import { Module } from '@nestjs/common';

import { RelayHub } from './relay';
import { RelayService } from './relay.service';

@Module({
  providers: [RelayHub, RelayService],
})
export class AppModule {}
