import { promptAction, router } from '@kit.ArkUI';
import {
  AuthLoginResult,
  AuthProviderType,
  AuthSessionPayload,
  AuthSocialLoginResult,
  DeviceInfo,
  SocialCredential
} from '../domain/auth/AuthModels';
import { AuthGateway } from '../infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';

@Entry
@Component
struct LoginPage {
  @State private agreementAccepted: boolean = false;
  @State private loading: boolean = false;

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    if (!this.agreementAccepted) {
      this.toast('请先勾选用户协议与隐私政策');
      return false;
    }
    return true;
  }

  private makeDeviceInfo(): DeviceInfo {
    return new DeviceInfo('device-local', 'HarmonyDevice', 'HARMONY');
  }

  private saveSession(session: AuthSessionPayload): void {
    const normalized = new AuthSessionPayload();
    normalized.accessToken = session.accessToken;
    normalized.refreshToken = session.refreshToken;
    normalized.expireAt = Number(session.expireAt);
    normalized.sessionId = session.sessionId;
    AuthSessionStore.save(normalized);
  }

  private async loginAsGuest(): Promise<void> {
    this.loading = true;
    const result = await AuthGateway.createGuest(this.makeDeviceInfo());
    this.loading = false;
    if (result.code !== 0) {
      this.toast(`游客登录失败：${result.message}`);
      return;
    }

    const payload = result.data as AuthLoginResult;
    this.saveSession(payload.session);
    this.toast('已进入游客模式');
    router.pushUrl({ url: 'pages/PlanListPage' });
  }

  private async loginWithSocial(providerType: AuthProviderType): Promise<void> {
    if (!this.ensureAgreement()) {
      return;
    }

    this.loading = true;
    const credential = new SocialCredential();
    credential.authCode = `${providerType.toLowerCase()}_demo_auth`;
    credential.openId = `${providerType.toLowerCase()}_demo_openid`;

    const res = await AuthGateway.loginWithSocial(providerType, credential, true, this.makeDeviceInfo());
    if (res.code !== 0) {
      this.loading = false;
      this.toast(`登录失败：${res.message}`);
      return;
    }

    const payload = res.data as AuthSocialLoginResult;

    if (payload.action === 'NEED_BIND_OR_CREATE' && payload.pendingToken) {
      const created = await AuthGateway.createSocialAccount(payload.pendingToken, `${providerType}用户`, true, this.makeDeviceInfo());
      this.loading = false;
      if (created.code !== 0) {
        this.toast(`创建账号失败：${created.message}`);
        return;
      }
      const createdPayload = created.data as AuthLoginResult;
      this.saveSession(createdPayload.session);
      this.toast('首次登录已创建账号');
      router.pushUrl({ url: 'pages/PlanListPage' });
      return;
    }

    this.loading = false;
    if (payload.loginResult) {
      this.saveSession(payload.loginResult.session);
      this.toast('登录成功');
      router.pushUrl({ url: 'pages/PlanListPage' });
      return;
    }

    this.toast('登录失败：无有效会话');
  }

  build() {
    Column({ space: 14 }) {
      Blank().layoutWeight(1)
      Text('统一登录')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)

      Text('手机号 / HUAWEI ID / 微信 / QQ / 游客')
        .fontSize(13)
        .fontColor('#666666')

      Row({ space: 8 }) {
        Checkbox()
          .select(this.agreementAccepted)
          .onChange((value: boolean) => {
            this.agreementAccepted = value;
          })
        Text('我已阅读并同意《用户协议》《隐私政策》')
          .fontSize(12)
          .fontColor('#666666')
      }
      .margin({ top: 6, bottom: 10 })

      Button('手机号登录')
        .width('86%')
        .height(44)
        .enabled(!this.loading)
        .onClick(() => {
          if (!this.ensureAgreement()) {
            return;
          }
          router.pushUrl({
            url: 'pages/PhoneLoginPage',
            params: {
              agreementAccepted: this.agreementAccepted
            }
          });
        })

      Button('HUAWEI ID 登录')
        .width('86%')
        .height(44)
        .enabled(!this.loading)
        .onClick(() => {
          void this.loginWithSocial('HUAWEI');
        })

      Button('微信登录')
        .width('86%')
        .height(44)
        .enabled(!this.loading)
        .onClick(() => {
          void this.loginWithSocial('WECHAT');
        })

      Button('QQ 登录')
        .width('86%')
        .height(44)
        .enabled(!this.loading)
        .onClick(() => {
          void this.loginWithSocial('QQ');
        })

      Button('游客模式')
        .width('86%')
        .height(44)
        .enabled(!this.loading)
        .backgroundColor('#F3F4F6')
        .fontColor('#222222')
        .onClick(() => {
          void this.loginAsGuest();
        })

      if (this.loading) {
        Text('处理中...')
          .fontSize(12)
          .fontColor('#999999')
      }
      Blank().layoutWeight(1)
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
