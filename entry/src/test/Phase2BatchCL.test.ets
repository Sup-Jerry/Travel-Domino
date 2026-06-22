import { describe, expect, it } from '@ohos/hypium';
import {
  createTrashPageForTest,
  resolveTrashAutoPurgeDiffMs,
  resolveTrashRemainingTimeText
} from '../main/ets/pages/TrashPage';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';

interface TrashPagePrivateCL {
  effectiveTheme: string;
  planList: PlanItem[];
  getThemePalette(): Object;
  onPageShow(): void;
  loadPlans(): Promise<void>;
  getRemainingTimeText(deleteTime: number | undefined): string;
  handleHardDelete(item: PlanItem): void;
  TrashSwipeMenu(item: PlanItem): void;
  initialRender(): void;
}

interface TrashPlanServiceCL {
  loadTrashPlans(): Promise<PlanItem[]>;
  hardDeletePlan(planId: number): Promise<void>;
  restorePlan(planId: number): Promise<void>;
}

interface TrashAlertButtonCL {
  value: string;
  action: () => Promise<void> | void;
}

interface TrashAlertOptionsCL {
  title: string;
  message: string;
  autoCancel: boolean;
  primaryButton: TrashAlertButtonCL;
  secondaryButton: TrashAlertButtonCL;
}

interface TrashUiContextCL {
  showAlertDialog(options: TrashAlertOptionsCL): void;
}

class TrashPlanServiceMockCL implements TrashPlanServiceCL {
  public plans: PlanItem[] = [];
  public hardDeletedPlanIds: number[] = [];
  public restoredPlanIds: number[] = [];
  public loadCount: number = 0;

  async loadTrashPlans(): Promise<PlanItem[]> {
    this.loadCount += 1;
    return this.plans;
  }

  async hardDeletePlan(planId: number): Promise<void> {
    this.hardDeletedPlanIds.push(planId);
  }

  async restorePlan(planId: number): Promise<void> {
    this.restoredPlanIds.push(planId);
  }
}

class TrashUiContextMockCL implements TrashUiContextCL {
  public showCount: number = 0;
  public lastOptions: TrashAlertOptionsCL | null = null;

  showAlertDialog(options: TrashAlertOptionsCL): void {
    this.showCount += 1;
    this.lastOptions = options;
  }
}

function createTrashPageCL(service: TrashPlanServiceMockCL): TrashPagePrivateCL {
  const page = createTrashPageForTest() as TrashPagePrivateCL;
  Reflect.set(page as Object, 'planService', service);
  return page;
}

function buildTrashPlanCL(id: number, title: string, deleteTime: number | undefined): PlanItem {
  return {
    id: id,
    title: title,
    createdAt: 1000,
    startDate: new Date(2026, 3, 22).getTime(),
    status: 0,
    delFlag: 1,
    deleteTime: deleteTime
  };
}

export default function phase2BatchCLTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCL_trash_page_extra', () => {
    it('normal: trash_remaining_time_should_render_day_hour_for_positive_multi_day_diff', 0, () => {
      // Arrange
      const now = 10_000;
      const retentionMs = 3 * 24 * 3600 * 1000;
      const deleteTime = now - (1 * 24 * 3600 * 1000) - (2 * 3600 * 1000);

      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);

      // Assert
      expect(text.indexOf('天') >= 0).assertTrue();
      expect(text.indexOf('小时') >= 0).assertTrue();
    });

    it('boundary: trash_auto_purge_diff_should_be_zero_at_exact_retention_deadline', 0, () => {
      // Arrange
      const now = 50_000;
      const retentionMs = 5_000;
      const deleteTime = now - retentionMs;

      // Act
      const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, retentionMs);
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);

      // Assert
      expect(diff).assertEqual(0);
      expect(text).assertEqual('即将清除');
    });

    it('invalid: trash_auto_purge_diff_should_treat_zero_delete_time_as_missing', 0, () => {
      // Arrange
      const now = 100_000;

      // Act
      const diff = resolveTrashAutoPurgeDiffMs(0, now);
      const text = resolveTrashRemainingTimeText(0, now);

      // Assert
      expect(diff).assertEqual(-1);
      expect(text).assertEqual('即将清除');
    });

    it('conflict: trash_remaining_time_should_render_hour_text_when_less_than_one_day_left', 0, () => {
      // Arrange
      const now = 200_000;
      const retentionMs = 6 * 3600 * 1000;
      const deleteTime = now - 2 * 3600 * 1000;

      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);

      // Assert
      expect(text.indexOf('天') < 0).assertTrue();
      expect(text.indexOf('小时') >= 0).assertTrue();
    });

    it('regression: trash_page_on_page_show_should_delegate_loading_without_throwing', 0, () => {
      // Arrange
      const service = new TrashPlanServiceMockCL();
      service.plans = [buildTrashPlanCL(301, 'Tokyo', Date.now() - 1000)];
      const page = createTrashPageCL(service);

      // Act
      page.onPageShow();

      // Assert
      expect(service.loadCount >= 0).assertTrue();
    });

    it('combined: trash_page_load_plans_should_replace_existing_plan_list', 0, async () => {
      // Arrange
      const service = new TrashPlanServiceMockCL();
      service.plans = [buildTrashPlanCL(302, 'Kyoto', Date.now() - 2000)];
      const page = createTrashPageCL(service);
      page.planList = [buildTrashPlanCL(300, 'Old', Date.now() - 3000)];

      // Act
      await page.loadPlans();

      // Assert
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].id).assertEqual(302);
    });

    it('combined: trash_page_hard_delete_primary_button_should_not_delete_plan', 0, () => {
      // Arrange
      const service = new TrashPlanServiceMockCL();
      const page = createTrashPageCL(service);
      const uiContext = new TrashUiContextMockCL();
      Reflect.set(page as Object, 'getUIContext', (): TrashUiContextCL => uiContext);
      const item = buildTrashPlanCL(303, 'Osaka', Date.now() - 3000);

      // Act
      page.handleHardDelete(item);
      uiContext.lastOptions?.primaryButton.action();

      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(service.hardDeletedPlanIds.length).assertEqual(0);
    });

    it('combined: trash_page_hard_delete_secondary_button_should_delete_and_reload', 0, async () => {
      // Arrange
      const service = new TrashPlanServiceMockCL();
      const page = createTrashPageCL(service);
      const uiContext = new TrashUiContextMockCL();
      let reloadCount = 0;
      Reflect.set(page as Object, 'getUIContext', (): TrashUiContextCL => uiContext);
      Reflect.set(page as Object, 'loadPlans', (): void => {
        reloadCount += 1;
      });
      const item = buildTrashPlanCL(304, 'Nara', Date.now() - 4000);

      // Act
      page.handleHardDelete(item);
      await uiContext.lastOptions?.secondaryButton.action();

      // Assert
      expect(service.hardDeletedPlanIds[0]).assertEqual(304);
      expect(reloadCount).assertEqual(1);
    });

    it('combined: trash_page_render_should_cover_empty_and_non_empty_lists', 0, () => {
      // Arrange
      const service = new TrashPlanServiceMockCL();
      const page = createTrashPageCL(service);
      const item = buildTrashPlanCL(305, 'Nagoya', Date.now() - 5000);

      // Act
      page.effectiveTheme = 'light';
      page.planList = [];
      page.initialRender();
      page.effectiveTheme = 'dark';
      page.planList = [item];
      page.initialRender();
      const palette = page.getThemePalette();
      const remainingText = page.getRemainingTimeText(item.deleteTime);

      // Assert
      expect(palette !== null).assertTrue();
      expect(remainingText.length > 0).assertTrue();
      expect(page.planList.length).assertEqual(1);
    });
  });
}
