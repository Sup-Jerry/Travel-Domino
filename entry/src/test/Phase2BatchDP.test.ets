import { describe, it, expect } from '@ohos/hypium';
import {
  buildHuaweiLoginErrorToken,
  createHuaweiAccountLoginButtonForTest,
  hasHuaweiCredentialData,
  resolveHuaweiLoginErrorCode,
  resolveHuaweiLoginErrorMessage
} from '../main/ets/pages/components/auth/HuaweiAccountLoginButton';
import { HuaweiCredential } from '../main/ets/domain/auth/AuthTypes';

interface HuaweiButtonPrivateDP {
  agreementAccepted: boolean;
  onCredential: (credential: HuaweiCredential) => void;
  onError: (message: string) => void;
  aboutToAppear(): void;
  onAgreementAcceptedChanged(): void;
  initialRender(): void;
}

class HuaweiCredentialDataDP {
  authorizationCode: string = '';
  idToken: string = '';
  openID: string = '';
  unionID: string = '';
}

class HuaweiLoginErrorDP {
  code: number = 0;
  message: string = '';
}

class HuaweiControllerMockDP {
  public statuses: number[] = [];
  public callback: ((err: Object, data: HuaweiCredentialDataDP | undefined) => void) | null = null;

  onClickLoginWithHuaweiIDButton(callback: (err: Object, data: HuaweiCredentialDataDP | undefined) => void): void {
    this.callback = callback;
  }

  setAgreementStatus(status: number): void {
    this.statuses.push(Number(status));
  }

  trigger(err: Object, data: HuaweiCredentialDataDP | undefined): void {
    if (this.callback) {
      this.callback(err, data);
    }
  }
}

function createButtonDP(controller: HuaweiControllerMockDP): HuaweiButtonPrivateDP {
  const button = createHuaweiAccountLoginButtonForTest() as HuaweiButtonPrivateDP;
  Reflect.set(button as Object, 'controller', controller);
  return button;
}

function createErrorDP(code: number, message: string): HuaweiLoginErrorDP {
  const err = new HuaweiLoginErrorDP();
  err.code = code;
  err.message = message;
  return err;
}

function createDataDP(code: string = 'auth-dp'): HuaweiCredentialDataDP {
  const data = new HuaweiCredentialDataDP();
  data.authorizationCode = code;
  data.idToken = 'id-dp';
  data.openID = 'open-dp';
  data.unionID = 'union-dp';
  return data;
}

export default function phase2BatchDPTest() {
  describe('phase2BatchDPTest', () => {
    it('normal: huawei_button_about_to_appear_should_bind_callback_and_apply_agreement', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);

      // Act
      button.agreementAccepted = false;
      button.aboutToAppear();

      // Assert
      expect(controller.callback !== null).assertTrue();
      expect(controller.statuses.length).assertEqual(1);
    });

    it('boundary: huawei_button_agreement_change_should_update_controller_each_time', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);

      // Act
      button.agreementAccepted = true;
      button.onAgreementAcceptedChanged();
      button.agreementAccepted = false;
      button.onAgreementAcceptedChanged();

      // Assert
      expect(controller.statuses.length >= 2).assertTrue();
    });

    it('invalid: huawei_button_callback_should_emit_error_token_for_non_zero_code', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);
      let errorMessage = '';
      let credentialCount = 0;
      button.onError = (message: string): void => {
        errorMessage = message;
      };
      button.onCredential = (_credential: HuaweiCredential): void => {
        credentialCount += 1;
      };

      // Act
      button.aboutToAppear();
      controller.trigger(createErrorDP(1001, 'network'), createDataDP());

      // Assert
      expect(errorMessage).assertEqual(buildHuaweiLoginErrorToken(1001, 'network'));
      expect(credentialCount).assertEqual(0);
    });

    it('conflict: huawei_button_callback_should_reject_empty_credential_data', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);
      let errorMessage = '';
      button.onError = (message: string): void => {
        errorMessage = message;
      };

      // Act
      button.aboutToAppear();
      controller.trigger(createErrorDP(0, ''), undefined);

      // Assert
      expect(errorMessage).assertEqual('huawei_credential_empty');
    });

    it('regression: huawei_button_callback_should_map_credential_fields_stably', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);
      let received = new HuaweiCredential();
      button.onCredential = (credential: HuaweiCredential): void => {
        received = credential;
      };

      // Act
      button.aboutToAppear();
      controller.trigger(createErrorDP(0, ''), createDataDP('auth-regression-dp'));

      // Assert
      expect(received.authorizationCode).assertEqual('auth-regression-dp');
      expect(received.idToken).assertEqual('id-dp');
      expect(received.openId).assertEqual('open-dp');
      expect(received.unionId).assertEqual('union-dp');
    });

    it('boundary: huawei_button_callback_should_keep_success_path_when_agreement_already_accepted', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);
      let received = new HuaweiCredential();
      let errorMessage = '';
      button.agreementAccepted = true;
      button.onCredential = (credential: HuaweiCredential): void => {
        received = credential;
      };
      button.onError = (message: string): void => {
        errorMessage = message;
      };

      // Act
      button.aboutToAppear();
      controller.trigger(createErrorDP(0, ''), createDataDP('auth-agreement-dp'));

      // Assert
      expect(errorMessage).assertEqual('');
      expect(received.authorizationCode).assertEqual('auth-agreement-dp');
    });

    it('combined: huawei_button_helpers_and_render_should_remain_available', 0, () => {
      // Arrange
      const controller = new HuaweiControllerMockDP();
      const button = createButtonDP(controller);
      const err = createErrorDP(7, 'timeout');
      let threw = false;

      // Act
      const code = resolveHuaweiLoginErrorCode(err);
      const message = resolveHuaweiLoginErrorMessage(err);
      const hasData = hasHuaweiCredentialData(createDataDP());
      try {
        button.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(code).assertEqual(7);
      expect(message).assertEqual('timeout');
      expect(hasData).assertTrue();
      expect(threw).assertFalse();
    });
  });
}
