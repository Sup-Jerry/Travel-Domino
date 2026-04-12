import { describe, it, expect } from '@ohos/hypium';
import { AppTexts } from '../main/ets/common/constants/AppTexts';

export default function appTextsConstantsTest() {
  describe('appTextsConstantsTest', () => {
    it('normal: app_texts_soft_delete_tip_should_not_be_empty', 0, () => {
      // Arrange
      const tip = AppTexts.SOFT_DELETE_RECYCLE_TIP;

      // Act
      const length = tip.length;

      // Assert
      expect(length > 0).assertTrue();
    });

    it('boundary: app_texts_soft_delete_tip_should_contain_retention_day_hint', 0, () => {
      // Arrange
      const tip = AppTexts.SOFT_DELETE_RECYCLE_TIP;

      // Act
      const hasRetentionHint = tip.indexOf('7') >= 0;

      // Assert
      expect(hasRetentionHint).assertTrue();
    });

    it('regression: td-20260412-app_texts_soft_delete_tip_should_keep_multiline_format', 0, () => {
      // Arrange
      const tip = AppTexts.SOFT_DELETE_RECYCLE_TIP;

      // Act
      const hasLineBreak = tip.indexOf('\n') >= 0;

      // Assert
      expect(hasLineBreak).assertTrue();
    });

    it('invalid: app_texts_soft_delete_tip_should_not_be_blank_after_trim', 0, () => {
      // Arrange
      const tip = AppTexts.SOFT_DELETE_RECYCLE_TIP;

      // Act
      const blank = tip.trim().length === 0;

      // Assert
      expect(blank).assertFalse();
    });

    it('conflict: app_texts_soft_delete_tip_should_include_delete_and_restore_hint_together', 0, () => {
      // Arrange
      const tip = AppTexts.SOFT_DELETE_RECYCLE_TIP;

      // Act
      const hasDeleteHint = tip.indexOf('删除') >= 0 || tip.indexOf('销毁') >= 0;
      const hasRestoreHint = tip.indexOf('恢复') >= 0;

      // Assert
      expect(hasDeleteHint).assertTrue();
      expect(hasRestoreHint).assertTrue();
    });

    it('combined: app_texts_soft_delete_tip_should_keep_length_and_retention_hint', 0, () => {
      // Arrange
      const tip = AppTexts.SOFT_DELETE_RECYCLE_TIP;

      // Act
      const valid = tip.length > 0 && tip.indexOf('7') >= 0;

      // Assert
      expect(valid).assertTrue();
    });
  });
}
