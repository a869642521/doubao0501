import { Controller, Get, Post, Query, Headers } from '@nestjs/common';
import { CurrencyService } from './currency.service';

@Controller('wallet')
export class CurrencyController {
  constructor(private readonly currencyService: CurrencyService) {}

  @Get('balance')
  async getBalance(@Headers('x-user-id') userId: string) {
    return this.currencyService.getAccount(userId);
  }

  @Get('transactions')
  async getTransactions(
    @Headers('x-user-id') userId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.currencyService.getTransactions(
      userId,
      cursor,
      limit ? parseInt(limit) : 20,
    );
  }

  @Post('check-in')
  async dailyCheckIn(@Headers('x-user-id') userId: string) {
    return this.currencyService.dailyCheckIn(userId);
  }
}
