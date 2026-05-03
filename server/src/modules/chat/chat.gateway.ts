import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import { CurrencyService } from '../currency/currency.service';
import { MessageRole } from '@prisma/client';
import { stripMarkdownForVoice } from './voice-plain.util';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/chat',
})
export class ChatGateway {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly chatService: ChatService,
    private readonly currencyService: CurrencyService,
  ) {}

  @SubscribeMessage('sendMessage')
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: { conversationId: string; content: string; userId: string },
  ) {
    const { conversationId, content, userId } = data;

    // 若会话不存在（前端用 agentId 当 conversationId），先 findOrCreate 会话
    let realConversationId = conversationId;
    try {
      await this.chatService.getConversationWithAgent(conversationId);
    } catch {
      // 会话不存在：把 conversationId 当 agentId 来 findOrCreate
      const effectiveUserId = userId || 'anonymous';
      try {
        const conv = await this.chatService.createConversation(
          effectiveUserId,
          conversationId,
        );
        realConversationId = conv.id;
        client.emit('conversationCreated', {
          oldId: conversationId,
          newId: realConversationId,
        });
      } catch {
        client.emit('error', { message: '会话创建失败，请重试' });
        return;
      }
    }

    await this.chatService.saveMessage(
      realConversationId,
      MessageRole.user,
      content,
    );

    // Check and deduct currency for messages beyond free tier
    if (userId) {
      try {
        await this.currencyService.handleMessageCost(userId);
      } catch {
        client.emit('error', { message: '灵感币不足，请先发布内容赚取灵感币' });
        return;
      }
    }

    const conversation =
      await this.chatService.getConversationWithAgent(realConversationId);
    const recentMessages =
      await this.chatService.getRecentMessagesForContext(realConversationId);

    // Call AI service via HTTP
    try {
      const aiServiceUrl = process.env.AI_SERVICE_URL || 'http://localhost:8001';
      const response = await fetch(`${aiServiceUrl}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          agent_id: conversation.agentId,
          system_prompt: conversation.agent.systemPrompt,
          messages: recentMessages.map((m) => ({
            role: m.role,
            content: m.content,
          })),
          stream: true,
        }),
      });

      if (!response.ok || !response.body) {
        throw new Error('AI service error');
      }

      let fullContent = '';
      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value, { stream: true });
        const lines = chunk.split('\n').filter((l) => l.startsWith('data: '));

        for (const line of lines) {
          const jsonStr = line.slice(6);
          if (jsonStr === '[DONE]') continue;

          try {
            const parsed = JSON.parse(jsonStr);
            if (parsed.error) {
              client.emit('error', { message: parsed.error });
              return;
            }
            const delta = parsed.choices?.[0]?.delta ?? {};
            // Thinking phase
            if (delta.thinking) {
              client.emit('thinkingChunk', { conversationId: realConversationId, token: delta.thinking });
            }
            // Actual response
            if (delta.content) {
              fullContent += delta.content;
              client.emit('messageChunk', { conversationId: realConversationId, token: delta.content });
            }
          } catch {
            // skip malformed chunks
          }
        }
      }

      let savedVoicePlain: string | null = null;
      if (fullContent) {
        savedVoicePlain = stripMarkdownForVoice(fullContent);
        if (!savedVoicePlain) savedVoicePlain = null;
        await this.chatService.saveMessage(
          realConversationId,
          MessageRole.assistant,
          fullContent,
          savedVoicePlain,
        );
      }

      client.emit('messageComplete', {
        conversationId: realConversationId,
        voicePlain: savedVoicePlain,
      });
    } catch (error) {
      client.emit('error', {
        message: 'AI 服务暂时不可用，请稍后再试',
      });
    }
  }

  /**
   * saveTurn：豆包端到端 SDK 每轮结束后，把用户话 + AI 话同步落库。
   * 不触发 LLM，只做持久化，保证语音对话历史与文字对话共享同一会话线。
   */
  @SubscribeMessage('saveTurn')
  async handleSaveTurn(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: {
      conversationId: string;
      userId: string;
      userText: string;
      assistantText: string;
    },
  ) {
    const { conversationId, userId, userText, assistantText } = data;
    if (!conversationId || !userText || !assistantText) return;

    let realConversationId = conversationId;
    try {
      await this.chatService.getConversationWithAgent(conversationId);
    } catch {
      const effectiveUserId = userId || 'anonymous';
      try {
        const conv = await this.chatService.createConversation(
          effectiveUserId,
          conversationId,
        );
        realConversationId = conv.id;
        client.emit('conversationCreated', {
          oldId: conversationId,
          newId: realConversationId,
        });
      } catch {
        return;
      }
    }

    await this.chatService.saveMessage(
      realConversationId,
      MessageRole.user,
      userText,
    );

    const voicePlain = stripMarkdownForVoice(assistantText) || null;
    await this.chatService.saveMessage(
      realConversationId,
      MessageRole.assistant,
      assistantText,
      voicePlain,
    );

    client.emit('turnSaved', { conversationId: realConversationId });
  }
}
