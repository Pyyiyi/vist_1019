import type { Server as HttpServer } from 'node:http';
import type { Request, RequestHandler, Response } from 'express';
import { Server as SocketServer } from 'socket.io';

import { MESSAGES } from '../shared/constants/messages.js';

let socketServer: SocketServer | undefined;

function sessionResponse(): Response {
  const response = {
    getHeader: () => undefined,
    setHeader: () => response,
    writeHead: () => response,
    end: () => response,
  };
  return response as unknown as Response;
}

function sessionUserId(request: Request): string | undefined {
  const session = (request as Request & {
    session?: { userId?: string; user?: { id?: string } };
  }).session;
  return session?.userId ?? session?.user?.id;
}

export function initRealtime(server: HttpServer, sessionMiddleware: RequestHandler): SocketServer {
  const io = new SocketServer(server, {
    path: '/ws',
    serveClient: false,
  });

  io.use((socket, next) => {
    const request = socket.request as Request;
    try {
      sessionMiddleware(request, sessionResponse(), (error?: unknown) => {
        if (error) {
          next(error instanceof Error ? error : new Error(String(error)));
          return;
        }

        const userId = sessionUserId(request);
        if (!userId) {
          next(new Error(MESSAGES.UNAUTHORIZED));
          return;
        }

        socket.data.userId = userId;
        next();
      });
    } catch (error) {
      next(error instanceof Error ? error : new Error(String(error)));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.data.userId as string | undefined;
    if (!userId) {
      socket.disconnect(true);
      return;
    }
    socket.join(`user:${userId}`);
  });

  socketServer = io;
  return io;
}

export function emitNotification(
  userId: string,
  payload: { id: string; title: string; templateType: string; createdAt: string }
): void {
  socketServer?.to(`user:${userId}`).emit('notification:new', payload);
}
