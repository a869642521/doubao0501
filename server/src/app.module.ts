import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { UserModule } from './modules/user/user.module';
import { AgentModule } from './modules/agent/agent.module';
import { ContentModule } from './modules/content/content.module';
import { CurrencyModule } from './modules/currency/currency.module';
import { ChatModule } from './modules/chat/chat.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UserModule,
    AgentModule,
    ContentModule,
    CurrencyModule,
    ChatModule,
  ],
})
export class AppModule {}
