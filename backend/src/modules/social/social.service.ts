import { Injectable } from '@nestjs/common';

interface SocialCredentialLite {
  unionId?: string;
  openId?: string;
  authCode?: string;
  idToken?: string;
}

@Injectable()
export class SocialService {
  async verifyCredential(providerType: string, credential: SocialCredentialLite): Promise<string> {
    const uid = (credential.unionId || credential.openId || credential.authCode || credential.idToken || '').trim();
    if (!uid) {
      return '';
    }
    return `${providerType}:${uid}`;
  }
}
