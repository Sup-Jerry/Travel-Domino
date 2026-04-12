import { describe, it, expect } from '@ohos/hypium';
import {
  resolveLogoutRedirectUrl,
  resolveLogoutToastMessage
} from '../main/ets/pages/SettingsAccountSecurityPage';

export default function settingsAccountSecurityPageHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsAccountSecurityPageHelper', () => {
    it('normal: settings_account_security_logout_success_toast_should_not_be_empty', 0, () => {
      // Arrange
      const success = true;
      // Act
      const text = resolveLogoutToastMessage(success);
      // Assert
      expect(text.trim().length > 0).assertTrue();
    });

    it('boundary: settings_account_security_logout_failure_toast_should_not_be_empty', 0, () => {
      // Arrange
      const success = false;
      // Act
      const text = resolveLogoutToastMessage(success);
      // Assert
      expect(text.trim().length > 0).assertTrue();
    });

    it('invalid: settings_account_security_logout_toast_for_true_and_false_should_differ', 0, () => {
      // Arrange
      const successText = true;
      const failedText = false;
      // Act
      const success = resolveLogoutToastMessage(successText);
      const failed = resolveLogoutToastMessage(failedText);
      // Assert
      expect(success === failed).assertFalse();
    });

    it('conflict: settings_account_security_redirect_should_target_login_page', 0, () => {
      // Arrange
      const expected = 'pages/LoginPage';
      // Act
      const url = resolveLogoutRedirectUrl();
      // Assert
      expect(url).assertEqual(expected);
    });

    it('regression: td-20260412-settings_account_security_redirect_should_start_with_pages_prefix', 0, () => {
      // Arrange
      const prefix = 'pages/';
      // Act
      const url = resolveLogoutRedirectUrl();
      // Assert
      expect(url.indexOf(prefix) === 0).assertTrue();
    });

    it('combined: settings_account_security_helper_chain_should_keep_success_path_stable', 0, () => {
      // Arrange
      const success = true;
      // Act
      const toast = resolveLogoutToastMessage(success);
      const url = resolveLogoutRedirectUrl();
      const valid = toast.length > 0 && url === 'pages/LoginPage';
      // Assert
      expect(valid).assertTrue();
    });
  });
}
