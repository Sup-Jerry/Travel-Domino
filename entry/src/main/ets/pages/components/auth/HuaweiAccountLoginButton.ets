import { LoginWithHuaweiIDButton, loginComponentManager } from '@kit.AccountKit';
import { HuaweiCredential } from '../../../domain/auth/AuthTypes';

@Component
export struct HuaweiAccountLoginButton {
  @Prop @Watch('onAgreementAcceptedChanged') agreementAccepted: boolean = false;
  onCredential: (credential: HuaweiCredential) => void = () => {};
  onError: (message: string) => void = () => {};
  private controller: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController();

  aboutToAppear(): void {
    this.bindLoginCallback();
    this.onAgreementAcceptedChanged();
  }

  private bindLoginCallback(): void {
    this.controller.onClickLoginWithHuaweiIDButton((err: Object, data: loginComponentManager.HuaweiIDCredential) => {
      const errorCode = Number((err as Record<string, Object>)?.code || 0);
      if (Number.isFinite(errorCode) && errorCode !== 0) {
        this.onError(`huawei_login_error_${errorCode}`);
        return;
      }
      if (!data) {
        this.onError('huawei_credential_empty');
        return;
      }
      const credential = new HuaweiCredential();
      credential.authorizationCode = data.authorizationCode || '';
      credential.idToken = data.idToken || '';
      credential.openId = data.openID || '';
      credential.unionId = data.unionID || '';
      this.onCredential(credential);
    });
  }

  private onAgreementAcceptedChanged(): void {
    this.controller.setAgreementStatus(
      this.agreementAccepted
        ? loginComponentManager.AgreementStatus.ACCEPTED
        : loginComponentManager.AgreementStatus.NOT_ACCEPTED
    );
  }

  build() {
    LoginWithHuaweiIDButton({
      params: {
        style: loginComponentManager.Style.BUTTON_RED,
        borderRadius: 14,
        textAndIconStyle: true,
        loginType: loginComponentManager.LoginType.ID
      },
      controller: this.controller
    })
      .width('100%')
      .height(48);
  }
}
