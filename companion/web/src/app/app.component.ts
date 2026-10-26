import { Component, ElementRef, OnDestroy, ViewChild, afterNextRender } from '@angular/core';
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
})
export class AppComponent implements OnDestroy {
  @ViewChild('qr') qrCanvas?: ElementRef<HTMLCanvasElement>;
  @ViewChild('audio') audio?: ElementRef<HTMLAudioElement>;

  french = navigator.language.toLowerCase().startsWith('fr');
  fingerprint = '';
  status = '';
  podcasts: Podcast[] = [];
  opened: Podcast | null = null;
  playing: Episode | null = null;
  error = '';
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
    localStorage.removeItem(storageKey);
    this.socket?.close();
    this.podcasts = [];
    this.opened = null;
    this.playing = null;
    this.fingerprint = '';
    this.sessionKey = undefined;
    await this.start();
  }

  openPodcast(podcast: Podcast): void {
    this.opened = podcast;
  }

  closePodcast(): void {
    this.opened = null;
  }

  async play(episode: Episode): Promise<void> {
    this.playing = episode;
    window.setTimeout(() => {
      const player = this.audio?.nativeElement;
      if (!player) return;
      player.src = episode.audioUrl;
      if (episode.positionMs > 0) player.currentTime = episode.positionMs / 1000;
      void player.play().catch(() => undefined);
    });
  }

  onTime(): void {
    const now = Date.now();
    if (now - this.lastSent < 5000) return;
    this.lastSent = now;
    void this.sendProgress();
  }

  async sendProgress(): Promise<void> {
    const episode = this.playing;
    const player = this.audio?.nativeElement;
    if (!episode || !player || !Number.isFinite(player.currentTime)) return;
    episode.positionMs = Math.floor(player.currentTime * 1000);
    await this.send({
      type: 'progress',
      episodeId: episode.id,
      positionMs: episode.positionMs,
    });
  }

  private async start(): Promise<void> {
    this.error = '';
    this.status = this.text('Preparing the encrypted link…', 'Préparation du lien chiffré…');
    try {
      const saved = localStorage.getItem(storageKey);
      this.stored = saved ? (JSON.parse(saved) as StoredSession) : await this.createSession();
      this.privateKey = await importPrivate(base64ToBytes(this.stored.pwaPriv));
      this.fingerprint = this.stored.fingerprint ?? '';
      if (this.stored.phonePub) {
        this.sessionKey = await deriveSessionKey(this.privateKey, base64ToBytes(this.stored.phonePub));
      }
      this.connect();
      if (!this.stored.phonePub) await this.drawQr();
    } catch {
      this.error = this.text(
        'This browser cannot start the encrypted link.',
        'Ce navigateur ne peut pas ouvrir le lien chiffré.',
      );
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
    const canvas = this.qrCanvas?.nativeElement;
    if (!stored || !canvas) return;
    const payload = JSON.stringify({
      v: 1,
      relay: stored.relay,
      session: stored.session,
      pub: stored.pwaPub,
    });
    await QRCode.toCanvas(canvas, payload, { margin: 1, width: 264 });
    this.status = this.text(
      'Scan this code with Podavio on the phone.',
      'Scannez ce code avec Podavio sur le téléphone.',
    );
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
      this.status = this.text('Waiting for the phone…', 'En attente du téléphone…');
    });
    socket.addEventListener('message', (event) => {
      void this.onMessage(String(event.data));
    });
    socket.addEventListener('close', () => {
      if (this.socket !== socket) return;
      this.status = this.text('Reconnecting…', 'Reconnexion…');
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
      return;
    }
    if (message['type'] === 'bye') {
      this.peerConn = '';
      this.status = this.text('Waiting for the phone…', 'En attente du téléphone…');
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
    this.fingerprint = stored.fingerprint;
    localStorage.setItem(storageKey, JSON.stringify(stored));
    this.status = this.text('Phone linked. Waiting for the library…', 'Téléphone associé. En attente de la bibliothèque…');
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
    if (payload.type === 'snapshot' && Array.isArray(payload.podcasts)) {
      this.podcasts = payload.podcasts;
      this.opened = null;
      this.status = '';
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
