import { Controller, Get, Post, Patch, Body, Param, Headers } from '@nestjs/common';
import { UserService } from './user.service';
import { IsString, IsOptional } from 'class-validator';

class QuickLoginDto {
  @IsString()
  phone!: string;
}

class UpdateProfileDto {
  @IsString()
  @IsOptional()
  nickname?: string;

  @IsString()
  @IsOptional()
  avatarUrl?: string;
}

@Controller('users')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @Post('quick-login')
  async quickLogin(@Body() dto: QuickLoginDto) {
    return this.userService.quickLogin(dto.phone);
  }

  @Get(':id')
  async findById(@Param('id') id: string) {
    return this.userService.findById(id);
  }

  @Patch(':id')
  async updateProfile(@Param('id') id: string, @Body() dto: UpdateProfileDto) {
    return this.userService.updateProfile(id, dto);
  }
}
