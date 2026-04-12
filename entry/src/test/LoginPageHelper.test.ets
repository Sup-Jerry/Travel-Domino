import { describe, it, expect } from '@ohos/hypium';
import {
  parseHuaweiLoginErrorCodeFromMessage,
  resolveLoginAgreementRequiredToast,
  resolveLoginFailureToast,
  shouldUseHuaweiApiFallbackByCode
} from '../main/ets/pages/LoginPage';

export default function loginPageHelperTest() {
  describe('unit_test_case_generator_autofill_LoginPageHelper', () => {
    it('normal: login_page_parse_error_code_should_extract_numeric_code', 0, () => {
      // Arrange
      const message = 'huawei_login_error_1001502003_xxx';
      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      // Assert
      expect(code).assertEqual(1001502003);
    });

    it('boundary: login_page_fallback_should_only_trigger_for_target_code', 0, () => {
      // Arrange
      const code = 1001502003;
      // Act
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);
      // Assert
      expect(shouldFallback).assertTrue();
    });

    it('invalid: login_page_parse_error_code_should_return_nan_for_bad_text', 0, () => {
      // Arrange
      const message = 'bad_message';
      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      // Assert
      expect(Number.isNaN(code)).assertTrue();
    });

    it('conflict: login_page_fallback_should_reject_nearby_code_value', 0, () => {
      // Arrange
      const code = 1001502002;
      // Act
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);
      // Assert
      expect(shouldFallback).assertFalse();
    });

    it('regression: td-20260412-login_page_agreement_toast_should_keep_exact_copy', 0, () => {
      // Arrange
      // Act
      const message = resolveLoginAgreementRequiredToast();
      // Assert
      expect(message).assertEqual('请先勾选《用户协议》和《隐私政策》');
    });

    it('combined: login_page_failure_toast_should_prefix_and_keep_message_body', 0, () => {
      // Arrange
      const prefix = '登录失败：';
      const detail = 'network_down';
      // Act
      const message = resolveLoginFailureToast(prefix, detail);
      // Assert
      expect(message).assertEqual('登录失败：network_down');
    });
  });
}
