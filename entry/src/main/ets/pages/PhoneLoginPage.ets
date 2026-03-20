import { promptAction, router } from '@kit.ArkUI';
import { AuthCodeSendResult, AuthLoginResult, AuthSessionPayload, DeviceInfo } from '../domain/auth/AuthModels';
import { AuthGateway } from '../infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';

interface PhoneLoginRouteParams {
  agreementAccepted?: boolean;
}

@Entry
@Component
struct PhoneLoginPage {
  @State private phoneNumber: string = '';
  @State private code: string = '';
  @State private loading: boolean = false;
  @State private agreementAccepted: boolean = false;
  @State private countdown: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as PhoneLoginRouteParams;
    this.agreementAccepted = params?.agreementAccepted === true;
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

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

  private startCooldown(seconds: number): void {
    this.countdown = seconds;
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
    this.timerId = setInterval(() => {
      this.countdown -= 1;
      if (this.countdown <= 0 && this.timerId !== -1) {
        clearInterval(this.timerId);
        this.timerId = -1;
      }
    }, 1000);
  }

  private async sendCode(): Promise<void> {
    if (!this.ensureAgreement()) {
      return;
    }
    const result = await AuthGateway.sendPhoneCode(this.phoneNumber, '+86', 'REGISTER_LOGIN', 'device-local', '127.0.0.1');
    if (result.code !== 0) {
      this.toast(`发送失败：${result.message}`);
      return;
    }
    const sendResult = result.data as AuthCodeSendResult;
    this.startCooldown(sendResult.retryAfterSeconds);
    this.toast('验证码已发送');
  }

  private async loginByPhone(): Promise<void> {
    if (!this.ensureAgreement()) {
      return;
    }
    this.loading = true;
    const result = await AuthGateway.loginWithPhone(this.phoneNumber, '+86', this.code, true, this.makeDeviceInfo());
    this.loading = false;

    if (result.code !== 0) {
      this.toast(`登录失败：${result.message}`);
      return;
    }

    const payload = result.data as AuthLoginResult;
    this.saveSession(payload.session);
    this.toast(payload.isNewUser ? '注册并登录成功' : '登录成功');
    router.pushUrl({ url: 'pages/PlanListPage' });
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回')
          .type(ButtonType.Capsule)
          .onClick(() => {
            router.back();
          })
        Blank()
      }
      .width('100%')

      Text('手机号验证码登录')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)

      TextInput({ placeholder: '请输入手机号', text: this.phoneNumber })
        .width('86%')
        .onChange((value: string) => {
          this.phoneNumber = value.trim();
        })

      Row({ space: 8 }) {
        TextInput({ placeholder: '请输入验证码', text: this.code })
          .layoutWeight(1)
          .onChange((value: string) => {
            this.code = value.trim();
          })

        Button(this.countdown > 0 ? `${this.countdown}s` : '发送验证码')
          .enabled(this.countdown <= 0 && this.phoneNumber.length >= 6)
          .onClick(() => {
            void this.sendCode();
          })
      }
      .width('86%')

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
      .width('86%')

      Button('登录 / 注册')
        .width('86%')
        .height(44)
        .enabled(!this.loading)
        .onClick(() => {
          void this.loginByPhone();
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
    .alignItems(HorizontalAlign.Center)
  }
}
