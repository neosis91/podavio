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
}

interface Podcast {
  id: number;
  title: string;
  author: string;
  imageUrl: string | null;
  episodes: Episode[];
}

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
    this.opened.set(null);
    this.playing.set(null);
    this.fingerprint.set('');
    this.sessionKey = undefined;
    this.peerConn = '';
    this.pendingHello = null;
    await this.start();
  }

  openPodcast(podcast: Podcast): void {
    this.opened.set(podcast);
  }

  closePodcast(): void {
    this.opened.set(null);
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

  play(episode: Episode): void {
    this.prepare(episode, true);
  }

  prepare(episode: Episode, autoplay: boolean): void {
    const current = this.audio()?.nativeElement;
    const same = this.playing()?.id === episode.id && !!current && current.src === episode.audioUrl;
    this.playing.set(episode);
    const podcast = this.podcasts().find((item) => item.episodes.some((entry) => entry.id === episode.id));
    if (podcast) this.opened.set(podcast);
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

  private applySnapshot(podcasts: Podcast[]): void {
    const playing = this.playing();
    const audio = this.audio()?.nativeElement;
    const locallyPlaying = !!playing && !!audio && !audio.paused && !audio.ended;
    this.podcasts.set(podcasts);
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
    const payload = JSON.parse(new TextDecoder().decode(clear)) as { type?: string; podcasts?: Podcast[] };
    if (payload.type === 'command') {
      this.handleCommand(payload as { action?: string; episodeId?: number; positionMs?: number; seconds?: number });
      return;
    }
    if (payload.type === 'snapshot' && Array.isArray(payload.podcasts)) {
      this.applySnapshot(payload.podcasts);
    }
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

function randomId(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return bytesToBase64(bytes);
}
