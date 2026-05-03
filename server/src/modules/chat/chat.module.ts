import { Module } from '@nestjs/common';
import { ChatService } from './chat.service';
import { ChatController } from './chat.controller';
import { ChatGateway } from './chat.gateway';
import { AgentModule } from '../agent/agent.module';
import { CurrencyModule } from '../currency/currency.module';

@Module({
  imports: [AgentModule, CurrencyModule],
  controllers: [ChatController],
  providers: [ChatService, ChatGateway],
  exports: [ChatService],
})
export class ChatModule {}
