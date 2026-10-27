import { HttpAdapterHost } from '@nestjs/core';
import { Injectable, OnApplicationBootstrap, OnApplicationShutdown } from '@nestjs/common';
import { WebSocket, WebSocketServer } from 'ws';

import { isRole, readClientMessage, RelayHub, type Role } from './relay';

interface BoundSocket {
  session: string;
  role: Role;
  outbound: { send(json: unknown): void };
}

@Injectable()
export class RelayService implements OnApplicationBootstrap, OnApplicationShutdown {
  private server?: WebSocketServer;
  private readonly sockets = new Map<WebSocket, BoundSocket>();

  constructor(
    private readonly http: HttpAdapterHost,
    private readonly hub: RelayHub,
  ) {}

  onApplicationBootstrap(): void {
    const httpServer = this.http.httpAdapter.getHttpServer();
    this.server = new WebSocketServer({ server: httpServer, path: '/ws' });
    this.server.on('connection', (socket) => this.bind(socket));
  }

  onApplicationShutdown(): void {
    for (const socket of this.sockets.keys()) socket.close();
    this.server?.close();
  }

  private bind(socket: WebSocket): void {
    socket.on('message', (data) => {
      const message = readClientMessage(data.toString());
      if (!message) return;
      if (message.type === 'join') {
        this.join(socket, message);
        return;
      }
      const bound = this.sockets.get(socket);
      if (!bound) return;
      this.hub.forward(bound.session, bound.role, message);
    });
    socket.on('close', () => this.drop(socket));
    socket.on('error', () => this.drop(socket));
  }

  private join(socket: WebSocket, message: Record<string, unknown>): void {
    if (this.sockets.has(socket)) return;
    const session = message.session;
    const conn = message.conn;
    if (!isRole(message.role)) return;
    if (typeof session !== 'string' || session.length < 8 || session.length > 128) {
      return;
    }
    if (typeof conn !== 'string' || conn.length < 8 || conn.length > 128) return;
    const outbound = {
      send: (json: unknown) => {
        if (socket.readyState === WebSocket.OPEN) {
          socket.send(JSON.stringify(json));
        }
      },
    };
    this.sockets.set(socket, { session, role: message.role, outbound });
    this.hub.join(session, message.role, conn, outbound);
  }

  private drop(socket: WebSocket): void {
    const bound = this.sockets.get(socket);
    if (!bound) return;
    this.sockets.delete(socket);
    this.hub.leave(bound.session, bound.role, bound.outbound);
  }
}
