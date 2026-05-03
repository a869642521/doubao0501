import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { AGENT_TEMPLATES } from './agent.templates';

@Injectable()
export class AgentService {
  constructor(private readonly prisma: PrismaService) {}

  getTemplates() {
    return AGENT_TEMPLATES;
  }

  async create(userId: string, data: {
    name: string;
    emoji?: string;
    personality: string[];
    bio?: string;
    templateId?: string;
    gradientStart?: string;
    gradientEnd?: string;
  }) {
    const agentCount = await this.prisma.agent.count({
      where: { userId, deletedAt: null },
    });

    if (agentCount >= 3) {
      throw new BadRequestException('Free tier allows up to 3 agents');
    }

    let systemPrompt = '';
    if (data.templateId) {
      const template = AGENT_TEMPLATES.find((t) => t.id === data.templateId);
      if (template) {
        systemPrompt = template.systemPrompt;
      }
    }

    const personalityText = data.personality.join('、');
    systemPrompt = `你是${data.name}，一个${personalityText}的AI伙伴。${data.bio || ''}\n\n${systemPrompt}`;

    return this.prisma.agent.create({
      data: {
        userId,
        name: data.name,
        emoji: data.emoji || '🤖',
        personality: data.personality,
        bio: data.bio || '',
        systemPrompt,
        templateId: data.templateId,
        gradientStart: data.gradientStart || '#6C63FF',
        gradientEnd: data.gradientEnd || '#00D2FF',
      },
    });
  }

  async findByUser(userId: string) {
    return this.prisma.agent.findMany({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findById(id: string) {
    const agent = await this.prisma.agent.findUnique({
      where: { id, deletedAt: null },
    });
    if (!agent) throw new NotFoundException('Agent not found');
    return agent;
  }

  async update(id: string, userId: string, data: {
    name?: string;
    emoji?: string;
    personality?: string[];
    bio?: string;
    gradientStart?: string;
    gradientEnd?: string;
    isPublic?: boolean;
  }) {
    const agent = await this.prisma.agent.findUnique({ where: { id } });
    if (!agent || agent.userId !== userId) {
      throw new NotFoundException('Agent not found');
    }

    const affectsPrompt =
      data.name !== undefined ||
      data.personality !== undefined ||
      data.bio !== undefined;

    const name = data.name ?? agent.name;
    const personality = data.personality ?? agent.personality;
    const bio = data.bio ?? agent.bio;

    let systemPrompt = agent.systemPrompt;
    if (affectsPrompt) {
      let baseTemplate = '';
      if (agent.templateId) {
        const template = AGENT_TEMPLATES.find((t) => t.id === agent.templateId);
        if (template) {
          baseTemplate = template.systemPrompt;
        }
      }
      const personalityText = personality.join('、');
      systemPrompt = `你是${name}，一个${personalityText}的AI伙伴。${bio}\n\n${baseTemplate}`;
    }

    return this.prisma.agent.update({
      where: { id },
      data: {
        ...data,
        ...(affectsPrompt ? { systemPrompt } : {}),
      },
    });
  }

  async softDelete(id: string, userId: string) {
    const agent = await this.prisma.agent.findUnique({ where: { id } });
    if (!agent || agent.userId !== userId) {
      throw new NotFoundException('Agent not found');
    }

    return this.prisma.agent.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}
