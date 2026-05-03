import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Query,
  Headers,
} from '@nestjs/common';
import { IsString, IsOptional } from 'class-validator';
import { ChatService } from './chat.service';

class CreateConversationDto {
  @IsString()
  agentId!: string;
}

@Controller('conversations')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Post()
  async createConversation(
    @Headers('x-user-id') userId: string,
    @Body() dto: CreateConversationDto,
  ) {
    return this.chatService.createConversation(userId, dto.agentId);
  }

  @Get()
  async getConversations(@Headers('x-user-id') userId: string) {
    return this.chatService.getConversations(userId);
  }

  @Get(':id/messages')
  async getMessages(
    @Param('id') id: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.chatService.getMessages(id, cursor, limit ? parseInt(limit) : 30);
  }
}
