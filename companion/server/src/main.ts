import 'reflect-metadata';

import { existsSync } from 'node:fs';
import { join } from 'node:path';

import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { NextFunction, Request, Response } from 'express';

import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const webRoot = join(__dirname, '..', '..', 'web', 'dist', 'web', 'browser');
  if (existsSync(webRoot)) {
    app.useStaticAssets(webRoot);
    app.use((req: Request, res: Response, next: NextFunction) => {
      if (req.method !== 'GET' || req.path.startsWith('/ws')) {
        next();
        return;
      }
      res.sendFile(join(webRoot, 'index.html'));
    });
  }
  const port = Number(process.env.PORT ?? 8787);
  await app.listen(port);
}

void bootstrap();
