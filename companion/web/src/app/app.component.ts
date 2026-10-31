import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  Injector,
  OnDestroy,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import QRCode from 'qrcode';

import {
  aad,
  base64ToBytes,
  bytesToBase64,
  createPwaKeys,
  deriveSessionKey,
  exportPrivate,
  exportRaw,
  importPrivate,
  open,
  safetyNumber,
  seal,
} from './session.crypto';

interface Episode {
  id: number;
  title: string;
  audioUrl: string;
  imageUrl: string | null;
  durationMs: number | null;
  positionMs: number;
  publishedAt: string | null;
  favorite: boolean;
  downloaded: boolean;
  played: boolean;
  lastPlayedAt: string | null;
  downloadedAt: string | null;
}

interface LibraryEpisode extends Episode {
  podcastId: number;
  podcastTitle: string;
}

interface Playlist {
  id: number;
  name: string;
  isDefault: boolean;
  episodeIds: number[];
}

type LibraryView =
  | 'hub'
  | 'favorites'
  | 'episodes'
  | 'downloads'
  | 'playlists'
  | 'playlist'
  | 'stats';

interface Podcast {
  id: number;
  title: string;
  author: string;
  imageUrl: string | null;
  preferred: boolean;
  episodes: Episode[];
}

type HomeShelf =
  | { id: 'continue'; episodes: LibraryEpisode[] }
  | { id: 'fresh' | 'favorites' | 'recent' | 'random' | 'downloads'; episodes: LibraryEpisode[] }
  | { id: 'preferred'; podcasts: Podcast[] };

interface StoredSession {
  relay: string;
  session: string;
  pwaPub: string;
  pwaPriv: string;
  phonePub?: string;
  fingerprint?: string;
}

const storageKey = 'podavio-web-session';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent implements OnDestroy {
  private readonly injector = inject(Injector);
  readonly qrCanvas = viewChild<ElementRef<HTMLCanvasElement>>('qr');
  readonly audio = viewChild<ElementRef<HTMLAudioElement>>('audio');

  readonly french = navigator.language.toLowerCase().startsWith('fr');
  readonly fingerprint = signal('');
  readonly status = signal('');
  readonly podcasts = signal<Podcast[]>([]);
  readonly playlists = signal<Playlist[]>([]);
  readonly page = signal<'home' | 'subscriptions' | 'library'>('home');
  readonly randomSeed = signal(1);
  readonly libraryView = signal<LibraryView>('hub');
  readonly openedPlaylist = signal<Playlist | null>(null);
  readonly opened = signal<Podcast | null>(null);
  readonly playing = signal<Episode | null>(null);
  readonly error = signal('');
  private socket?: WebSocket;
  private stored?: StoredSession;
  private privateKey?: CryptoKey;
  private sessionKey?: CryptoKey;
  private conn = randomId();
  private peerConn = '';
  private sendN = 0;
  private recvN = 0;
  private pendingHello: { pub: string; iv: string; ct: string } | null = null;
  private lastSent = 0;

  constructor() {
    afterNextRender(() => {
      void this.start();
    });
  }

  ngOnDestroy(): void {
    this.socket?.close();
  }

  text(en: string, fr: string): string {
    return this.french ? fr : en;
  }

  initial(title: string): string {
    const trimmed = title.trim();
    return trimmed ? trimmed.charAt(0).toUpperCase() : '·';
  }

  formatWhen(value: string | null): string {
    if (!value) return '';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return value;
    return date.toLocaleDateString(this.french ? 'fr' : undefined, {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  }

  async disconnect(): Promise<void> {
    await this.forget(true);
  }

  private async forget(notify: boolean): Promise<void> {
    const socket = this.socket;
    this.socket = undefined;
    if (notify && socket && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: 'unlink' }));
    }
    socket?.close();
    localStorage.removeItem(storageKey);
    this.stored = undefined;
    this.podcasts.set([]);
    this.playlists.set([]);
    this.page.set('home');
    this.libraryView.set('hub');
    this.openedPlaylist.set(null);
    this.opened.set(null);
    this.playing.set(null);
    this.fingerprint.set('');
    this.sessionKey = undefined;
    this.peerConn = '';
    this.pendingHello = null;
    await this.start();
  }

  openPodcast(podcast: Podcast): void {
    this.page.set('subscriptions');
    this.opened.set(podcast);
  }

  showHome(): void {
    this.page.set('home');
    this.opened.set(null);
  }

  closePodcast(): void {
    this.page.set('subscriptions');
    this.libraryView.set('hub');
    this.openedPlaylist.set(null);
    this.opened.set(null);
  }

  showLibrary(): void {
    this.page.set('library');
    this.opened.set(null);
    this.libraryView.set('hub');
    this.openedPlaylist.set(null);
  }

  openLibrary(view: LibraryView): void {
    this.libraryView.set(view);
    this.openedPlaylist.set(null);
  }

  openPlaylist(playlist: Playlist): void {
    this.openedPlaylist.set(playlist);
    this.libraryView.set('playlist');
  }

  libraryBack(): void {
    if (this.libraryView() === 'playlist') {
      this.libraryView.set('playlists');
      this.openedPlaylist.set(null);
      return;
    }
    this.libraryView.set('hub');
  }

  libraryTitle(): string {
    switch (this.libraryView()) {
      case 'favorites':
        return this.text('Favorites', 'Favoris');
      case 'episodes':
        return this.text('Episodes', 'Épisodes');
      case 'downloads':
        return this.text('Downloads', 'Téléchargements');
      case 'playlists':
        return this.text('Playlists', 'Playlists');
      case 'playlist':
        return this.openedPlaylist()?.name ?? this.text('Playlists', 'Playlists');
      case 'stats':
        return this.text('Statistics', 'Statistiques');
      case 'hub':
        return this.text('Library', 'Bibliothèque');
    }
  }

  flatEpisodes(): LibraryEpisode[] {
    return this.podcasts().flatMap((podcast) =>
      podcast.episodes.map((episode) => ({
        ...episode,
        podcastId: podcast.id,
        podcastTitle: podcast.title,
      })),
    );
  }

  recentEpisodes(): LibraryEpisode[] {
    return this.flatEpisodes()
      .filter((episode) => episode.lastPlayedAt)
      .sort((a, b) => (b.lastPlayedAt ?? '').localeCompare(a.lastPlayedAt ?? ''));
  }

  libraryEpisodes(): LibraryEpisode[] {
    const view = this.libraryView();
    const episodes = this.flatEpisodes();
    if (view === 'favorites') return episodes.filter((episode) => episode.favorite);
    if (view === 'downloads') return episodes.filter((episode) => episode.downloaded);
    if (view === 'episodes') {
      return [...episodes].sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''));
    }
    if (view === 'playlist') {
      const playlist = this.openedPlaylist();
      if (!playlist) return [];
      const byId = new Map(episodes.map((episode) => [episode.id, episode]));
      return playlist.episodeIds.flatMap((id) => {
        const episode = byId.get(id);
        return episode ? [episode] : [];
      });
    }
    return [];
  }

  statCount(kind: 'podcasts' | 'episodes' | 'favorites' | 'downloads' | 'playlists'): number {
    if (kind === 'podcasts') return this.podcasts().length;
    if (kind === 'playlists') return this.playlists().length;
    if (kind === 'favorites') return this.flatEpisodes().filter((episode) => episode.favorite).length;
    if (kind === 'downloads') return this.flatEpisodes().filter((episode) => episode.downloaded).length;
    return this.flatEpisodes().length;
  }

  greeting(): string {
    const hour = new Date().getHours();
    if (hour >= 6 && hour <= 12) return this.text('Good morning', 'Bonjour');
    if (hour >= 13 && hour <= 17) return this.text('Good afternoon', 'Bon après-midi');
    if (hour >= 18 && hour <= 23) return this.text('Good evening', 'Bonsoir');
    return this.text('Good night', 'Bonne nuit');
  }

  homeShelves(): HomeShelf[] {
    const shelves: HomeShelf[] = [];
    for (const id of ['continue', 'fresh', 'favorites', 'recent', 'random', 'preferred', 'downloads'] as const) {
      const shelf = this.homeShelf(id);
      if (shelf) shelves.push(shelf);
    }
    return shelves;
  }

  shelfTitle(id: HomeShelf['id']): string {
    switch (id) {
      case 'continue':
        return this.text('Continue listening', 'Continuer d’écouter');
      case 'fresh':
        return this.text("What's new", 'Les nouveautés');
      case 'favorites':
        return this.text('Favorites', 'Favoris');
      case 'recent':
        return this.text('Recent plays', 'Lectures récentes');
      case 'random':
        return this.text('Random', 'Aléatoire');
      case 'preferred':
        return this.text('Preferred subscriptions', 'Abonnements préférés');
      case 'downloads':
        return this.text('Recent downloads', 'Derniers téléchargements');
    }
  }

  openShelf(id: Exclude<HomeShelf['id'], 'continue' | 'random' | 'preferred'>): void {
    const view = id === 'fresh' ? 'episodes' : id === 'recent' ? 'hub' : id;
    this.page.set('library');
    this.opened.set(null);
    this.openedPlaylist.set(null);
    this.libraryView.set(view);
  }

  reshuffle(): void {
    this.randomSeed.update((seed) => seed + 1);
  }

  washUrl(): string | null {
    const first = this.homeShelves()[0];
    if (!first) return null;
    if (first.id === 'preferred') return first.podcasts[0]?.imageUrl ?? null;
    return this.coverOf(first.episodes[0]);
  }

  coverOf(episode: LibraryEpisode): string | null {
    if (episode.imageUrl) return episode.imageUrl;
    return this.podcasts().find((podcast) => podcast.id === episode.podcastId)?.imageUrl ?? null;
  }

  progress(episode: Episode): number | null {
    const duration = episode.durationMs;
    if (!duration || duration <= 0 || episode.positionMs <= 0) return null;
    return Math.min(1, episode.positionMs / duration);
  }

  meta(episode: LibraryEpisode): string {
    return [episode.podcastTitle, this.formatWhen(episode.publishedAt), this.formatDuration(episode.durationMs)]
      .filter((part) => part.length > 0)
      .join(' · ');
  }

  formatDuration(ms: number | null): string {
    if (ms == null || ms <= 0) return '';
    const total = Math.floor(ms / 1000);
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    const seconds = total % 60;
    const padded = String(seconds).padStart(2, '0');
    if (hours > 0) return `${hours}:${String(minutes).padStart(2, '0')}:${padded}`;
    return `${minutes}:${padded}`;
  }

  continueRows(count: number): number {
    return Math.min(3, Math.max(1, count));
  }

  private homeShelf(id: HomeShelf['id']): HomeShelf | null {
    const episodes = this.flatEpisodes();
    if (id === 'continue') {
      const rows = episodes
        .filter((episode) => !episode.played && episode.positionMs > 0)
        .sort((a, b) => (b.lastPlayedAt ?? '').localeCompare(a.lastPlayedAt ?? ''))
        .slice(0, 15);
      return rows.length ? { id, episodes: rows } : null;
    }
    if (id === 'fresh') {
      const rows = episodes
        .filter((episode) => !episode.played && episode.positionMs === 0)
        .sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''))
        .slice(0, 16);
      return rows.length ? { id, episodes: rows } : null;
    }
    if (id === 'favorites') {
      const rows = episodes
        .filter((episode) => episode.favorite)
        .sort((a, b) => (b.publishedAt ?? '').localeCompare(a.publishedAt ?? ''))
        .slice(0, 16);
      return rows.length ? { id, episodes: rows } : null;
    }
    if (id === 'recent') {
      const playing = new Set(
        episodes.filter((episode) => !episode.played && episode.positionMs > 0).map((episode) => episode.id),
      );
      const rows = episodes
        .filter((episode) => episode.lastPlayedAt && !playing.has(episode.id))
        .sort((a, b) => (b.lastPlayedAt ?? '').localeCompare(a.lastPlayedAt ?? ''))
        .slice(0, 12);
      return rows.length ? { id, episodes: rows } : null;
    }
    if (id === 'random') {
      const rows = shuffled(
        episodes.filter((episode) => !episode.played),
        this.randomSeed(),
      ).slice(0, 12);
      return rows.length ? { id, episodes: rows } : null;
    }
    if (id === 'downloads') {
      const rows = episodes
        .filter((episode) => episode.downloaded)
        .sort((a, b) => {
          const byDownload = (b.downloadedAt ?? '').localeCompare(a.downloadedAt ?? '');
          return byDownload || (b.publishedAt ?? '').localeCompare(a.publishedAt ?? '');
        })
        .slice(0, 12);
      return rows.length ? { id, episodes: rows } : null;
    }
    const podcasts = [...this.podcasts()].sort((a, b) => {
      if (a.preferred !== b.preferred) return a.preferred ? -1 : 1;
      return unfinishedListen(b, episodes) - unfinishedListen(a, episodes) || a.title.localeCompare(b.title);
    });
    return podcasts.length ? { id: 'preferred', podcasts } : null;
  }

  episodeCount(podcast: Podcast): string {
    const count = podcast.episodes.length;
    if (count === 1) return this.text('1 episode', '1 épisode');
    return this.text(`${count} episodes`, `${count} épisodes`);
  }

  playOpened(): void {
    const podcast = this.opened();
    if (!podcast || podcast.episodes.length === 0) return;
    const playing = this.playing();
    const current = playing && podcast.episodes.some((episode) => episode.id === playing.id)
      ? playing
      : podcast.episodes[0];
    this.play(current);
  }

  play(episode: Episode, openShow = true): void {
    this.prepare(episode, true, openShow);
  }

  prepare(episode: Episode, autoplay: boolean, openShow = true): void {
    const current = this.audio()?.nativeElement;
    const same = this.playing()?.id === episode.id && !!current && current.src === episode.audioUrl;
    this.playing.set(episode);
    const podcast = this.podcasts().find((item) => item.episodes.some((entry) => entry.id === episode.id));
    if (openShow && podcast) {
      this.page.set('subscriptions');
      this.opened.set(podcast);
    }
    afterNextRender(() => {
      const player = this.audio()?.nativeElement;
      if (!player) return;
      if (!same) {
        player.src = episode.audioUrl;
        if (episode.positionMs > 0) player.currentTime = episode.positionMs / 1000;
      }
      if (autoplay) void player.play().catch(() => undefined);
      else void this.sendProgress();
    }, { injector: this.injector });
  }

  onTime(): void {
    const now = Date.now();
    if (now - this.lastSent < 1000) return;
    this.lastSent = now;
    void this.sendProgress();
  }

  async sendProgress(): Promise<void> {
    const episode = this.playing();
    const player = this.audio()?.nativeElement;
    if (!episode || !player || !Number.isFinite(player.currentTime)) return;
    episode.positionMs = Math.floor(player.currentTime * 1000);
    const durationMs = Number.isFinite(player.duration) ? Math.floor(player.duration * 1000) : null;
    await this.send({
      type: 'progress',
      episodeId: episode.id,
      positionMs: episode.positionMs,
      durationMs,
      playing: !player.paused && !player.ended,
      ended: player.ended,
    });
  }

  private handleCommand(payload: { action?: string; episodeId?: number; positionMs?: number; seconds?: number }): void {
    const action = payload.action;
    if ((action === 'play' || action === 'prepare') && typeof payload.episodeId === 'number') {
      const episode = this.findEpisode(payload.episodeId);
      if (!episode) return;
      if (typeof payload.positionMs === 'number') episode.positionMs = payload.positionMs;
      this.prepare(episode, action === 'play');
      return;
    }
    const player = this.audio()?.nativeElement;
    if (!player || !this.playing()) return;
    if (action === 'toggle') {
      if (player.paused) void player.play().catch(() => undefined);
      else player.pause();
    } else if (action === 'seek' && typeof payload.positionMs === 'number') {
      player.currentTime = payload.positionMs / 1000;
    } else if (action === 'skip' && typeof payload.seconds === 'number') {
      player.currentTime = Math.max(0, player.currentTime + payload.seconds);
    } else if (action === 'next' || action === 'previous') {
      this.stepEpisode(action === 'next' ? 1 : -1);
      return;
    }
    void this.sendProgress();
  }

  private findEpisode(id: number): Episode | undefined {
    for (const podcast of this.podcasts()) {
      const episode = podcast.episodes.find((item) => item.id === id);
      if (episode) return episode;
    }
    return undefined;
  }

  private stepEpisode(delta: number): void {
    const playing = this.playing();
    if (!playing) return;
    const podcast = this.podcasts().find((item) => item.episodes.some((entry) => entry.id === playing.id));
    if (!podcast) return;
    const index = podcast.episodes.findIndex((entry) => entry.id === playing.id);
    const next = podcast.episodes[index + delta];
    if (next) this.prepare(next, true);
  }

  private async start(): Promise<void> {
    this.error.set('');
    this.status.set(this.text('Preparing the encrypted link…', 'Préparation du lien chiffré…'));
    try {
      const saved = localStorage.getItem(storageKey);
      this.stored = saved ? (JSON.parse(saved) as StoredSession) : await this.createSession();
      this.privateKey = await importPrivate(base64ToBytes(this.stored.pwaPriv));
      this.fingerprint.set(this.stored.fingerprint ?? '');
      if (this.stored.phonePub) {
        this.sessionKey = await deriveSessionKey(this.privateKey, base64ToBytes(this.stored.phonePub));
      }
      this.connect();
      if (!this.stored.phonePub) await this.drawQr();
    } catch {
      this.error.set(this.text(
        'This browser cannot start the encrypted link.',
        'Ce navigateur ne peut pas ouvrir le lien chiffré.',
      ));
    }
  }

  private async createSession(): Promise<StoredSession> {
    const keys = await createPwaKeys();
    const pub = await exportRaw(keys.publicKey);
    const priv = await exportPrivate(keys.privateKey);
    const scheme = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const created: StoredSession = {
      relay: `${scheme}//${location.host}/ws`,
      session: randomId(),
      pwaPub: bytesToBase64(pub),
      pwaPriv: bytesToBase64(priv),
    };
    localStorage.setItem(storageKey, JSON.stringify(created));
    return created;
  }

  private async drawQr(): Promise<void> {
    const stored = this.stored;
    const canvas = this.qrCanvas()?.nativeElement;
    if (!stored || !canvas) return;
    const payload = JSON.stringify({
      v: 1,
      relay: stored.relay,
      session: stored.session,
      pub: stored.pwaPub,
    });
    await QRCode.toCanvas(canvas, payload, { margin: 1, width: 264 });
    this.status.set(this.text(
      'Scan this code with Podavio on the phone.',
      'Scannez ce code avec Podavio sur le téléphone.',
    ));
  }

  private connect(): void {
    const stored = this.stored;
    if (!stored) return;
    this.conn = randomId();
    this.sendN = 0;
    this.recvN = 0;
    this.peerConn = '';
    const socket = new WebSocket(stored.relay);
    this.socket = socket;
    socket.addEventListener('open', () => {
      socket.send(JSON.stringify({
        type: 'join',
        session: stored.session,
        role: 'browser',
        conn: this.conn,
      }));
      this.status.set(this.text('Waiting for the phone…', 'En attente du téléphone…'));
    });
    socket.addEventListener('message', (event) => {
      if (this.socket !== socket) return;
      void this.onMessage(String(event.data));
    });
    socket.addEventListener('close', () => {
      if (this.socket !== socket) return;
      this.status.set(this.text('Reconnecting…', 'Reconnexion…'));
      window.setTimeout(() => this.connect(), 3000);
    });
  }

  private async onMessage(raw: string): Promise<void> {
    const message = JSON.parse(raw) as Record<string, unknown>;
    if (message['type'] === 'peer' && message['role'] === 'phone' && typeof message['conn'] === 'string') {
      this.peerConn = message['conn'];
      this.recvN = 0;
      if (this.pendingHello) {
        await this.acceptHello(this.pendingHello);
        this.pendingHello = null;
      }
      void this.sendProgress();
      return;
    }
    if (message['type'] === 'unlink') {
      await this.forget(false);
      return;
    }
    if (message['type'] === 'bye') {
      this.peerConn = '';
      this.status.set(this.text('Waiting for the phone…', 'En attente du téléphone…'));
      return;
    }
    if (message['type'] === 'hello') {
      const hello = {
        pub: String(message['pub'] ?? ''),
        iv: String(message['iv'] ?? ''),
        ct: String(message['ct'] ?? ''),
      };
      if (!this.peerConn) {
        this.pendingHello = hello;
        return;
      }
      await this.acceptHello(hello);
      return;
    }
    if (message['type'] === 'blob') await this.acceptBlob(message);
  }

  private async acceptHello(hello: { pub: string; iv: string; ct: string }): Promise<void> {
    const stored = this.stored;
    const privateKey = this.privateKey;
    if (!stored || !privateKey) return;
    const phonePub = base64ToBytes(hello.pub);
    const key = await deriveSessionKey(privateKey, phonePub);
    const clear = await open(key, hello.iv, hello.ct, aad('phone', this.peerConn, 0));
    if (!clear) return;
    const payload = JSON.parse(new TextDecoder().decode(clear)) as { pub?: string };
    if (payload.pub !== hello.pub) return;
    this.sessionKey = key;
    stored.phonePub = hello.pub;
    stored.fingerprint = await safetyNumber(base64ToBytes(stored.pwaPub), phonePub);
    this.fingerprint.set(stored.fingerprint);
    localStorage.setItem(storageKey, JSON.stringify(stored));
    this.status.set(this.text('Phone linked. Waiting for the library…', 'Téléphone associé. En attente de la bibliothèque…'));
  }

  private applySnapshot(podcasts: Podcast[], playlists: Playlist[]): void {
    const playing = this.playing();
    const audio = this.audio()?.nativeElement;
    const locallyPlaying = !!playing && !!audio && !audio.paused && !audio.ended;
    this.podcasts.set(podcasts);
    this.playlists.set(playlists);
    const openedList = this.openedPlaylist();
    if (openedList) {
      const nextList = playlists.find((playlist) => playlist.id === openedList.id) ?? null;
      this.openedPlaylist.set(nextList);
      if (!nextList && this.libraryView() === 'playlist') this.libraryView.set('playlists');
    }
    const opened = this.opened();
    if (opened) {
      this.opened.set(podcasts.find((podcast) => podcast.id === opened.id) ?? null);
    }
    if (playing) {
      const next = podcasts
        .flatMap((podcast) => podcast.episodes)
        .find((episode) => episode.id === playing.id);
      if (!next) {
        this.playing.set(null);
      } else if (
        audio &&
        !locallyPlaying &&
        Math.abs(audio.currentTime * 1000 - next.positionMs) > 1500
      ) {
        audio.currentTime = next.positionMs / 1000;
        this.playing.set(next);
      } else {
        this.playing.set(locallyPlaying ? { ...next, positionMs: playing.positionMs } : next);
      }
    }
    this.status.set('');
  }

  private async acceptBlob(message: Record<string, unknown>): Promise<void> {
    const key = this.sessionKey;
    const n = message['n'];
    const iv = message['iv'];
    const ct = message['ct'];
    if (!key || typeof n !== 'number' || typeof iv !== 'string' || typeof ct !== 'string') return;
    if (n <= this.recvN) return;
    this.recvN = n;
    const clear = await open(key, iv, ct, aad('phone', this.peerConn, n));
    if (!clear) return;
    const payload = JSON.parse(new TextDecoder().decode(clear)) as {
      type?: string;
      podcasts?: unknown;
      playlists?: unknown;
    };
    if (payload.type === 'command') {
      this.handleCommand(payload as { action?: string; episodeId?: number; positionMs?: number; seconds?: number });
      return;
    }
    if (payload.type === 'snapshot' && Array.isArray(payload.podcasts)) {
      this.applySnapshot(this.readPodcasts(payload.podcasts), this.readPlaylists(payload.playlists));
    }
  }

  private readPodcasts(raw: unknown[]): Podcast[] {
    const podcasts: Podcast[] = [];
    for (const item of raw) {
      if (!item || typeof item !== 'object') continue;
      const podcast = item as Record<string, unknown>;
      if (typeof podcast['id'] !== 'number' || typeof podcast['title'] !== 'string') continue;
      const episodes = Array.isArray(podcast['episodes'])
        ? podcast['episodes'].flatMap((entry) => {
            const episode = this.readEpisode(entry);
            return episode ? [episode] : [];
          })
        : [];
      podcasts.push({
        id: podcast['id'],
        title: podcast['title'],
        author: typeof podcast['author'] === 'string' ? podcast['author'] : '',
        imageUrl: typeof podcast['imageUrl'] === 'string' ? podcast['imageUrl'] : null,
        preferred: podcast['preferred'] === true,
        episodes,
      });
    }
    return podcasts;
  }

  private readEpisode(raw: unknown): Episode | null {
    if (!raw || typeof raw !== 'object') return null;
    const episode = raw as Record<string, unknown>;
    if (typeof episode['id'] !== 'number' || typeof episode['title'] !== 'string') return null;
    if (typeof episode['audioUrl'] !== 'string') return null;
    return {
      id: episode['id'],
      title: episode['title'],
      audioUrl: episode['audioUrl'],
      imageUrl: typeof episode['imageUrl'] === 'string' ? episode['imageUrl'] : null,
      durationMs: typeof episode['durationMs'] === 'number' ? episode['durationMs'] : null,
      positionMs: typeof episode['positionMs'] === 'number' ? episode['positionMs'] : 0,
      publishedAt: typeof episode['publishedAt'] === 'string' ? episode['publishedAt'] : null,
      favorite: episode['favorite'] === true,
      downloaded: episode['downloaded'] === true,
      played: episode['played'] === true,
      lastPlayedAt: typeof episode['lastPlayedAt'] === 'string' ? episode['lastPlayedAt'] : null,
      downloadedAt: typeof episode['downloadedAt'] === 'string' ? episode['downloadedAt'] : null,
    };
  }

  private readPlaylists(raw: unknown): Playlist[] {
    if (!Array.isArray(raw)) return [];
    const playlists: Playlist[] = [];
    for (const item of raw) {
      if (!item || typeof item !== 'object') continue;
      const playlist = item as Record<string, unknown>;
      if (typeof playlist['id'] !== 'number' || typeof playlist['name'] !== 'string') continue;
      const episodeIds = Array.isArray(playlist['episodeIds'])
        ? playlist['episodeIds'].filter((id): id is number => typeof id === 'number')
        : [];
      playlists.push({
        id: playlist['id'],
        name: playlist['name'],
        isDefault: playlist['isDefault'] === true,
        episodeIds,
      });
    }
    return playlists;
  }

  private async send(payload: unknown): Promise<void> {
    const key = this.sessionKey;
    const socket = this.socket;
    if (!key || !socket || socket.readyState !== WebSocket.OPEN || !this.peerConn) return;
    this.sendN += 1;
    const sealed = await seal(
      key,
      new TextEncoder().encode(JSON.stringify(payload)),
      aad('browser', this.conn, this.sendN),
    );
    socket.send(JSON.stringify({ type: 'blob', n: this.sendN, iv: sealed.iv, ct: sealed.ct }));
  }
}

function unfinishedListen(podcast: Podcast, episodes: LibraryEpisode[]): number {
  let total = 0;
  for (const episode of episodes) {
    if (episode.podcastId === podcast.id && !episode.played && episode.positionMs > 0) {
      total += episode.positionMs;
    }
  }
  return total;
}

function shuffled<T>(items: T[], seed: number): T[] {
  const copy = [...items];
  let state = seed >>> 0 || 1;
  for (let index = copy.length - 1; index > 0; index--) {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    const swap = copy[index];
    const target = state % (index + 1);
    copy[index] = copy[target];
    copy[target] = swap;
  }
  return copy;
}

function randomId(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return bytesToBase64(bytes);
}
