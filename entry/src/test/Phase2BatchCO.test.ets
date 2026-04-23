import { describe, expect, it } from '@ohos/hypium';
import {
  createLoginPageForTest,
  parseHuaweiLoginErrorCodeFromMessage,
  resolveLoginAgreementRequiredToast,
  resolveLoginFailureToast,
  shouldLoginSceneStart,
  shouldUseHuaweiApiFallbackByCode
} from '../main/ets/pages/LoginPage';

interface LoginPagePrivateCO {
  agreementAccepted: boolean;
  loading: boolean;
  activeLoginScene: string;
  loginGeneration: number;
  initialRender(): void;
  beginLogin(scene: string, allowOverride?: boolean): number;
  finishLogin(scene: string, generation: number): void;
  isCurrentLogin(generation: number): boolean;
}

function createLoginPageCO(): LoginPagePrivateCO {
  return createLoginPageForTest() as LoginPagePrivateCO;
}

export default function phase2BatchCOTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCO_login_page_extra', () => {
    it('normal: login_page_error_code_parser_should_extract_code_with_suffix', 0, () => {
      // Arrange
      const message = 'huawei_login_error_1001502003_user_cancel';

      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);

      // Assert
      expect(code).assertEqual(1001502003);
      expect(shouldFallback).assertTrue();
    });

    it('boundary: login_page_error_code_parser_should_accept_plain_numeric_text', 0, () => {
      // Arrange
      const message = '1001502003';

      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);

      // Assert
      expect(code).assertEqual(1001502003);
    });

    it('invalid: login_page_error_code_parser_should_return_zero_for_blank_and_nan_for_non_numeric_prefix', 0, () => {
      // Arrange
      const blankMessage = '   ';
      const badMessage = 'huawei_login_error_bad_code';

      // Act
      const blankCode = parseHuaweiLoginErrorCodeFromMessage(blankMessage);
      const badCode = parseHuaweiLoginErrorCodeFromMessage(badMessage);

      // Assert
      expect(blankCode).assertEqual(0);
      expect(Number.isNaN(badCode)).assertTrue();
    });

    it('conflict: login_page_scene_start_should_block_duplicate_active_scene_without_override', 0, () => {
      // Arrange
      const activeScene = 'huawei';
      const nextScene = 'huawei';

      // Act
      const allowed = shouldLoginSceneStart(activeScene, nextScene, false);

      // Assert
      expect(allowed).assertFalse();
    });

    it('regression: login_page_scene_start_should_allow_different_scene_when_override_enabled', 0, () => {
      // Arrange
      const activeScene = 'huawei';
      const nextScene = 'guest';

      // Act
      const allowed = shouldLoginSceneStart(activeScene, nextScene, true);

      // Assert
      expect(allowed).assertTrue();
    });

    it('boundary: login_page_scene_start_should_allow_when_active_scene_is_blank_or_none', 0, () => {
      // Arrange
      const blankActive = '';
      const noneActive = 'none';

      // Act
      const blankAllowed = shouldLoginSceneStart(blankActive, 'guest', false);
      const noneAllowed = shouldLoginSceneStart(noneActive, 'huawei', false);

      // Assert
      expect(blankAllowed).assertTrue();
      expect(noneAllowed).assertTrue();
    });

    it('invalid: login_page_scene_start_should_reject_override_for_same_active_scene', 0, () => {
      // Arrange
      const activeScene = 'guest';
      const nextScene = 'guest';

      // Act
      const allowed = shouldLoginSceneStart(activeScene, nextScene, true);

      // Assert
      expect(allowed).assertFalse();
    });

    it('combined: login_page_failure_toast_should_concat_prefix_and_message_without_trimming', 0, () => {
      // Arrange
      const prefix = 'login_failed: ';
      const detail = ' network_down ';

      // Act
      const message = resolveLoginFailureToast(prefix, detail);

      // Assert
      expect(message).assertEqual('login_failed:  network_down ');
    });

    it('combined: login_page_agreement_toast_and_fallback_guard_should_stay_independent', 0, () => {
      // Arrange
      const targetCode = 1001502003;
      const nearbyCode = 1001502004;

      // Act
      const agreementToast = resolveLoginAgreementRequiredToast();
      const targetFallback = shouldUseHuaweiApiFallbackByCode(targetCode);
      const nearbyFallback = shouldUseHuaweiApiFallbackByCode(nearbyCode);

      // Assert
      expect(agreementToast.trim().length > 0).assertTrue();
      expect(targetFallback).assertTrue();
      expect(nearbyFallback).assertFalse();
    });

    it('combined: login_page_begin_and_finish_should_track_generation_for_same_scene', 0, () => {
      // Arrange
      const page = createLoginPageCO();

      // Act
      const generation = page.beginLogin('huawei');
      const currentAfterBegin = page.isCurrentLogin(generation);
      page.finishLogin('huawei', generation);

      // Assert
      expect(generation > 0).assertTrue();
      expect(currentAfterBegin).assertTrue();
      expect(page.activeLoginScene).assertEqual('none');
      expect(page.loading).assertFalse();
    });

    it('combined: login_page_begin_should_reject_duplicate_scene_until_current_finishes', 0, () => {
      // Arrange
      const page = createLoginPageCO();

      // Act
      const first = page.beginLogin('guest', true);
      const duplicate = page.beginLogin('guest', false);
      page.finishLogin('guest', first);

      // Assert
      expect(first > 0).assertTrue();
      expect(duplicate).assertEqual(-1);
      expect(page.activeLoginScene).assertEqual('none');
    });

    it('boundary: login_page_finish_should_ignore_stale_generation_and_wrong_scene', 0, () => {
      // Arrange
      const page = createLoginPageCO();

      // Act
      const generation = page.beginLogin('huawei');
      page.finishLogin('guest', generation);
      const afterWrongSceneCurrent = page.isCurrentLogin(generation);
      const sceneAfterWrongFinish = page.activeLoginScene;
      page.finishLogin('huawei', generation - 1);
      const sceneAfterStaleFinish = page.activeLoginScene;
      page.finishLogin('huawei', generation);

      // Assert
      expect(afterWrongSceneCurrent).assertTrue();
      expect(sceneAfterWrongFinish).assertEqual('huawei');
      expect(sceneAfterStaleFinish).assertEqual('huawei');
      expect(page.activeLoginScene).assertEqual('none');
      expect(page.loading).assertFalse();
    });

    it('combined: login_page_begin_override_should_advance_generation_and_replace_active_scene', 0, () => {
      // Arrange
      const page = createLoginPageCO();

      // Act
      const first = page.beginLogin('huawei');
      const second = page.beginLogin('guest', true);

      // Assert
      expect(first > 0).assertTrue();
      expect(second > first).assertTrue();
      expect(page.activeLoginScene).assertEqual('guest');
      expect(page.isCurrentLogin(first)).assertFalse();
      expect(page.isCurrentLogin(second)).assertTrue();
    });

    it('combined: login_page_render_should_cover_loading_and_idle_states', 0, () => {
      // Arrange
      const page = createLoginPageCO();

      // Act
      page.agreementAccepted = false;
      page.loading = false;
      page.initialRender();
      page.agreementAccepted = true;
      page.loading = true;
      page.activeLoginScene = 'guest';
      page.initialRender();

      // Assert
      expect(page.agreementAccepted).assertTrue();
      expect(page.loading).assertTrue();
      expect(page.activeLoginScene).assertEqual('guest');
    });
  });
}
