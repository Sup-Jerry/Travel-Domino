import { describe, it, expect } from '@ohos/hypium';
import {
  normalizeMyPageLightHintKey,
  normalizeMyPageUsername,
  resolveMyPageAgreementRequiredToast,
  shouldMyPageEmitLightHint
} from '../main/ets/pages/MyPage';

export default function myPageHelperTest() {
  describe('unit_test_case_generator_autofill_MyPageHelper', () => {
    it('normal: my_page_username_should_trim_and_keep_valid_chars', 0, () => {
      // Arrange
      const input = '  Alice_01 ';
      // Act
      const username = normalizeMyPageUsername(input);
      // Assert
      expect(username).assertEqual('Alice_01');
    });

    it('boundary: my_page_username_should_reject_length_over_32', 0, () => {
      // Arrange
      const input = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      // Act
      const username = normalizeMyPageUsername(input);
      // Assert
      expect(username).assertEqual('');
    });

    it('invalid: my_page_username_should_reject_unsupported_symbols', 0, () => {
      // Arrange
      const input = 'name@home';
      // Act
      const username = normalizeMyPageUsername(input);
      // Assert
      expect(username).assertEqual('');
    });

    it('conflict: my_page_light_hint_should_block_duplicate_within_dedup_window', 0, () => {
      // Arrange
      const lastKey = 'profile_offline:user1';
      const nextKey = 'profile_offline:user1';
      // Act
      const shouldEmit = shouldMyPageEmitLightHint(lastKey, 1000, nextKey, 2000, 2000);
      // Assert
      expect(shouldEmit).assertFalse();
    });

    it('regression: td-20260412-my_page_agreement_toast_should_keep_exact_copy', 0, () => {
      // Arrange
      // Act
      const message = resolveMyPageAgreementRequiredToast();
      // Assert
      expect(message).assertEqual('请先勾选《用户协议》和《隐私政策》');
    });

    it('combined: my_page_light_hint_key_normalization_and_emit_should_work_together', 0, () => {
      // Arrange
      const rawKey = '  profile_cloud_fail:user2  ';
      const normalizedKey = normalizeMyPageLightHintKey(rawKey);
      // Act
      const shouldEmit = shouldMyPageEmitLightHint('', 0, normalizedKey, 5000, 1000);
      // Assert
      expect(normalizedKey).assertEqual('profile_cloud_fail:user2');
      expect(shouldEmit).assertTrue();
    });
  });
}
