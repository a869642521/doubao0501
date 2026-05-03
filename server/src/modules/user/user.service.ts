import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import * as jwt from 'jsonwebtoken';

@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}

  async findById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id, deletedAt: null },
    });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async quickLogin(phone: string) {
    let user = await this.prisma.user.findUnique({ where: { phone } });

    if (!user) {
      user = await this.prisma.user.create({
        data: {
          phone,
          nickname: `用户${phone.slice(-4)}`,
          currencyAccount: {
            create: { balance: 50 },
          },
        },
      });
    }

    const secret = process.env.JWT_SECRET || 'dev-secret';
    const token = jwt.sign({ sub: user.id }, secret, { expiresIn: '30d' });

    return { user, token };
  }

  async updateProfile(id: string, data: { nickname?: string; avatarUrl?: string }) {
    return this.prisma.user.update({
      where: { id },
      data,
    });
  }
}
