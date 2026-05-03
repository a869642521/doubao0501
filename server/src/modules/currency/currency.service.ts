import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { TransactionType } from '@prisma/client';

const REWARD_PUBLISH = 10;
const REWARD_LIKE = 1;
const REWARD_COMMENT = 2;
const REWARD_CHECKIN = 5;
const COST_PER_MESSAGE = 1;
const FREE_DAILY_MESSAGES = 20;

@Injectable()
export class CurrencyService {
  constructor(private readonly prisma: PrismaService) {}

  async getAccount(userId: string) {
    let account = await this.prisma.currencyAccount.findUnique({
      where: { userId },
    });

    if (!account) {
      account = await this.prisma.currencyAccount.create({
        data: { userId, balance: 50 },
      });
    }

    return account;
  }

  async getTransactions(userId: string, cursor?: string, limit = 20) {
    const account = await this.getAccount(userId);
    const where: any = { accountId: account.id };
    if (cursor) {
      where.createdAt = { lt: new Date(cursor) };
    }

    return this.prisma.currencyTransaction.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async dailyCheckIn(userId: string) {
    const account = await this.getAccount(userId);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (account.lastCheckIn && account.lastCheckIn >= today) {
      throw new BadRequestException('今日已签到');
    }

    await this.prisma.$transaction([
      this.prisma.currencyAccount.update({
        where: { id: account.id },
        data: {
          balance: { increment: REWARD_CHECKIN },
          totalEarned: { increment: REWARD_CHECKIN },
          lastCheckIn: new Date(),
        },
      }),
      this.prisma.currencyTransaction.create({
        data: {
          accountId: account.id,
          amount: REWARD_CHECKIN,
          type: TransactionType.EARN,
          reason: '每日签到',
        },
      }),
    ]);

    return { reward: REWARD_CHECKIN };
  }

  async earnFromPublish(userId: string) {
    return this.earn(userId, REWARD_PUBLISH, '发布内容');
  }

  async earnFromLike(userId: string) {
    return this.earn(userId, REWARD_LIKE, '获得点赞');
  }

  async earnFromComment(userId: string) {
    return this.earn(userId, REWARD_COMMENT, '获得评论');
  }

  async handleMessageCost(userId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayMessageCount = await this.prisma.currencyTransaction.count({
      where: {
        account: { userId },
        reason: '发送消息',
        createdAt: { gte: today },
      },
    });

    if (todayMessageCount < FREE_DAILY_MESSAGES) {
      return; // still within free tier
    }

    return this.spend(userId, COST_PER_MESSAGE, '发送消息');
  }

  private async earn(userId: string, amount: number, reason: string) {
    const account = await this.getAccount(userId);
    await this.prisma.$transaction([
      this.prisma.currencyAccount.update({
        where: { id: account.id },
        data: {
          balance: { increment: amount },
          totalEarned: { increment: amount },
        },
      }),
      this.prisma.currencyTransaction.create({
        data: {
          accountId: account.id,
          amount,
          type: TransactionType.EARN,
          reason,
        },
      }),
    ]);
  }

  private async spend(userId: string, amount: number, reason: string) {
    const account = await this.getAccount(userId);

    if (account.balance < amount) {
      throw new BadRequestException('灵感币不足');
    }

    await this.prisma.$transaction([
      this.prisma.currencyAccount.update({
        where: { id: account.id },
        data: {
          balance: { decrement: amount },
          totalSpent: { increment: amount },
        },
      }),
      this.prisma.currencyTransaction.create({
        data: {
          accountId: account.id,
          amount: -amount,
          type: TransactionType.SPEND,
          reason,
        },
      }),
    ]);
  }
}
