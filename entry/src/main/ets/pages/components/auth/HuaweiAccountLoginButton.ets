import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { HuaweiCredential } from '../../../domain/auth/AuthTypes';
import { hilog } from '@kit.PerformanceAnalysisKit';

type HuaweiCredentialAction = (credential: HuaweiCredential) => void;
type HuaweiErrorAction = (message: string) => void;

export function resolveHuaweiLoginErrorCode(err: Object): number {
  return Number((err as Record<string, Object>)?.code || 0);
}

export function resolveHuaweiLoginErrorMessage(err: Object): string {
  return String((err as Record<string, Object>)?.message || '');
}

export function buildHuaweiLoginErrorToken(errorCode: number, errorMessage: string): string {
  return `huawei_login_error_${errorCode}_${errorMessage}`;
}

export function hasHuaweiCredentialData(data: Object | undefined): boolean {
  return !!data;
}

@Component
export struct HuaweiAccountLoginButton {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'HuaweiLoginButton';
  @Prop @Watch('onAgreementAcceptedChanged') agreementAccepted: boolean = false;
  onCredential: HuaweiCredentialAction = () => {};
  onError: HuaweiErrorAction = () => {};
  private controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController();

  aboutToAppear(): void {
    hilog.info(HuaweiAccountLoginButton.LOG_DOMAIN, HuaweiAccountLoginButton.LOG_TAG, '[LOGIN_TRACE][button] aboutToAppear');
    this.bindLoginCallback();
    this.onAgreementAcceptedChanged();
  }

  private bindLoginCallback(): void {
    hilog.info(HuaweiAccountLoginButton.LOG_DOMAIN, HuaweiAccountLoginButton.LOG_TAG, '[LOGIN_TRACE][button] bind callback');
    this.controller.onClickLoginWithHuaweiIDButton((err: Object, data: loginComponentManager.HuaweiIDCredential) => {
      const errorCode = resolveHuaweiLoginErrorCode(err);
      const errorMessage = resolveHuaweiLoginErrorMessage(err);
      const rawErr = JSON.stringify(err);
      hilog.info(
        HuaweiAccountLoginButton.LOG_DOMAIN,
        HuaweiAccountLoginButton.LOG_TAG,
        `[LOGIN_TRACE][button] callback code=${errorCode}, message=${errorMessage}, hasData=${data ? 1 : 0}, agreement=${this.agreementAccepted ? 1 : 0}, raw=${rawErr}`
      );
      if (Number.isFinite(errorCode) && errorCode !== 0) {
        hilog.warn(
          HuaweiAccountLoginButton.LOG_DOMAIN,
          HuaweiAccountLoginButton.LOG_TAG,
          `[LOGIN_TRACE][button] fail code=${errorCode}, message=${errorMessage}, raw=${rawErr}`
        );
        this.onError(buildHuaweiLoginErrorToken(errorCode, errorMessage));
        return;
      }
      if (!hasHuaweiCredentialData(data)) {
        hilog.warn(HuaweiAccountLoginButton.LOG_DOMAIN, HuaweiAccountLoginButton.LOG_TAG, '[LOGIN_TRACE][button] fail empty_credential');
        this.onError('huawei_credential_empty');
        return;
      }
      const credential = new HuaweiCredential();
      credential.authorizationCode = data.authorizationCode || '';
      credential.idToken = data.idToken || '';
      credential.openId = data.openID || '';
      credential.unionId = data.unionID || '';
      const authCodeLen = credential.authorizationCode.length;
      const openIdLen = credential.openId.length;
      const unionIdLen = credential.unionId.length;
      hilog.info(
        HuaweiAccountLoginButton.LOG_DOMAIN,
        HuaweiAccountLoginButton.LOG_TAG,
        `[LOGIN_TRACE][button] success authCodeLen=${authCodeLen}, openIdLen=${openIdLen}, unionIdLen=${unionIdLen}`
      );
      this.onCredential(credential);
    });
  }

  private onAgreementAcceptedChanged(): void {
    hilog.info(
      HuaweiAccountLoginButton.LOG_DOMAIN,
      HuaweiAccountLoginButton.LOG_TAG,
      `[LOGIN_TRACE][button] agreement_changed=${this.agreementAccepted ? 1 : 0}`
    );
    this.controller.setAgreementStatus(
      this.agreementAccepted
        ? loginComponentManager.AgreementStatus.ACCEPTED
        : loginComponentManager.AgreementStatus.NOT_ACCEPTED
    );
  }

  build() {
    LoginWithHuaweiIDButton({
      params: {
        style: loginComponentManager.Style.BUTTON_RED
      },
      controller: this.controller
    })
      .width('100%')
      .height(48);
  }
}

export function createHuaweiAccountLoginButtonForTest(): Object {
  return new HuaweiAccountLoginButton(undefined, {} as LocalStorage);
}
