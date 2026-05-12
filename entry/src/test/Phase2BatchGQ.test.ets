import { describe, expect, it } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { createArchivePageForTest } from '../main/ets/pages/ArchivePage';

interface ArchivePagePrivateGQ {
  planList: PlanItem[];
  tipDialogController: Object | null;
  loadPlans(): Promise<void>;
  onPageShow(): void;
  handleSoftDelete(item: PlanItem): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
  handleActivate(item: PlanItem): Promise<void>;
}

class PlanServiceMockGQ {
  archivedPlans: PlanItem[] = [];
  softDeletedIds: number[] = [];
  activatedIds: number[] = [];

  async loadArchivedPlans(): Promise<PlanItem[]> {
    return this.archivedPlans;
  }

  async softDeletePlan(planId: number): Promise<void> {
    this.softDeletedIds.push(planId);
  }

  async activatePlan(planId: number): Promise<void> {
    this.activatedIds.push(planId);
  }
}

class PreferenceManagerMockGQ {
  value: boolean = false;

  async getValue(_key: string, _defaultValue: boolean): Promise<boolean> {
    return this.value;
  }
}

function createArchivePagePrivateGQ(): ArchivePagePrivateGQ {
  return createArchivePageForTest() as ArchivePagePrivateGQ;
}

function buildArchivePlanGQ(id: number, title: string): PlanItem {
  return {
    id: id,
    title: title,
    startDate: 1713744000000,
    createdAt: 1713657600000,
    status: 2
  };
}

export default function phase2BatchGQTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGQ_archive_page_method_lines', () => {
    it('combined: archive_page_should_cover_page_show_and_load_plans_bridge', 0, async () => {
      const page = createArchivePagePrivateGQ();
      const service = new PlanServiceMockGQ();
      let loadCount = 0;

      service.archivedPlans = [buildArchivePlanGQ(1, 'Tokyo'), buildArchivePlanGQ(2, 'Osaka')];
      Reflect.set(page as Object, 'planService', service);
      Reflect.set(page as Object, 'loadPlans', async (): Promise<void> => {
        loadCount += 1;
        page.planList = await service.loadArchivedPlans();
      });

      page.onPageShow();
      await (Reflect.get(page as Object, 'loadPlans') as () => Promise<void>)();

      expect(loadCount).assertEqual(2);
      expect(page.planList.length).assertEqual(2);
    });

    it('combined: archive_page_should_cover_skip_delete_and_dialog_delete_paths', 0, async () => {
      const page = createArchivePagePrivateGQ();
      const item = buildArchivePlanGQ(11, 'Kyoto');
      const prefMock = new PreferenceManagerMockGQ();
      const prefOrigin = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
      let executeCount = 0;
      let executedPlanId = -1;

      Reflect.set(PreferenceManager as Object, 'getInstance', (): PreferenceManagerMockGQ => prefMock);
      Reflect.set(page as Object, 'executeSoftDelete', async (planId: number): Promise<void> => {
        executeCount += 1;
        executedPlanId = planId;
      });

      prefMock.value = true;
      await page.handleSoftDelete(item);
      prefMock.value = false;
      await page.handleSoftDelete(item);

      expect(executeCount).assertEqual(1);
      expect(executedPlanId).assertEqual(11);
      expect(page.tipDialogController !== null).assertTrue();
      expect(typeof Reflect.get(page.tipDialogController as Object, 'open')).assertEqual('function');

      Reflect.set(PreferenceManager as Object, 'getInstance', prefOrigin);
    });

    it('combined: archive_page_should_cover_execute_delete_and_activate_refresh_paths', 0, async () => {
      const page = createArchivePagePrivateGQ();
      const service = new PlanServiceMockGQ();
      const item = buildArchivePlanGQ(21, 'Seoul');
      let refreshCount = 0;

      Reflect.set(page as Object, 'planService', service);
      Reflect.set(page as Object, 'loadPlans', (): Promise<void> => {
        refreshCount += 1;
        return Promise.resolve();
      });

      await page.executeSoftDelete(21);
      await page.handleActivate(item);

      expect(service.softDeletedIds.length).assertEqual(1);
      expect(service.softDeletedIds[0]).assertEqual(21);
      expect(service.activatedIds.length).assertEqual(1);
      expect(service.activatedIds[0]).assertEqual(21);
      expect(refreshCount).assertEqual(2);
    });
  });
}
