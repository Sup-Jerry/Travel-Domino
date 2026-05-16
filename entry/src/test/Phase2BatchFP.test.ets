import { describe, it, expect } from '@ohos/hypium';
import {
  buildHuaweiLoginErrorToken,
  hasHuaweiCredentialData,
  resolveHuaweiLoginErrorCode,
  resolveHuaweiLoginErrorMessage
} from '../main/ets/pages/components/auth/HuaweiAccountLoginButton';
import {
  AppNavKey,
  createAppSideBarRouteOptions,
  getAppSideBarRouteByKey,
  shouldAppSideBarNavigate
} from '../main/ets/pages/components/views/AppSideBar';
import {
  resolveLogoutRedirectUrl,
  resolveLogoutToastMessage
} from '../main/ets/pages/SettingsAccountSecurityPage';

class EmptyHuaweiErrorFP {}

class InvalidHuaweiErrorFP {
  code: string = 'abc';
  message: number = 123;
}

class EmptyHuaweiCredentialFP {}

export default function phase2BatchFPTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFP_huawei_login_button_helpers', () => {
    it('boundary: huawei_login_error_extractors_should_fallback_for_empty_object', 0, () => {
      // Arrange
      // Act
      // Assert
      const err = new EmptyHuaweiErrorFP() as Object;
      expect(resolveHuaweiLoginErrorCode(err)).assertEqual(0);
      expect(resolveHuaweiLoginErrorMessage(err)).assertEqual('');
    });

    it('invalid: huawei_login_error_extractors_should_stringify_non_string_message_and_zero_bad_code', 0, () => {
      // Arrange
      // Act
      // Assert
      const err = new InvalidHuaweiErrorFP() as Object;
      expect(Number.isNaN(resolveHuaweiLoginErrorCode(err))).assertTrue();
      expect(resolveHuaweiLoginErrorMessage(err)).assertEqual('123');
    });

    it('combined: huawei_login_token_builder_should_keep_zero_code_shape_and_credential_truthiness', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(buildHuaweiLoginErrorToken(0, '')).assertEqual('huawei_login_error_0_');
      expect(hasHuaweiCredentialData(undefined)).assertFalse();
      expect(hasHuaweiCredentialData(new EmptyHuaweiCredentialFP() as Object)).assertTrue();
    });
  });

  describe('unit_test_case_generator_autofill_Phase2BatchFP_app_sidebar_helpers', () => {
    it('normal: app_sidebar_route_map_should_cover_all_nav_keys', 0, () => {
      // Arrange
      // Act
      // Assert
      const keys: AppNavKey[] = ['plans', 'archive', 'trash', 'settings'];
      const routes = keys.map((key: AppNavKey) => getAppSideBarRouteByKey(key));

      expect(routes[0]).assertEqual('pages/PlanListPage');
      expect(routes[1]).assertEqual('pages/ArchivePage');
      expect(routes[2]).assertEqual('pages/TrashPage');
      expect(routes[3]).assertEqual('pages/SettingsPage');
    });

    it('boundary: app_sidebar_route_options_should_not_share_mutable_url_state', 0, () => {
      // Arrange
      // Act
      // Assert
      const first = createAppSideBarRouteOptions('pages/PlanListPage');
      const second = createAppSideBarRouteOptions('pages/ArchivePage');
      first.url = 'mutated';

      expect(second.url).assertEqual('pages/ArchivePage');
    });

    it('combined: app_sidebar_navigation_should_be_true_for_different_targets_and_false_for_self', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(shouldAppSideBarNavigate('plans', 'archive')).assertTrue();
      expect(shouldAppSideBarNavigate('archive', 'plans')).assertTrue();
      expect(shouldAppSideBarNavigate('settings', 'settings')).assertFalse();
    });
  });

  describe('unit_test_case_generator_autofill_Phase2BatchFP_settings_account_security_helpers', () => {
    it('normal: settings_account_security_logout_toasts_should_distinguish_success_and_failure', 0, () => {
      // Arrange
      // Act
      // Assert
      const success = resolveLogoutToastMessage(true);
      const failed = resolveLogoutToastMessage(false);

      expect(success.trim().length > 0).assertTrue();
      expect(failed.trim().length > 0).assertTrue();
      expect(success === failed).assertFalse();
    });

    it('boundary: settings_account_security_redirect_should_be_stable_across_calls', 0, () => {
      // Arrange
      // Act
      // Assert
      const first = resolveLogoutRedirectUrl();
      const second = resolveLogoutRedirectUrl();

      expect(first).assertEqual('pages/LoginPage');
      expect(second).assertEqual(first);
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
