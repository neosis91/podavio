import { Injectable } from '@nestjs/common';

export type Role = 'browser' | 'phone';

export interface Outbound {
  send(json: unknown): void;
}

interface Room {
  peers: Partial<Record<Role, Outbound>>;
  conns: Partial<Record<Role, string>>;
}

const maxId = 128;
const maxBlob = 2_000_000;

export function isRole(value: unknown): value is Role {
  return value === 'browser' || value === 'phone';
}

function other(role: Role): Role {
  return role === 'browser' ? 'phone' : 'browser';
}

function shortText(value: unknown): string | null {
  if (typeof value !== 'string' || value.length === 0 || value.length > maxId) {
    return null;
  }
  return value;
}

function blobText(value: unknown): string | null {
  if (typeof value !== 'string' || value.length === 0 || value.length > maxBlob) {
    return null;
  }
  return value;
}

/** Associe deux sockets et ne transmet que des champs opaques. */
@Injectable()
export class RelayHub {
  private readonly rooms = new Map<string, Room>();

  join(session: string, role: Role, conn: string, peer: Outbound): void {
    const room = this.rooms.get(session) ?? { peers: {}, conns: {} };
    room.peers[role] = peer;
    room.conns[role] = conn;
    this.rooms.set(session, room);
    const opposite = other(role);
    const oppositePeer = room.peers[opposite];
    const oppositeConn = room.conns[opposite];
    if (oppositePeer && oppositeConn) {
      oppositePeer.send({ type: 'peer', role, conn });
      peer.send({ type: 'peer', role: opposite, conn: oppositeConn });
    }
  }

  leave(session: string, role: Role, peer: Outbound): void {
    const room = this.rooms.get(session);
    if (!room || room.peers[role] !== peer) return;
    delete room.peers[role];
    delete room.conns[role];
    const opposite = other(role);
    room.peers[opposite]?.send({ type: 'bye', role });
    if (!room.peers.browser && !room.peers.phone) {
      this.rooms.delete(session);
    }
  }

  forward(session: string, from: Role, message: Record<string, unknown>): void {
    const room = this.rooms.get(session);
    const target = room?.peers[other(from)];
    if (!target) return;
    if (message.type === 'hello') {
      const pub = shortText(message.pub);
      const iv = shortText(message.iv);
      const ct = blobText(message.ct);
      if (!pub || !iv || !ct) return;
      target.send({ type: 'hello', pub, iv, ct });
      return;
    }
    if (message.type === 'unlink') {
      target.send({ type: 'unlink', role: from });
      return;
    }
    if (message.type === 'blob') {
      const n = message.n;
      const iv = shortText(message.iv);
      const ct = blobText(message.ct);
      if (typeof n !== 'number' || !Number.isInteger(n) || n < 1 || !iv || !ct) {
        return;
      }
      target.send({ type: 'blob', n, iv, ct });
    }
  }
}

export function readClientMessage(raw: string): Record<string, unknown> | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
  return parsed as Record<string, unknown>;
}
