import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthResult, HuaweiCredential, UserSession } from '../domain/auth/AuthTypes';
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { HuaweiAccountLoginButton } from './components/auth/HuaweiAccountLoginButton';
import { ProfileViewModel } from '../viewmodel/ProfileViewModel';

const HUAWEI_API_FALLBACK_ERROR_CODE = 1001502003;

export function resolveLoginAgreementRequiredToast(): string {
  return '请先勾选《用户协议》和《隐私政策》';
}

export function parseHuaweiLoginErrorCodeFromMessage(message: string): number {
  const codeText = (message || '').replace('huawei_login_error_', '').split('_')[0];
  const code = Number(codeText);
  return Number.isFinite(code) ? code : NaN;
}

export function shouldUseHuaweiApiFallbackByCode(code: number): boolean {
  return code === HUAWEI_API_FALLBACK_ERROR_CODE;
}

export function resolveLoginFailureToast(prefix: string, message: string): string {
  return `${prefix}${message}`;
}

export function shouldLoginSceneStart(activeScene: string, nextScene: string, allowOverride: boolean): boolean {
  const active = String(activeScene || 'none');
  const next = String(nextScene || 'none');
  if (active === 'none') {
    return true;
  }
  return allowOverride && active !== next;
}

@Entry
@Component
struct LoginPage {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'LoginPage';
  @State private agreementAccepted: boolean = false;
  @State private loading: boolean = false;
  @State private activeLoginScene: string = 'none';
  private loginGeneration: number = 0;
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();

  private createLoginTraceId(scene: string): string {
    return `${scene}_${Date.now()}`;
  }

  private toast(message: string): void {
    promptAction.openToast({ message });
  }

  private ensureAgreement(): boolean {
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ensureAgreement accepted=${this.agreementAccepted ? 1 : 0}`);
    if (!this.agreementAccepted) {
      this.toast(resolveLoginAgreementRequiredToast());
      return false;
    }
    return true;
  }

  private async replaceUrl(url: string): Promise<void> {
    try {
      await this.getUIContext().getRouter().replaceUrl({ url: url });
    } catch (error) {
      hilog.error(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `replaceUrl failed: ${JSON.stringify(error)}`);
    }
  }

  private async ensureCloudProfile(hostContext: common.Context, session: UserSession | null): Promise<void> {
    if (!session) {
      return;
    }
    const accountId = String(session.accountId || '').trim();
    if (!accountId) {
      return;
    }
    try {
      const profileViewModel = ProfileViewModel.getInstance();
      profileViewModel.bindContext(hostContext);
      const profile = await profileViewModel.ensureProfile(accountId);
      if (profile) {
        hilog.info(
          LoginPage.LOG_DOMAIN,
          LoginPage.LOG_TAG,
          `[PROFILE_TRACE][page] ensureProfile ok accountId=${accountId}, username=${profile.username}`
        );
        return;
      }
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[PROFILE_TRACE][page] ensureProfile empty accountId=${accountId}, state=${profileViewModel.getState()}`
      );
    } catch (error) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[PROFILE_TRACE][page] ensureProfile fail reason=${JSON.stringify(error)}`);
    }
  }

  private beginLogin(scene: string, allowOverride: boolean = false): number {
    if (!shouldLoginSceneStart(this.activeLoginScene, scene, allowOverride)) {
      return -1;
    }
    if (this.activeLoginScene !== 'none') {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] override login active=${this.activeLoginScene}, next=${scene}`
      );
    }
    this.loginGeneration += 1;
    this.activeLoginScene = scene;
    this.loading = true;
    return this.loginGeneration;
  }

  private finishLogin(scene: string, generation: number): void {
    if (generation !== this.loginGeneration || this.activeLoginScene !== scene) {
      return;
    }
    this.activeLoginScene = 'none';
    this.loading = false;
  }

  private isCurrentLogin(generation: number): boolean {
    return generation === this.loginGeneration;
  }

  private async loginWithHuaweiButton(credential: HuaweiCredential): Promise<void> {
    const traceId = this.createLoginTraceId('button');
    const generation = this.beginLogin('huawei');
    if (generation < 0) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ignore duplicated loginWithHuaweiButton trace=${traceId}`);
      return;
    }
    hilog.info(
      LoginPage.LOG_DOMAIN,
      LoginPage.LOG_TAG,
      `[LOGIN_TRACE][page] click agreement=${this.agreementAccepted ? 1 : 0}, authCodeLen=${credential.authorizationCode.length}, openIdLen=${credential.openId.length}, unionIdLen=${credential.unionId.length}, trace=${traceId}`
    );
    if (!this.ensureAgreement()) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] blocked by agreement trace=${traceId}`);
      this.finishLogin('huawei', generation);
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    let result = new AuthResult<UserSession>();
    try {
      result = await this.authFacade.explicitLoginByButton(credential, false);
    } catch (error) {
      if (!this.isCurrentLogin(generation)) {
        return;
      }
      hilog.error(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] login exception=${JSON.stringify(error)}, trace=${traceId}`);
      this.toast('登录异常，请检查网络后重试');
      return;
    } finally {
      this.finishLogin('huawei', generation);
    }
    if (!this.isCurrentLogin(generation)) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ignore stale huawei result trace=${traceId}`);
      return;
    }
    if (!result.success) {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] login fail code=${result.code}, message=${result.message}, source=${result.source}, trace=${traceId}`
      );
      this.toast(resolveLoginFailureToast('登录失败：', result.message));
      return;
    }
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] login success source=${result.source}, trace=${traceId}`);
    void this.ensureCloudProfile(hostContext, result.data);
    this.toast('登录成功');
    await this.replaceUrl('pages/PlanListPage');
  }

  private async loginWithHuaweiApiFallback(): Promise<void> {
    const traceId = this.createLoginTraceId('api_fallback');
    const generation = this.beginLogin('huawei');
    if (generation < 0) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ignore duplicated loginWithHuaweiApiFallback trace=${traceId}`);
      return;
    }
    if (!this.ensureAgreement()) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] api_fallback blocked by agreement trace=${traceId}`);
      this.finishLogin('huawei', generation);
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    let result = new AuthResult<UserSession>();
    try {
      result = await this.authFacade.explicitLoginByButton(undefined, false);
    } catch (error) {
      if (!this.isCurrentLogin(generation)) {
        return;
      }
      hilog.error(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] api_fallback exception=${JSON.stringify(error)}, trace=${traceId}`);
      this.toast('登录异常，请检查网络后重试');
      return;
    } finally {
      this.finishLogin('huawei', generation);
    }
    if (!this.isCurrentLogin(generation)) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ignore stale api_fallback result trace=${traceId}`);
      return;
    }
    if (!result.success) {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] api_fallback fail code=${result.code}, message=${result.message}, source=${result.source}, trace=${traceId}`
      );
      this.toast(resolveLoginFailureToast('登录失败：', result.message));
      return;
    }
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] api_fallback success source=${result.source}, trace=${traceId}`);
    void this.ensureCloudProfile(hostContext, result.data);
    this.toast('登录成功');
    await this.replaceUrl('pages/PlanListPage');
  }

  private async loginAsGuest(): Promise<void> {
    const traceId = this.createLoginTraceId('guest');
    const generation = this.beginLogin('guest', true);
    if (generation < 0) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ignore duplicated loginAsGuest trace=${traceId}`);
      return;
    }
    if (!this.ensureAgreement()) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] guest_login blocked by agreement trace=${traceId}`);
      this.finishLogin('guest', generation);
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    let result = new AuthResult<UserSession>();
    try {
      result = await this.authFacade.explicitGuestLogin();
    } catch (error) {
      if (!this.isCurrentLogin(generation)) {
        return;
      }
      hilog.error(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] guest_login exception=${JSON.stringify(error)}, trace=${traceId}`);
      this.toast('游客登录异常，请稍后重试');
      return;
    } finally {
      this.finishLogin('guest', generation);
    }
    if (!this.isCurrentLogin(generation)) {
      hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] ignore stale guest result trace=${traceId}`);
      return;
    }
    if (!result.success) {
      hilog.warn(
        LoginPage.LOG_DOMAIN,
        LoginPage.LOG_TAG,
        `[LOGIN_TRACE][page] guest_login fail code=${result.code}, message=${result.message}, source=${result.source}, trace=${traceId}`
      );
      this.toast(resolveLoginFailureToast('游客登录失败：', result.message));
      return;
    }
    hilog.info(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] guest_login success source=${result.source}, trace=${traceId}`);
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
            const traceId = this.createLoginTraceId('button_error');
            const code = parseHuaweiLoginErrorCodeFromMessage(message);
            hilog.warn(
              LoginPage.LOG_DOMAIN,
              LoginPage.LOG_TAG,
              `[LOGIN_TRACE][page] button error message=${message}, code=${code}, trace=${traceId}`
            );
            if (!this.ensureAgreement()) {
              hilog.warn(LoginPage.LOG_DOMAIN, LoginPage.LOG_TAG, `[LOGIN_TRACE][page] block fallback by agreement trace=${traceId}`);
              return;
            }
            if (shouldUseHuaweiApiFallbackByCode(code)) {
              hilog.info(
                LoginPage.LOG_DOMAIN,
                LoginPage.LOG_TAG,
                `[LOGIN_TRACE][page] trigger api_fallback by code=1001502003, trace=${traceId}`
              );
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

export function createLoginPageForTest(): Object {
  return new LoginPage(undefined, new LocalStorage()) as Object;
}


