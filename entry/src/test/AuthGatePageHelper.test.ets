import { describe, it, expect } from '@ohos/hypium';
import { LoginStatus } from '../main/ets/domain/auth/AuthTypes';
import {
  resolveAuthGateCheckingText,
  resolveAuthGateTargetUrl,
  shouldAuthGateRouteToPlanList
} from '../main/ets/pages/AuthGatePage';
import { shouldLoginSceneStart } from '../main/ets/pages/LoginPage';

export default function authGatePageHelperTest() {
  describe('unit_test_case_generator_autofill_AuthGatePageHelper', () => {
    it('normal: auth_gate_should_route_to_plan_list_when_authenticated', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.AUTHENTICATED;
      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      // Assert
      expect(shouldRoute).assertTrue();
    });

    it('boundary: auth_gate_target_url_should_fallback_to_login_when_success_false', 0, () => {
      // Arrange
      const success = false;
      const status = LoginStatus.AUTHENTICATED;
      // Act
      const target = resolveAuthGateTargetUrl(success, status);
      // Assert
      expect(target).assertEqual('pages/LoginPage');
    });

    it('invalid: auth_gate_should_not_route_to_plan_list_when_status_unauthenticated', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.UNAUTHENTICATED;
      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      // Assert
      expect(shouldRoute).assertFalse();
    });

    it('conflict: auth_gate_target_url_should_prioritize_status_over_success_like_login_guard', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.LOGIN_FAILED;
      // Act
      const target = resolveAuthGateTargetUrl(success, status);
      // Assert
      expect(target).assertEqual('pages/LoginPage');
    });

    it('regression: td-20260412-auth_gate_checking_text_should_keep_loading_copy', 0, () => {
      // Arrange
      const checking = true;
      // Act
      const text = resolveAuthGateCheckingText(checking);
      // Assert
      expect(text).assertEqual('正在检查登录状态...');
    });

    it('combined: auth_gate_helpers_should_return_login_route_and_jump_text_after_checking', 0, () => {
      // Arrange
      const success = false;
      const status = LoginStatus.UNAUTHENTICATED;
      // Act
      const target = resolveAuthGateTargetUrl(success, status);
      const text = resolveAuthGateCheckingText(false);
      // Assert
      expect(target).assertEqual('pages/LoginPage');
      expect(text).assertEqual('正在跳转...');
    });
    it('regression: guest_login_should_be_allowed_to_override_huawei_inflight', 0, () => {
      // Arrange
      const huaweiBusy = 'huawei';
      // Act
      const allowGuest = shouldLoginSceneStart(huaweiBusy, 'guest', true);
      const allowDuplicateHuawei = shouldLoginSceneStart(huaweiBusy, 'huawei', false);
      // Assert
      expect(allowGuest).assertTrue();
      expect(allowDuplicateHuawei).assertFalse();
    });
  });
}
