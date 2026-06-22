import { describe, it, expect } from '@ohos/hypium';
import {
  buildHuaweiLoginErrorToken,
  createHuaweiAccountLoginButtonForTest,
  hasHuaweiCredentialData,
  resolveHuaweiLoginErrorCode,
  resolveHuaweiLoginErrorMessage
} from '../main/ets/pages/components/auth/HuaweiAccountLoginButton';

class MockHuaweiLoginError {
  code: number = 0;
  message: string = '';
}

class MockHuaweiCredentialData {
  authorizationCode: string = '';
}

interface HuaweiAccountLoginButtonPrivateTest {
  agreementAccepted: boolean;
  updateStateVars(params: HuaweiAccountLoginButtonParamsTest): void;
}

interface HuaweiAccountLoginButtonParamsTest {
  agreementAccepted?: boolean;
}

export default function huaweiAccountLoginButtonHelperTest() {
  describe('unit_test_case_generator_autofill_HuaweiAccountLoginButtonHelper', () => {
    it('combined: huawei_login_button_update_state_vars_should_replace_agreement_flag', 0, () => {
      // Arrange
      const button = createHuaweiAccountLoginButtonForTest() as Object as HuaweiAccountLoginButtonPrivateTest;
      button.agreementAccepted = false;

      // Act
      button.updateStateVars({ agreementAccepted: true });

      // Assert
      expect(button.agreementAccepted).assertTrue();
    });

    it('normal: huawei_login_should_extract_error_code_and_message', 0, () => {
      // Arrange
      const err = new MockHuaweiLoginError();
      err.code = 1001500001;
      err.message = 'network_busy';
      // Act
      const code = resolveHuaweiLoginErrorCode(err);
      const message = resolveHuaweiLoginErrorMessage(err);
      // Assert
      expect(code).assertEqual(1001500001);
      expect(message).assertEqual('network_busy');
    });

    it('boundary: huawei_login_should_default_error_code_to_zero_when_missing', 0, () => {
      // Arrange
      const err = new MockHuaweiLoginError();
      // Act
      const code = resolveHuaweiLoginErrorCode(err);
      // Assert
      expect(code).assertEqual(0);
    });

    it('invalid: huawei_login_should_default_error_message_to_empty_when_missing', 0, () => {
      // Arrange
      const err = new MockHuaweiLoginError();
      err.code = 1;
      // Act
      const message = resolveHuaweiLoginErrorMessage(err);
      // Assert
      expect(message).assertEqual('');
    });

    it('conflict: huawei_login_should_distinguish_empty_and_non_empty_credential_data', 0, () => {
      // Arrange
      const emptyData = undefined;
      const validData = new MockHuaweiCredentialData();
      validData.authorizationCode = 'abc';
      // Act
      const empty = hasHuaweiCredentialData(emptyData);
      const valid = hasHuaweiCredentialData(validData);
      // Assert
      expect(empty).assertFalse();
      expect(valid).assertTrue();
    });

    it('regression: td-20260412-huawei-login-error-token-format-should-stay-stable', 0, () => {
      // Arrange
      const code = 7;
      const message = 'fail';
      // Act
      const token = buildHuaweiLoginErrorToken(code, message);
      // Assert
      expect(token).assertEqual('huawei_login_error_7_fail');
    });

    it('combined: huawei_login_error_extract_and_token_build_should_chain', 0, () => {
      // Arrange
      const err = new MockHuaweiLoginError();
      err.code = 9;
      err.message = 'timeout';
      // Act
      const code = resolveHuaweiLoginErrorCode(err);
      const message = resolveHuaweiLoginErrorMessage(err);
      const token = buildHuaweiLoginErrorToken(code, message);
      // Assert
      expect(token).assertEqual('huawei_login_error_9_timeout');
    });
  });
}
