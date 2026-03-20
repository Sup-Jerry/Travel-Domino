import { Injectable } from '@nestjs/common';
import { SocialCredentialDto } from '../auth/dto/auth.dto';

@Injectable()
export class SocialService {
  async verifyCredential(providerType: string, credential: SocialCredentialDto): Promise<string> {
    const uid = (credential.unionId || credential.openId || credential.authCode || credential.idToken || '').trim();
    if (!uid) {
      return '';
    }

    // 生产模式下预留真实校验入口。
    if (String(process.env.AUTH_USE_STUB_PROVIDERS || 'false').toLowerCase() !== 'true') {
      // TODO: HUAWEI/WECHAT/QQ 真实服务端校验接入点
      // 当前先返回 uid，避免阻塞联调。
      return `${providerType}:${uid}`;
    }

    return `${providerType}:${uid}`;
  }
}
