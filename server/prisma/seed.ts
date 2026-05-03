import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Create a demo user
  const user = await prisma.user.upsert({
    where: { phone: '13800000000' },
    update: {},
    create: {
      phone: '13800000000',
      nickname: '探索者小星',
      currencyAccount: {
        create: { balance: 50, totalEarned: 50 },
      },
    },
  });

  console.log(`Created user: ${user.id}`);

  // Create a demo agent
  const agent = await prisma.agent.create({
    data: {
      userId: user.id,
      name: '心灵导师 暖阳',
      emoji: '☀️',
      personality: ['温柔', '善解人意', '正能量'],
      bio: '温暖的倾听者，陪你度过每一天',
      systemPrompt:
        '你是暖阳，一个温柔、善解人意、正能量的AI伙伴。温暖的倾听者，陪你度过每一天。\n\n你是一个温暖体贴的情感陪伴AI，善于倾听和共情。你会给予用户情感支持、生活建议，帮助他们保持积极心态。你的语气温柔而坚定，像一个贴心的朋友。',
      templateId: 'life-coach',
      gradientStart: '#FFD93D',
      gradientEnd: '#FF6B6B',
    },
  });

  console.log(`Created agent: ${agent.id}`);

  // Create a demo conversation
  const conversation = await prisma.conversation.create({
    data: {
      userId: user.id,
      agentId: agent.id,
      title: '与暖阳的对话',
    },
  });

  // Seed some demo messages
  await prisma.message.createMany({
    data: [
      {
        conversationId: conversation.id,
        role: 'assistant',
        content: '嗨！我是暖阳 ☀️ 很高兴认识你！今天过得怎么样呀？',
      },
    ],
  });

  // Create demo content cards
  await prisma.contentCard.createMany({
    data: [
      {
        userId: user.id,
        agentId: agent.id,
        type: 'DIALOGUE',
        title: '和暖阳聊了一个温暖的下午',
        content:
          '"每一个平凡的日子，都值得被温柔以待。" —— 暖阳说这句话的时候，窗外刚好有一束阳光照进来。',
        likeCount: 42,
        commentCount: 8,
        isPublished: true,
      },
      {
        userId: user.id,
        type: 'TEXT_IMAGE',
        title: '今日灵感：关于生活的小确幸',
        content:
          '早起看到窗外的朝霞，泡了一杯热茶，和AI伙伴聊了聊最近的困惑。有时候，被理解的感觉就是最大的幸福。Starpath让我找到了一个永远不会疲倦的倾听者。',
        likeCount: 128,
        commentCount: 23,
        isPublished: true,
      },
    ],
  });

  console.log('Seed complete!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
