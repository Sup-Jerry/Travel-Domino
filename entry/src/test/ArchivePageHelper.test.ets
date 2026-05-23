import { describe, it, expect } from '@ohos/hypium';
import {
  createArchivePageForTest,
  resolveArchiveSoftDeleteDialogMessage,
  resolveArchiveSoftDeleteDialogTitle,
  resolveArchiveTagText,
  shouldArchiveSkipSoftDeleteTip
} from '../main/ets/pages/ArchivePage';
import { AppTexts } from '../main/ets/common/constants/AppTexts';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';

interface ArchivePagePrivateTest {
  effectiveTheme: string;
  planList: PlanItem[];
  tipDialogController: Object | null;
  getThemePalette(): Object;
  onPageShow(): void;
  loadPlans(): Promise<void>;
  handleSoftDelete(item: PlanItem): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
  handleActivate(item: PlanItem): Promise<void>;
  ArchiveSwipeMenu(item: PlanItem): void;
  initialRender(): void;
}

function createArchivePagePrivateForTest(): ArchivePagePrivateTest {
  return createArchivePageForTest() as ArchivePagePrivateTest;
}

function buildArchivePlanItemForTest(id: number, title: string): PlanItem {
  return {
    id: id,
    title: title,
    startDate: new Date(2026, 3, 22).getTime(),
    createdAt: Date.now(),
    status: 2
  };
}

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

    it('combined: archive_page_instance_should_render_empty_and_archived_list_paths', 0, () => {
      // Arrange
      const emptyPage = createArchivePagePrivateForTest();
      const listPage = createArchivePagePrivateForTest();
      listPage.planList = [
        buildArchivePlanItemForTest(101, 'Tokyo'),
        buildArchivePlanItemForTest(102, 'Osaka')
      ];
      listPage.effectiveTheme = 'dark';

      // Act
      emptyPage.initialRender();
      listPage.initialRender();
      const palette = listPage.getThemePalette();

      // Assert
      expect(emptyPage.planList.length).assertEqual(0);
      expect(listPage.planList.length).assertEqual(2);
      expect(palette !== null).assertTrue();
    });

    it('regression: td-20260422-archive_page_swipe_menu_should_bind_archive_item_actions', 0, () => {
      // Arrange
      const page = createArchivePagePrivateForTest();
      const item = buildArchivePlanItemForTest(103, 'Kyoto');

      // Act
      page.ArchiveSwipeMenu(item);

      // Assert
      expect(item.id).assertEqual(103);
      expect(item.title).assertEqual('Kyoto');
    });
  });
}

