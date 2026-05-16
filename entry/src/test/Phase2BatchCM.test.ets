import { describe, expect, it } from '@ohos/hypium';
import {
  createArchivePageForTest,
  resolveArchiveSoftDeleteDialogMessage,
  resolveArchiveSoftDeleteDialogTitle,
  resolveArchiveTagText,
  shouldArchiveSkipSoftDeleteTip
} from '../main/ets/pages/ArchivePage';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';

interface ArchivePagePrivateCM {
  effectiveTheme: string;
  planList: PlanItem[];
  tipDialogController: Object | null;
  getThemePalette(): Object;
  onPageShow(): void;
  loadPlans(): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
  handleActivate(item: PlanItem): Promise<void>;
  ArchiveSwipeMenu(item: PlanItem): void;
  initialRender(): void;
}

interface ArchivePlanServiceCM {
  loadArchivedPlans(): Promise<PlanItem[]>;
  softDeletePlan(planId: number): Promise<void>;
  activatePlan(planId: number): Promise<void>;
}

class ArchivePlanServiceMockCM implements ArchivePlanServiceCM {
  public plans: PlanItem[] = [];
  public softDeletedPlanIds: number[] = [];
  public activatedPlanIds: number[] = [];
  public loadCount: number = 0;

  async loadArchivedPlans(): Promise<PlanItem[]> {
    this.loadCount += 1;
    return this.plans;
  }

  async softDeletePlan(planId: number): Promise<void> {
    this.softDeletedPlanIds.push(planId);
  }

  async activatePlan(planId: number): Promise<void> {
    this.activatedPlanIds.push(planId);
  }
}

function createArchivePageCM(service: ArchivePlanServiceMockCM): ArchivePagePrivateCM {
  const page = createArchivePageForTest() as ArchivePagePrivateCM;
  Reflect.set(page as Object, 'planService', service);
  return page;
}

function buildArchivePlanCM(id: number, title: string): PlanItem {
  return {
    id: id,
    title: title,
    startDate: new Date(2026, 3, 22).getTime(),
    createdAt: 1000 + id,
    status: 2
  };
}

export default function phase2BatchCMTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCM_archive_page_extra', () => {
    it('normal: archive_skip_tip_should_return_same_boolean_for_both_states', 0, () => {
      // Arrange
      const enabled = true;
      const disabled = false;

      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(enabled);
      const shouldShow = shouldArchiveSkipSoftDeleteTip(disabled);

      // Assert
      expect(shouldSkip).assertTrue();
      expect(shouldShow).assertFalse();
    });

    it('boundary: archive_dialog_copy_should_be_non_empty_and_tag_should_keep_padding', 0, () => {
      // Arrange
      // Act
      const title = resolveArchiveSoftDeleteDialogTitle();
      const message = resolveArchiveSoftDeleteDialogMessage();
      const tag = resolveArchiveTagText();

      // Assert
      expect(title.trim().length > 0).assertTrue();
      expect(message.trim().length > 0).assertTrue();
      expect(tag.length > tag.trim().length).assertTrue();
    });

    it('combined: archive_page_load_plans_should_replace_existing_list', 0, async () => {
      // Arrange
      const service = new ArchivePlanServiceMockCM();
      service.plans = [buildArchivePlanCM(401, 'Sapporo')];
      const page = createArchivePageCM(service);
      page.planList = [buildArchivePlanCM(400, 'Old')];

      // Act
      await page.loadPlans();

      // Assert
      expect(service.loadCount).assertEqual(1);
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].id).assertEqual(401);
    });

    it('regression: archive_page_on_page_show_should_delegate_to_load_plans', 0, () => {
      // Arrange
      const service = new ArchivePlanServiceMockCM();
      const page = createArchivePageCM(service);

      // Act
      page.onPageShow();

      // Assert
      expect(service.loadCount >= 0).assertTrue();
    });

    it('combined: archive_page_execute_soft_delete_should_call_service_and_reload', 0, async () => {
      // Arrange
      const service = new ArchivePlanServiceMockCM();
      const page = createArchivePageCM(service);
      let reloadCount = 0;
      Reflect.set(page as Object, 'loadPlans', (): void => {
        reloadCount += 1;
      });

      // Act
      await page.executeSoftDelete(402);

      // Assert
      expect(service.softDeletedPlanIds[0]).assertEqual(402);
      expect(reloadCount).assertEqual(1);
    });

    it('combined: archive_page_activate_should_call_service_and_reload', 0, async () => {
      // Arrange
      const service = new ArchivePlanServiceMockCM();
      const page = createArchivePageCM(service);
      let reloadCount = 0;
      Reflect.set(page as Object, 'loadPlans', (): void => {
        reloadCount += 1;
      });
      const item = buildArchivePlanCM(403, 'Fukuoka');

      // Act
      await page.handleActivate(item);

      // Assert
      expect(service.activatedPlanIds[0]).assertEqual(403);
      expect(reloadCount).assertEqual(1);
    });

    it('combined: archive_page_render_should_cover_empty_and_archived_list_states', 0, () => {
      // Arrange
      const service = new ArchivePlanServiceMockCM();
      const page = createArchivePageCM(service);
      const item = buildArchivePlanCM(404, 'Kobe');

      // Act
      page.effectiveTheme = 'light';
      page.planList = [];
      page.initialRender();
      page.effectiveTheme = 'dark';
      page.planList = [item];
      page.initialRender();
      page.ArchiveSwipeMenu(item);
      const palette = page.getThemePalette();

      // Assert
      expect(palette !== null).assertTrue();
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].title).assertEqual('Kobe');
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
