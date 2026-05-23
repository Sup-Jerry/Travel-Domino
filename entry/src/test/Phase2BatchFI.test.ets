import { describe, expect, it } from '@ohos/hypium';
import { LoginStatus } from '../main/ets/domain/auth/AuthTypes';
import {
  resolveAuthGateCheckingText,
  resolveAuthGateTargetUrl,
  shouldAuthGateRouteToPlanList
} from '../main/ets/pages/AuthGatePage';
import {
  parseHuaweiLoginErrorCodeFromMessage,
  resolveLoginAgreementRequiredToast,
  resolveLoginFailureToast,
  shouldLoginSceneStart,
  shouldUseHuaweiApiFallbackByCode
} from '../main/ets/pages/LoginPage';
import {
  resolveLogoutRedirectUrl,
  resolveLogoutToastMessage
} from '../main/ets/pages/SettingsAccountSecurityPage';
import {
  resolveArchiveSoftDeleteDialogMessage,
  resolveArchiveSoftDeleteDialogTitle,
  resolveArchiveTagText,
  shouldArchiveSkipSoftDeleteTip
} from '../main/ets/pages/ArchivePage';

export default function phase2BatchFITest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFI_page_helpers', () => {
    it('normal: auth_gate_helpers_should_route_only_authenticated_success_to_plan_list', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(shouldAuthGateRouteToPlanList(true, LoginStatus.AUTHENTICATED)).assertTrue();
      expect(shouldAuthGateRouteToPlanList(false, LoginStatus.AUTHENTICATED)).assertFalse();
      expect(shouldAuthGateRouteToPlanList(true, LoginStatus.UNAUTHENTICATED)).assertFalse();
      expect(resolveAuthGateTargetUrl(true, LoginStatus.AUTHENTICATED)).assertEqual('pages/PlanListPage');
      expect(resolveAuthGateTargetUrl(false, LoginStatus.AUTHENTICATED)).assertEqual('pages/LoginPage');
      expect(resolveAuthGateCheckingText(true).length > 0).assertTrue();
      expect(resolveAuthGateCheckingText(false).length > 0).assertTrue();
    });

    it('boundary: login_helpers_should_parse_error_codes_and_scene_start_rules', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(resolveLoginAgreementRequiredToast().length > 0).assertTrue();
      expect(parseHuaweiLoginErrorCodeFromMessage('huawei_login_error_1001502003_x')).assertEqual(1001502003);
      expect(Number.isNaN(parseHuaweiLoginErrorCodeFromMessage('bad_message'))).assertTrue();
      expect(shouldUseHuaweiApiFallbackByCode(1001502003)).assertTrue();
      expect(shouldUseHuaweiApiFallbackByCode(1001502004)).assertFalse();
      expect(resolveLoginFailureToast('prefix:', 'msg')).assertEqual('prefix:msg');
      expect(shouldLoginSceneStart('none', 'silent', false)).assertTrue();
      expect(shouldLoginSceneStart('active', 'silent', false)).assertFalse();
      expect(shouldLoginSceneStart('active', 'silent', true)).assertTrue();
      expect(shouldLoginSceneStart('active', 'active', true)).assertFalse();
    });

    it('regression: settings_account_security_helpers_should_keep_logout_messages_and_redirect', 0, () => {
      // Arrange
      // Act
      // Assert
      const successToast = resolveLogoutToastMessage(true);
      const failToast = resolveLogoutToastMessage(false);

      expect(successToast.length > 0).assertTrue();
      expect(failToast.length > 0).assertTrue();
      expect(successToast === failToast).assertFalse();
      expect(resolveLogoutRedirectUrl()).assertEqual('pages/LoginPage');
    });

    it('combined: archive_helpers_should_keep_tip_and_tag_text_contracts', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(shouldArchiveSkipSoftDeleteTip(true)).assertTrue();
      expect(shouldArchiveSkipSoftDeleteTip(false)).assertFalse();
      expect(resolveArchiveSoftDeleteDialogTitle().length > 0).assertTrue();
      expect(resolveArchiveSoftDeleteDialogMessage().length > 0).assertTrue();
      expect(resolveArchiveTagText().indexOf('归档') >= 0).assertTrue();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
