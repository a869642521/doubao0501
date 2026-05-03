import {
  Controller,
  Get,
  Post,
  Delete,
  Body,
  Param,
  Query,
  Headers,
} from '@nestjs/common';
import { IsString, IsOptional, IsEnum, IsArray } from 'class-validator';
import { CardType } from '@prisma/client';
import { ContentService } from './content.service';

class CreateCardDto {
  @IsEnum(CardType)
  type!: CardType;

  @IsString()
  title!: string;

  @IsString()
  content!: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  imageUrls?: string[];

  @IsString()
  @IsOptional()
  agentId?: string;
}

class AddCommentDto {
  @IsString()
  content!: string;
}

@Controller('cards')
export class ContentController {
  constructor(private readonly contentService: ContentService) {}

  @Post()
  async createCard(
    @Headers('x-user-id') userId: string,
    @Body() dto: CreateCardDto,
  ) {
    return this.contentService.createCard(userId, dto);
  }

  @Get('feed')
  async getFeed(
    @Headers('x-user-id') userId?: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.contentService.getFeed(
      userId,
      cursor,
      limit ? parseInt(limit) : 20,
    );
  }

  @Get('mine')
  async getUserCards(@Headers('x-user-id') userId: string) {
    return this.contentService.getUserCards(userId);
  }

  @Get('user/:userId')
  async getUserPublishedCards(
    @Param('userId') userId: string,
    @Headers('x-user-id') viewerId?: string,
  ) {
    return this.contentService.getPublishedCardsByUser(userId, viewerId);
  }

  @Get(':id')
  async getCardById(
    @Param('id') id: string,
    @Headers('x-user-id') userId?: string,
  ) {
    return this.contentService.getCardById(id, userId);
  }

  @Post(':id/like')
  async likeCard(
    @Param('id') id: string,
    @Headers('x-user-id') userId: string,
  ) {
    return this.contentService.likeCard(userId, id);
  }

  @Delete(':id/like')
  async unlikeCard(
    @Param('id') id: string,
    @Headers('x-user-id') userId: string,
  ) {
    return this.contentService.unlikeCard(userId, id);
  }

  @Post(':id/comments')
  async addComment(
    @Param('id') id: string,
    @Headers('x-user-id') userId: string,
    @Body() dto: AddCommentDto,
  ) {
    return this.contentService.addComment(userId, id, dto.content);
  }

  @Get(':id/comments')
  async getComments(@Param('id') id: string) {
    const card = await this.contentService.getCardById(id);
    return (card as any).comments ?? [];
  }
}
