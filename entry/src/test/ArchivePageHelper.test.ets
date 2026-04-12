import { describe, it, expect } from '@ohos/hypium';
import {
  resolveArchiveSoftDeleteDialogMessage,
  resolveArchiveSoftDeleteDialogTitle,
  resolveArchiveTagText,
  shouldArchiveSkipSoftDeleteTip
} from '../main/ets/pages/ArchivePage';
import { AppTexts } from '../main/ets/common/constants/AppTexts';

export default function archivePageHelperTest() {
  describe('unit_test_case_generator_autofill_ArchivePageHelper', () => {
    it('normal: archive_skip_tip_should_return_true_when_preference_enabled', 0, () => {
      // Arrange
      const isSkip = true;
      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(isSkip);
      // Assert
      expect(shouldSkip).assertTrue();
    });

    it('boundary: archive_skip_tip_should_return_false_when_preference_disabled', 0, () => {
      // Arrange
      const isSkip = false;
      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(isSkip);
      // Assert
      expect(shouldSkip).assertFalse();
    });

    it('invalid: archive_dialog_title_should_keep_expected_copy', 0, () => {
      // Arrange
      // Act
      const title = resolveArchiveSoftDeleteDialogTitle();
      // Assert
      expect(title).assertEqual('移入回收站');
    });

    it('conflict: archive_dialog_message_should_match_app_text_constant', 0, () => {
      // Arrange
      // Act
      const message = resolveArchiveSoftDeleteDialogMessage();
      // Assert
      expect(message).assertEqual(AppTexts.SOFT_DELETE_RECYCLE_TIP);
    });

    it('regression: td-20260412-archive_tag_text_should_keep_padding_spaces', 0, () => {
      // Arrange
      // Act
      const tagText = resolveArchiveTagText();
      // Assert
      expect(tagText).assertEqual(' 已归档 ');
    });

    it('combined: archive_skip_and_dialog_copy_should_work_as_expected', 0, () => {
      // Arrange
      const isSkip = false;
      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(isSkip);
      const title = resolveArchiveSoftDeleteDialogTitle();
      const message = resolveArchiveSoftDeleteDialogMessage();
      // Assert
      expect(shouldSkip).assertFalse();
      expect(title).assertEqual('移入回收站');
      expect(message.length > 0).assertTrue();
    });
  });
}

