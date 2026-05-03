import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MessageRole } from '@prisma/client';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  /** 确保 userId 对应的用户存在；未登录时返回系统匿名账号 */
  private async resolveUserId(userId: string | undefined | null): Promise<string> {
    if (userId && userId !== 'anonymous') {
      const exists = await this.prisma.user.findUnique({ where: { id: userId } });
      if (exists) return userId;
    }
    // 匿名用户：找或创建系统账号（phone = 'anonymous'）
    const anon = await this.prisma.user.upsert({
      where: { phone: 'anonymous' },
      create: { phone: 'anonymous', nickname: '访客' },
      update: {},
    });
    return anon.id;
  }

  async createConversation(userId: string, agentId: string) {
    const realUserId = await this.resolveUserId(userId);

    // 若 agent 不存在，自动创建占位 agent（支持预览卡片 / 地球模式等演示场景）
    const agent = await this.prisma.agent.upsert({
      where: { id: agentId },
      create: {
        id: agentId,
        userId: realUserId,
        name: 'AI 伙伴',
        emoji: '🤖',
        bio: '你好，我是你的 AI 伙伴，有什么可以帮你的吗？',
        systemPrompt:
          '你是一个温暖、友善的 AI 伙伴。请用自然、亲切的语气与用户交流，提供有价值的帮助和陪伴。',
        gradientStart: '#6C63FF',
        gradientEnd: '#00D2FF',
      },
      update: {},
    });

    // 若已存在相同 userId+agentId 的会话，直接复用（幂等）
    const existing = await this.prisma.conversation.findFirst({
      where: { userId: realUserId, agentId },
      include: { agent: true },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) return existing;

    return this.prisma.conversation.create({
      data: {
        userId: realUserId,
        agentId,
        title: `与 ${agent.name} 的对话`,
      },
      include: { agent: true },
    });
  }

  async getConversations(userId: string) {
    return this.prisma.conversation.findMany({
      where: { userId },
      include: {
        agent: { select: { id: true, name: true, emoji: true, gradientStart: true, gradientEnd: true, templateId: true } },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { content: true, createdAt: true, role: true },
        },
      },
      orderBy: { lastMessageAt: 'desc' },
    });
  }

  async getMessages(conversationId: string, cursor?: string, limit = 30) {
    const where: any = { conversationId };
    if (cursor) {
      where.createdAt = { lt: new Date(cursor) };
    }

    return this.prisma.message.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async saveMessage(
    conversationId: string,
    role: MessageRole,
    content: string,
    voicePlain?: string | null,
  ) {
    const message = await this.prisma.message.create({
      data: {
        conversationId,
        role,
        content,
        ...(role === MessageRole.assistant &&
        voicePlain != null &&
        voicePlain.length > 0
          ? { voicePlain }
          : {}),
      },
    });

    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { lastMessageAt: new Date() },
    });

    return message;
  }

  async getConversationWithAgent(conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { agent: true },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    return conversation;
  }

  async getRecentMessagesForContext(conversationId: string, limit = 20) {
    const messages = await this.prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { role: true, content: true },
    });
    return messages.reverse();
  }
}
