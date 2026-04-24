import { describe, it, expect } from '@ohos/hypium';
import {
  createTrashPageForTest,
  resolveTrashAutoPurgeDiffMs,
  resolveTrashRemainingTimeText
} from '../main/ets/pages/TrashPage';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';

interface TrashPagePrivateTest {
  effectiveTheme: string;
  planList: PlanItem[];
  getThemePalette(): Object;
  onPageShow(): void;
  loadPlans(): Promise<void>;
  getRemainingTimeText(deleteTime: number | undefined): string;
  handleHardDelete(item: PlanItem): void;
  TrashSwipeMenu(item: PlanItem): void;
  initialRender(): void;
  getUIContext(): TrashUiContextTest;
}

interface TrashPlanServiceTest {
  loadTrashPlans(): Promise<PlanItem[]>;
  hardDeletePlan(planId: number): Promise<void>;
  restorePlan(planId: number): Promise<void>;
}

interface TrashAlertButtonTest {
  value: string;
  action: () => Promise<void> | void;
}

interface TrashAlertOptionsTest {
  title: string;
  message: string;
  autoCancel: boolean;
  primaryButton: TrashAlertButtonTest;
  secondaryButton: TrashAlertButtonTest;
}

interface TrashUiContextTest {
  showAlertDialog(options: TrashAlertOptionsTest): void;
}

class TrashPlanServiceMockTest implements TrashPlanServiceTest {
  public plans: PlanItem[] = [];
  public hardDeletedPlanIds: number[] = [];
  public restoredPlanIds: number[] = [];

  async loadTrashPlans(): Promise<PlanItem[]> {
    return this.plans;
  }

  async hardDeletePlan(planId: number): Promise<void> {
    this.hardDeletedPlanIds.push(planId);
  }

  async restorePlan(planId: number): Promise<void> {
    this.restoredPlanIds.push(planId);
  }
}

class TrashUiContextMockTest implements TrashUiContextTest {
  public showCount: number = 0;
  public lastOptions?: TrashAlertOptionsTest;

  showAlertDialog(options: TrashAlertOptionsTest): void {
    this.showCount += 1;
    this.lastOptions = options;
  }
}

function createTrashPagePrivateForTest(service: TrashPlanServiceTest): TrashPagePrivateTest {
  const page = createTrashPageForTest() as TrashPagePrivateTest;
  Reflect.set(page as Object, 'planService', service);
  return page;
}

function buildTrashPlanItemForTest(id: number, title: string): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: Date.now(),
    startDate: new Date(2026, 3, 22).getTime(),
    status: 0,
    delFlag: 1,
    deleteTime: Date.now() - 3_600_000
  };
}

export default function trashPageHelperTest() {
  describe('unit_test_case_generator_autofill_TrashPageHelper', () => {
    it('normal: trash_remaining_time_should_render_day_and_hour_when_diff_over_one_day', 0, () => {
      // Arrange
      const now = 1_000;
      const deleteTime = now - 2 * 24 * 3600 * 1000;
      const retentionMs = 3 * 24 * 3600 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('1天 0小时 后自动清除');
    });

    it('boundary: trash_remaining_time_should_fallback_to_immediate_when_diff_equals_zero', 0, () => {
      // Arrange
      const now = 5_000;
      const deleteTime = 4_000;
      const retentionMs = 1_000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('即将清除');
    });

    it('invalid: trash_remaining_time_should_fallback_to_immediate_when_delete_time_missing', 0, () => {
      // Arrange
      const now = 10_000;
      // Act
      const text = resolveTrashRemainingTimeText(undefined, now);
      // Assert
      expect(text).assertEqual('即将清除');
    });

    it('conflict: trash_remaining_time_should_render_hour_only_when_less_than_one_day', 0, () => {
      // Arrange
      const now = 100_000;
      const deleteTime = now - 6 * 3600 * 1000;
      const retentionMs = 12 * 3600 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('6小时 后自动清除');
    });

    it('regression: td-20260412-trash_auto_purge_diff_should_keep_negative_when_missing_delete_time', 0, () => {
      // Arrange
      const now = 123_456;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(undefined, now);
      // Assert
      expect(diff).assertEqual(-1);
    });

    it('combined: trash_diff_and_text_should_stay_consistent_for_positive_diff', 0, () => {
      // Arrange
      const now = 200_000;
      const deleteTime = now - 1_000;
      const retentionMs = 3_600_000;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, retentionMs);
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(diff > 0).assertTrue();
      expect(text).assertEqual('0小时 后自动清除');
    });

    it('normal: trash_page_load_plans_should_sync_plan_list_from_service', 0, async () => {
      // Arrange
      const service = new TrashPlanServiceMockTest();
      service.plans = [buildTrashPlanItemForTest(201, 'Seoul')];
      const page = createTrashPagePrivateForTest(service);

      // Act
      await page.loadPlans();

      // Assert
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].title).assertEqual('Seoul');
    });

    it('combined: trash_page_hard_delete_dialog_should_execute_secondary_action', 0, async () => {
      // Arrange
      const service = new TrashPlanServiceMockTest();
      const page = createTrashPagePrivateForTest(service);
      const uiContext = new TrashUiContextMockTest();
      let refreshCount = 0;
      Reflect.set(page as Object, 'getUIContext', (): TrashUiContextTest => uiContext);
      Reflect.set(page as Object, 'loadPlans', (): void => {
        refreshCount += 1;
      });
      const item = buildTrashPlanItemForTest(202, 'Busan');

      // Act
      page.handleHardDelete(item);
      await uiContext.lastOptions?.secondaryButton.action();

      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(service.hardDeletedPlanIds[0]).assertEqual(202);
      expect(refreshCount).assertEqual(1);
    });

    it('regression: td-20260422-trash_page_render_and_swipe_menu_should_cover_deleted_plan_paths', 0, () => {
      // Arrange
      const service = new TrashPlanServiceMockTest();
      const page = createTrashPagePrivateForTest(service);
      const item = buildTrashPlanItemForTest(203, 'Daegu');
      page.planList = [item];
      page.effectiveTheme = 'dark';
      let threw = false;

      // Act
      try {
        page.initialRender();
        page.TrashSwipeMenu(item);
      } catch (_error) {
        threw = true;
      }
      const remainingText = page.getRemainingTimeText(item.deleteTime);
      const palette = page.getThemePalette();

      // Assert
      expect(threw).assertFalse();
      expect(remainingText.length > 0).assertTrue();
      expect(palette !== null).assertTrue();
    });

    it('boundary: trash_auto_purge_diff_should_treat_zero_delete_time_as_missing', 0, () => {
      // Arrange
      const now = 20_000;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(0, now);
      const text = resolveTrashRemainingTimeText(0, now);
      // Assert
      expect(diff).assertEqual(-1);
      expect(text).assertEqual('即将清除');
    });

    it('boundary: trash_remaining_time_should_floor_partial_hours', 0, () => {
      // Arrange
      const now = 100_000;
      const deleteTime = now - 30 * 60 * 1000;
      const retentionMs = 2 * 3600 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('1小时 后自动清除');
    });

    it('normal: trash_page_on_page_show_should_delegate_to_load_plans_once', 0, () => {
      // Arrange
      const service = new TrashPlanServiceMockTest();
      const page = createTrashPagePrivateForTest(service);
      let loadCount = 0;
      Reflect.set(page as Object, 'loadPlans', (): void => {
        loadCount += 1;
      });
      // Act
      page.onPageShow();
      // Assert
      expect(loadCount).assertEqual(1);
    });

    it('combined: trash_page_hard_delete_primary_button_should_not_delete_or_reload', 0, () => {
      // Arrange
      const service = new TrashPlanServiceMockTest();
      const page = createTrashPagePrivateForTest(service);
      const uiContext = new TrashUiContextMockTest();
      let refreshCount = 0;
      Reflect.set(page as Object, 'getUIContext', (): TrashUiContextTest => uiContext);
      Reflect.set(page as Object, 'loadPlans', (): void => {
        refreshCount += 1;
      });
      const item = buildTrashPlanItemForTest(204, 'Jeju');

      // Act
      page.handleHardDelete(item);
      uiContext.lastOptions?.primaryButton.action();

      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(service.hardDeletedPlanIds.length).assertEqual(0);
      expect(refreshCount).assertEqual(0);
    });
  });
}

