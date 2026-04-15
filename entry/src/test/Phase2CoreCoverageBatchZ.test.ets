import { describe, expect, it } from '@ohos/hypium';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';

function clearDirtyPoolForZ(): void {
  PlanRepositoryImpl.consumeDirtyPlanIds();
}

export default function phase2CoreCoverageBatchZTest() {
  describe('phase2CoreCoverageBatchZTest', () => {
    it('normal: plan_repository_get_plan_by_id_should_return_undefined_when_rdb_not_initialized', 0, async () => {
      // Arrange
      clearDirtyPoolForZ();
      // Act
      const plan = await PlanRepositoryImpl.getPlanById(1);
      // Assert
      expect(plan === undefined).assertTrue();
    });

    it('boundary: plan_repository_purge_old_trash_should_return_zero_when_rdb_not_initialized', 0, async () => {
      // Arrange
      clearDirtyPoolForZ();
      // Act
      const deletedRows = await PlanRepositoryImpl.purgeOldTrash();
      // Assert
      expect(deletedRows).assertEqual(0);
    });

    it('invalid: plan_repository_search_paths_should_return_empty_when_rdb_not_initialized', 0, async () => {
      // Arrange
      clearDirtyPoolForZ();
      // Act
      const searched = await PlanRepositoryImpl.searchPlans('');
      const searchedTrash = await PlanRepositoryImpl.searchTrashPlans('   ');
      // Assert
      expect(searched.length).assertEqual(0);
      expect(searchedTrash.length).assertEqual(0);
    });

    it('conflict: plan_repository_update_plan_status_should_not_dirty_pool_when_rdb_not_initialized', 0, async () => {
      // Arrange
      clearDirtyPoolForZ();
      // Act
      await PlanRepositoryImpl.updatePlanStatus(99, 2);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(dirty.length).assertEqual(0);
    });

    it('regression: td-20260415-update-strategy-mode-null-store-should-not-add-dirty-id', 0, async () => {
      // Arrange
      clearDirtyPoolForZ();
      // Act
      await PlanRepositoryImpl.updateStrategyMode(88, 1);
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(dirty.length).assertEqual(0);
    });

    it('combined: plan_repository_null_store_mutations_should_complete_without_throw_and_keep_dirty_pool_clean', 0, async () => {
      // Arrange
      clearDirtyPoolForZ();
      // Act
      await PlanRepositoryImpl.restorePlan(1);
      await PlanRepositoryImpl.hardDeletePlan(1);
      await PlanRepositoryImpl.softDeletePlan(1);
      await PlanRepositoryImpl.updateStartDate(1, Date.now());
      await PlanRepositoryImpl.updatePlanName(1, 'plan_z');
      await PlanRepositoryImpl.updateAutoAmapRoute(1, true);
      await PlanRepositoryImpl.updateStrategyDimensions(1, 1, 2, 3, 4);
      await PlanRepositoryImpl.saveAiContext(1, 'prompt_z', 'explain_z');
      const dirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(dirty.length).assertEqual(0);
    });
  });
}

