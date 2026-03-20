import { Injectable } from '@nestjs/common';

interface SmsSendResult {
  codeHash: string;
  channel: string;
  expiredAt: number;
}

@Injectable()
export class SmsService {
  async sendCode(_phoneNumber: string, _countryCode: string, _bizType: string): Promise<SmsSendResult> {
    const code = `${Math.floor(Math.random() * 900000) + 100000}`;
    return {
      codeHash: code,
      channel: process.env.SMS_PROVIDER || 'PRODUCTION_ADAPTER',
      expiredAt: Date.now() + 5 * 60 * 1000
    };
  }
}
