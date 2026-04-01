import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthResult, HuaweiCredential, UserSession } from '../domain/auth/AuthTypes';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { HuaweiAccountLoginButton } from './components/auth/HuaweiAccountLoginButton';

@Entry
@Component
struct LoginPage {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'LoginPage';
  @State private agreementAccepted: boolean = false;
  @State private loading: boolean = false;
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ensureAgreement accepted=${this.agreementAccepted ? 1 : 0}`);
    if (!this.agreementAccepted) {
      this.toast('请先勾选《用户协议》和《隐私政策》');
      return false;
    }
    return true;
  }

  private async replaceUrl(url: string): Promise<void> {
    await this.getUIContext().getRouter().replaceUrl({ url: url });
  }

  private async loginWithHuaweiButton(credential: HuaweiCredential): Promise<void> {
    hilog.info(
      LoginPage.LOG_DOMAIN,
      LoginPage.LOG_TAG,
      `[LOGIN_TRACE][page] click agreement=${this.agreementAccepted ? 1 : 0}, authCodeLen=${credential.authorizationCode.length}, openIdLen=${credential.openId.length}, unionIdLen=${credential.unionId.length}`
    );
    if (!this.ensureAgreement()) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, '[LOGIN_TRACE][page] blocked by agreement');
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.loading = true;
    let result = new AuthResult<UserSession>();
    try {
      result = await this.authFacade.explicitLoginByButton(credential, false);
    } finally {
      this.loading = false;
    }
    if (!result.success) {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] login fail code=${result.code}, message=${result.message}, source=${result.source}`
      );
      this.toast(`登录失败：${result.message}`);
      return;
    }
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] login success source=${result.source}`);
    this.toast('登录成功');
    await this.replaceUrl('pages/PlanListPage');
  }

  private async loginWithHuaweiApiFallback(): Promise<void> {
    if (!this.ensureAgreement()) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, '[LOGIN_TRACE][page] api_fallback blocked by agreement');
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.loading = true;
    let result = new AuthResult<UserSession>();
    try {
      result = await this.authFacade.explicitLoginByButton(undefined, false);
    } finally {
      this.loading = false;
    }
    if (!result.success) {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] api_fallback fail code=${result.code}, message=${result.message}, source=${result.source}`
      );
      this.toast(`登录失败：${result.message}`);
      return;
    }
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] api_fallback success source=${result.source}`);
    this.toast('登录成功');
    await this.replaceUrl('pages/PlanListPage');
  }

  private async loginAsGuest(): Promise<void> {
    if (!this.ensureAgreement()) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, '[LOGIN_TRACE][page] guest_login blocked by agreement');
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    this.loading = true;
    let result = new AuthResult<UserSession>();
    try {
      result = await this.authFacade.explicitGuestLogin();
    } finally {
      this.loading = false;
    }
    if (!result.success) {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] guest_login fail code=${result.code}, message=${result.message}, source=${result.source}`
      );
      this.toast(`游客登录失败：${result.message}`);
      return;
    }
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] guest_login success source=${result.source}`);
    this.toast('游客登录成功');
    await this.replaceUrl('pages/PlanListPage');
  }

  build() {
    Column() {
      Column({ space: 8 }) {
        Text('Travel Domino')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
        Text('智能行程规划，从登录开始')
          .fontSize(14)
          .fontColor('#6B7280')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ top: 24, bottom: 22 })

      Column({ space: 14 }) {
        Text('账号登录')
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor('#111827')
          .width('100%')
          .textAlign(TextAlign.Start)

        Text('优先使用华为账号登录')
          .fontSize(13)
          .fontColor('#6B7280')
          .width('100%')
          .textAlign(TextAlign.Start)

        Row({ space: 8 }) {
          Checkbox()
            .select(this.agreementAccepted)
            .onChange((value: boolean) => {
              this.agreementAccepted = value;
              hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] agreement checkbox changed=${value ? 1 : 0}`);
            })
          Text('我已阅读并同意《用户协议》《隐私政策》')
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .width('100%')
        .margin({ top: 2, bottom: 6 })

        HuaweiAccountLoginButton({
          agreementAccepted: this.agreementAccepted,
          onCredential: (credential: HuaweiCredential) => {
            void this.loginWithHuaweiButton(credential);
          },
          onError: (message: string) => {
            const codeText = message.replace('huawei_login_error_', '').split('_')[0];
            const code = Number(codeText);
            hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] button error message=${message}, code=${code}`);
            if (!this.ensureAgreement()) {
              hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, '[LOGIN_TRACE][page] block fallback by agreement');
              return;
            }
            if (code === 1001502003) {
              hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, '[LOGIN_TRACE][page] trigger api_fallback by code=1001502003');
              void this.loginWithHuaweiApiFallback();
              return;
            }
            this.toast(`华为账号登录失败：${message}`);
          }
        })

        Button('游客登录')
          .width('100%')
          .height(44)
          .backgroundColor('#EEF2FF')
          .fontColor('#1F2937')
          .borderRadius(10)
          .onClick(() => {
            void this.loginAsGuest();
          })

        if (this.loading) {
          Text('处理中，请稍候...')
            .width('100%')
            .textAlign(TextAlign.Center)
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 22, bottom: 22 })
      .backgroundColor('#FFFFFF')
      .borderRadius(22)

      Blank().layoutWeight(1)

      Text('可通过上方按钮使用游客模式继续。')
        .fontSize(12)
        .fontColor('#9CA3AF')
        .margin({ bottom: 12 })
    }
    .padding({ left: 24, right: 24, top: 8, bottom: 12 })
    .backgroundColor('#F5F7FB')
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }
}


