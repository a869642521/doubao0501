import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CardType } from '@prisma/client';
import { CurrencyService } from '../currency/currency.service';

@Injectable()
export class ContentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly currencyService: CurrencyService,
  ) {}

  async createCard(
    userId: string,
    data: {
      type: CardType;
      title: string;
      content: string;
      imageUrls?: string[];
      agentId?: string;
    },
  ) {
    const card = await this.prisma.contentCard.create({
      data: {
        userId,
        agentId: data.agentId,
        type: data.type,
        title: data.title,
        content: data.content,
        imageUrls: data.imageUrls || [],
        isPublished: true,
      },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: {
          select: {
            id: true,
            name: true,
            emoji: true,
            gradientStart: true,
            gradientEnd: true,
          },
        },
      },
    });

    await this.currencyService.earnFromPublish(userId);

    return { ...card, isLiked: false };
  }

  async getFeed(userId?: string, cursor?: string, limit = 20) {
    const where: any = { isPublished: true, deletedAt: null };
    if (cursor) {
      where.createdAt = { lt: new Date(cursor) };
    }

    const cards = await this.prisma.contentCard.findMany({
      where,
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: {
          select: {
            id: true,
            name: true,
            emoji: true,
            gradientStart: true,
            gradientEnd: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
    });

    // Resolve isLiked in bulk
    let likedCardIds = new Set<string>();
    if (userId && cards.length > 0) {
      const cardIds = cards.slice(0, limit).map((c) => c.id);
      const likes = await this.prisma.like.findMany({
        where: { userId, cardId: { in: cardIds } },
        select: { cardId: true },
      });
      likedCardIds = new Set(likes.map((l) => l.cardId));
    }

    const hasMore = cards.length > limit;
    const items = cards.slice(0, limit);
    const nextCursor = hasMore
      ? items[items.length - 1].createdAt.toISOString()
      : null;

    return {
      items: items.map((card) => ({
        ...card,
        isLiked: likedCardIds.has(card.id),
      })),
      nextCursor,
    };
  }

  async getCardById(id: string, userId?: string) {
    const card = await this.prisma.contentCard.findUnique({
      where: { id, deletedAt: null },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: {
          select: {
            id: true,
            name: true,
            emoji: true,
            gradientStart: true,
            gradientEnd: true,
          },
        },
        comments: {
          include: {
            user: { select: { id: true, nickname: true, avatarUrl: true } },
          },
          orderBy: { createdAt: 'desc' },
          take: 50,
        },
      },
    });
    if (!card) throw new NotFoundException('Card not found');

    let isLiked = false;
    if (userId) {
      const like = await this.prisma.like.findUnique({
        where: { userId_cardId: { userId, cardId: id } },
      });
      isLiked = !!like;
    }

    return { ...card, isLiked };
  }

  async likeCard(userId: string, cardId: string) {
    const existing = await this.prisma.like.findUnique({
      where: { userId_cardId: { userId, cardId } },
    });
    if (existing) throw new ConflictException('Already liked');

    await this.prisma.$transaction([
      this.prisma.like.create({ data: { userId, cardId } }),
      this.prisma.contentCard.update({
        where: { id: cardId },
        data: { likeCount: { increment: 1 } },
      }),
    ]);

    const card = await this.prisma.contentCard.findUnique({
      where: { id: cardId },
    });
    if (card) {
      await this.currencyService.earnFromLike(card.userId);
    }

    return { liked: true };
  }

  async unlikeCard(userId: string, cardId: string) {
    try {
      await this.prisma.$transaction([
        this.prisma.like.delete({
          where: { userId_cardId: { userId, cardId } },
        }),
        this.prisma.contentCard.update({
          where: { id: cardId },
          data: { likeCount: { decrement: 1 } },
        }),
      ]);
    } catch {
      // Already unliked — silently succeed
    }
    return { liked: false };
  }

  async addComment(userId: string, cardId: string, content: string) {
    const comment = await this.prisma.comment.create({
      data: { userId, cardId, content },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
      },
    });

    await this.prisma.contentCard.update({
      where: { id: cardId },
      data: { commentCount: { increment: 1 } },
    });

    const card = await this.prisma.contentCard.findUnique({
      where: { id: cardId },
    });
    if (card) {
      await this.currencyService.earnFromComment(card.userId);
    }

    return comment;
  }

  async getUserCards(userId: string) {
    const cards = await this.prisma.contentCard.findMany({
      where: { userId, deletedAt: null },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: {
          select: {
            id: true,
            name: true,
            emoji: true,
            gradientStart: true,
            gradientEnd: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return cards.map((card) => ({ ...card, isLiked: false }));
  }

  /** 某用户已发布的卡片（个人主页展示）；可选当前浏览者用于解析 isLiked。 */
  async getPublishedCardsByUser(cardAuthorId: string, viewerId?: string) {
    const cards = await this.prisma.contentCard.findMany({
      where: {
        userId: cardAuthorId,
        isPublished: true,
        deletedAt: null,
      },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: {
          select: {
            id: true,
            name: true,
            emoji: true,
            gradientStart: true,
            gradientEnd: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 60,
    });

    let likedCardIds = new Set<string>();
    if (viewerId && cards.length > 0) {
      const cardIds = cards.map((c) => c.id);
      const likes = await this.prisma.like.findMany({
        where: { userId: viewerId, cardId: { in: cardIds } },
        select: { cardId: true },
      });
      likedCardIds = new Set(likes.map((l) => l.cardId));
    }

    return cards.map((card) => ({
      ...card,
      isLiked: likedCardIds.has(card.id),
    }));
  }
}
