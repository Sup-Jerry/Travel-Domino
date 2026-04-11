import { describe, expect, it } from '@ohos/hypium';
import { ExecutionContextStore } from '../main/ets/infrastructure/persistence/ExecutionContextStore';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { createDefaultExecutionContext, PlanTransitionEvent } from '../main/ets/domain/statemachine/ExecutionContext';
import { PlanStatus, TransitionTriggerSource } from '../main/ets/domain/statemachine/PlanStatus';

function resetStoreKeys(): void {
  AppStorage.setOrCreate(AppStorageKeys.PLAN_EXECUTION_CONTEXT, '');
  AppStorage.setOrCreate(AppStorageKeys.PLAN_TRANSITION_LOG, '');
}

function createTransition(planId: string, ts: number): PlanTransitionEvent {
  return {
    planId: planId,
    fromStatus: PlanStatus.CONFIRMED,
    toStatus: PlanStatus.READY,
    triggerSource: TransitionTriggerSource.TIME_WINDOW,
    triggerReason: 'test',
    timestamp: ts
  };
}

export default function executionContextStoreTest() {
  describe('executionContextStoreTest', () => {
    it('normal: write_and_read_context_should_return_latest_context', 0, () => {
      // Arrange
      resetStoreKeys();
      const store = ExecutionContextStore.getInstance();
      const ctx = createDefaultExecutionContext('p_normal', 1_000, 1_200, 1_800);
      ctx.status = PlanStatus.READY;
      // Act
      store.writeContext(ctx);
      const loaded = store.readContext('p_normal');
      // Assert
      expect(loaded !== null).assertTrue();
      expect(loaded?.planId || '').assertEqual('p_normal');
      expect(loaded?.status || PlanStatus.DRAFT).assertEqual(PlanStatus.READY);
    });

    it('boundary: append_transition_should_keep_latest_30_records_only', 0, () => {
      // Arrange
      resetStoreKeys();
      const store = ExecutionContextStore.getInstance();
      for (let i = 0; i < 32; i++) {
        store.appendTransition(createTransition('p_boundary', 10_000 + i));
      }
      // Act
      const all = store.readTransitions('p_boundary');
      // Assert
      expect(all.length).assertEqual(30);
      expect(all[0].timestamp).assertEqual(10_002);
      expect(all[29].timestamp).assertEqual(10_031);
    });

    it('invalid: read_methods_should_fallback_when_storage_contains_invalid_json', 0, () => {
      // Arrange
      resetStoreKeys();
      const store = ExecutionContextStore.getInstance();
      AppStorage.setOrCreate(AppStorageKeys.PLAN_EXECUTION_CONTEXT, '{bad json');
      AppStorage.setOrCreate(AppStorageKeys.PLAN_TRANSITION_LOG, '{bad json');
      // Act
      const context = store.readContext('p_invalid');
      const transitions = store.readTransitions('p_invalid');
      // Assert
      expect(context === null).assertTrue();
      expect(transitions.length).assertEqual(0);
    });

    it('conflict: write_context_should_replace_same_plan_id_instead_of_duplicating', 0, () => {
      // Arrange
      resetStoreKeys();
      const store = ExecutionContextStore.getInstance();
      const first = createDefaultExecutionContext('p_conflict', 1_000);
      first.status = PlanStatus.CONFIRMED;
      const second = createDefaultExecutionContext('p_conflict', 2_000);
      second.status = PlanStatus.IN_PROGRESS;
      // Act
      store.writeContext(first);
      store.writeContext(second);
      const loaded = store.readContext('p_conflict');
      // Assert
      expect(loaded !== null).assertTrue();
      expect(loaded?.status || PlanStatus.DRAFT).assertEqual(PlanStatus.IN_PROGRESS);
      const raw = AppStorage.get<string>(AppStorageKeys.PLAN_EXECUTION_CONTEXT) || '[]';
      const parsed = JSON.parse(raw) as Array<Object>;
      expect(parsed.length).assertEqual(1);
    });

    it('regression: td-20260411-c4-read-latest-transition-should-return-last-item', 0, () => {
      // Arrange
      resetStoreKeys();
      const store = ExecutionContextStore.getInstance();
      store.appendTransition(createTransition('p_regression', 1));
      store.appendTransition(createTransition('p_regression', 2));
      // Act
      const latest = store.readLatestTransition('p_regression');
      // Assert
      expect(latest !== null).assertTrue();
      expect(latest?.timestamp || 0).assertEqual(2);
    });

    it('combined: clear_context_should_not_remove_transition_history', 0, () => {
      // Arrange
      resetStoreKeys();
      const store = ExecutionContextStore.getInstance();
      const ctx = createDefaultExecutionContext('p_combined', 1_000);
      store.writeContext(ctx);
      store.appendTransition(createTransition('p_combined', 9_999));
      // Act
      store.clearContext('p_combined');
      const context = store.readContext('p_combined');
      const transitions = store.readTransitions('p_combined');
      // Assert
      expect(context === null).assertTrue();
      expect(transitions.length).assertEqual(1);
      expect(transitions[0].timestamp).assertEqual(9_999);
    });
  });
}
