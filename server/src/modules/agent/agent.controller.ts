import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Headers,
} from '@nestjs/common';
import { IsString, IsOptional, IsArray, IsBoolean } from 'class-validator';
import { AgentService } from './agent.service';

class CreateAgentDto {
  @IsString()
  name!: string;

  @IsString()
  @IsOptional()
  emoji?: string;

  @IsArray()
  @IsString({ each: true })
  personality!: string[];

  @IsString()
  @IsOptional()
  bio?: string;

  @IsString()
  @IsOptional()
  templateId?: string;

  @IsString()
  @IsOptional()
  gradientStart?: string;

  @IsString()
  @IsOptional()
  gradientEnd?: string;
}

class UpdateAgentDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsString()
  @IsOptional()
  emoji?: string;

  @IsArray()
  @IsString({ each: true })
  @IsOptional()
  personality?: string[];

  @IsString()
  @IsOptional()
  bio?: string;

  @IsString()
  @IsOptional()
  gradientStart?: string;

  @IsString()
  @IsOptional()
  gradientEnd?: string;

  @IsBoolean()
  @IsOptional()
  isPublic?: boolean;
}

@Controller('agents')
export class AgentController {
  constructor(private readonly agentService: AgentService) {}

  @Get('templates')
  getTemplates() {
    return this.agentService.getTemplates();
  }

  @Post()
  async create(
    @Headers('x-user-id') userId: string,
    @Body() dto: CreateAgentDto,
  ) {
    return this.agentService.create(userId, dto);
  }

  @Get()
  async findByUser(@Headers('x-user-id') userId: string) {
    return this.agentService.findByUser(userId);
  }

  @Get(':id')
  async findById(@Param('id') id: string) {
    return this.agentService.findById(id);
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Headers('x-user-id') userId: string,
    @Body() dto: UpdateAgentDto,
  ) {
    return this.agentService.update(id, userId, dto);
  }

  @Delete(':id')
  async delete(
    @Param('id') id: string,
    @Headers('x-user-id') userId: string,
  ) {
    return this.agentService.softDelete(id, userId);
  }
}
