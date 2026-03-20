import { promptAction, router } from '@kit.ArkUI';
import { AuthIdentityView, AuthMeResult, AuthProviderType, SocialCredential } from '../domain/auth/AuthModels';
import { AuthGateway } from '../infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';

@Entry
@Component
struct AccountCenterPage {
  @State private userId: string = '';
  @State private nickname: string = '';
  @State private isGuest: boolean = false;
  @State private identities: AuthIdentityView[] = [];
  @State private phoneToBind: string = '';
  @State private codeToBind: string = '';

  aboutToAppear(): void {
    void this.reload();
  }

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private accessToken(): string {
    return AuthSessionStore.getAccessToken();
  }

  private async reload(): Promise<void> {
    const token = this.accessToken();
    if (!token) {
      this.toast('登录状态失效，请重新登录');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }

    const me = await AuthGateway.me(token);
    if (me.code !== 0) {
      AuthSessionStore.clear();
      this.toast('登录状态失效，请重新登录');
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }

    const meData = me.data as AuthMeResult;
    this.userId = meData.userId;
    this.nickname = meData.nickname;
    this.isGuest = meData.isGuest;

    const ids = await AuthGateway.listIdentities(token);
    if (ids.code === 0) {
      this.identities = ids.data as AuthIdentityView[];
    }
  }

  private async sendBindCode(): Promise<void> {
    const res = await AuthGateway.sendPhoneCode(this.phoneToBind, '+86', 'BIND_PHONE', 'device-local', '127.0.0.1');
    if (res.code !== 0) {
      this.toast(`发送失败：${res.message}`);
      return;
    }
    this.toast('验证码已发送');
  }

  private async bindPhone(): Promise<void> {
    const res = await AuthGateway.bindPhone(this.accessToken(), this.phoneToBind, '+86', this.codeToBind);
    if (res.code !== 0) {
      this.toast(`绑定失败：${res.message}`);
      return;
    }
    this.toast('手机号绑定成功');
    await this.reload();
  }

  private async bindSocial(provider: AuthProviderType): Promise<void> {
    const credential = new SocialCredential();
    credential.authCode = `${provider.toLowerCase()}_bind_auth`;
    credential.openId = `${provider.toLowerCase()}_bind_openid`;

    const res = await AuthGateway.bindSocial(this.accessToken(), provider, credential);
    if (res.code !== 0) {
      this.toast(`绑定失败：${res.message}`);
      return;
    }
    this.toast(`${provider} 绑定成功`);
    await this.reload();
  }

  private async unbind(provider: AuthProviderType): Promise<void> {
    const res = await AuthGateway.unbind(this.accessToken(), provider);
    if (res.code !== 0) {
      this.toast(`解绑失败：${res.message}`);
      return;
    }
    this.toast(`${provider} 解绑成功`);
    await this.reload();
  }

  private async logout(): Promise<void> {
    const session = AuthSessionStore.load();
    if (!session) {
      AuthSessionStore.clear();
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    await AuthGateway.logout(session.accessToken, session.sessionId);
    AuthSessionStore.clear();
    this.toast('已退出登录');
    router.pushUrl({ url: 'pages/LoginPage' });
  }

  private async logoutAll(): Promise<void> {
    const token = this.accessToken();
    if (!token) {
      return;
    }
    const res = await AuthGateway.logoutAll(token);
    if (res.code !== 0) {
      this.toast(`操作失败：${res.message}`);
      return;
    }
    AuthSessionStore.clear();
    this.toast('所有设备已退出');
    router.pushUrl({ url: 'pages/LoginPage' });
  }

  private async requestCancel(): Promise<void> {
    const res = await AuthGateway.cancelRequest(this.accessToken(), 'reauth_confirmed', '不再使用');
    if (res.code !== 0) {
      this.toast(`注销申请失败：${res.message}`);
      return;
    }
    this.toast('注销申请已提交(PENDING)');
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Button('返回')
          .onClick(() => {
            router.back();
          })
        Blank()
      }
      .width('100%')

      Text('账号中心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)

      Text(`用户ID: ${this.userId}`)
        .fontSize(13)
      Text(`昵称: ${this.nickname}`)
        .fontSize(13)
      Text(`账号类型: ${this.isGuest ? '游客' : '正式账号'}`)
        .fontSize(13)

      Divider().width('100%')

      Text('已绑定方式')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      ForEach(this.identities, (item: AuthIdentityView) => {
        Row() {
          Text(`${item.providerType}: ${item.displayName}`)
            .layoutWeight(1)
            .fontSize(13)
          if (item.bound) {
            Button('解绑')
              .height(30)
              .fontSize(12)
              .onClick(() => {
                void this.unbind(item.providerType);
              })
          }
        }
        .width('100%')
      }, (item: AuthIdentityView) => item.providerType)

      Divider().width('100%')

      Text('绑定手机号')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      TextInput({ placeholder: '手机号', text: this.phoneToBind })
        .width('100%')
        .onChange((value: string) => {
          this.phoneToBind = value.trim();
        })
      Row({ space: 8 }) {
        TextInput({ placeholder: '验证码', text: this.codeToBind })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.codeToBind = value.trim();
          })
        Button('发送验证码')
          .onClick(() => {
            void this.sendBindCode();
          })
      }
      .width('100%')
      Button('绑定手机号')
        .width('100%')
        .onClick(() => {
          void this.bindPhone();
        })

      Row({ space: 8 }) {
        Button('绑定HUAWEI')
          .layoutWeight(1)
          .onClick(() => {
            void this.bindSocial('HUAWEI');
          })
        Button('绑定微信')
          .layoutWeight(1)
          .onClick(() => {
            void this.bindSocial('WECHAT');
          })
        Button('绑定QQ')
          .layoutWeight(1)
          .onClick(() => {
            void this.bindSocial('QQ');
          })
      }
      .width('100%')

      Divider().width('100%')

      Button('退出当前设备')
        .width('100%')
        .onClick(() => {
          void this.logout();
        })
      Button('退出所有设备')
        .width('100%')
        .onClick(() => {
          void this.logoutAll();
        })
      Button('申请注销账号')
        .width('100%')
        .backgroundColor('#FDECEC')
        .fontColor('#C62828')
        .onClick(() => {
          void this.requestCancel();
        })
    }
    .padding(20)
    .width('100%')
    .height('100%')
  }
}
