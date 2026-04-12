import { describe, expect, it } from '@ohos/hypium';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';

function resetDirtyPlanIds(): void {
  EventRepositoryImpl.consumeDirtyPlanIds();
}

export default function eventRepositoryImplTest() {
  describe('eventRepositoryImplTest', () => {
    it('normal: mark_plan_dirty_should_append_valid_plan_id', 0, () => {
      // Arrange
      resetDirtyPlanIds();
      // Act
      EventRepositoryImpl.markPlanDirty(1001);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual(1001);
    });

    it('boundary: mark_plan_dirty_should_keep_unique_id_when_marked_repeatedly', 0, () => {
      // Arrange
      resetDirtyPlanIds();
      // Act
      EventRepositoryImpl.markPlanDirty(1002);
      EventRepositoryImpl.markPlanDirty(1002);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual(1002);
    });

    it('invalid: mark_plan_dirty_should_ignore_non_positive_and_non_finite_values', 0, () => {
      // Arrange
      resetDirtyPlanIds();
      // Act
      EventRepositoryImpl.markPlanDirty(0);
      EventRepositoryImpl.markPlanDirty(-1);
      EventRepositoryImpl.markPlanDirty(Number.NaN);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(ids.length).assertEqual(0);
    });

    it('conflict: consume_dirty_plan_ids_should_clear_pending_ids_after_read', 0, () => {
      // Arrange
      resetDirtyPlanIds();
      EventRepositoryImpl.markPlanDirty(2001);
      EventRepositoryImpl.markPlanDirty(2002);
      // Act
      const firstRead = EventRepositoryImpl.consumeDirtyPlanIds();
      const secondRead = EventRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(firstRead.length).assertEqual(2);
      expect(secondRead.length).assertEqual(0);
    });

    it('regression: td-20260412-c4-dirty-plan-id-order-should-follow-insertion', 0, () => {
      // Arrange
      resetDirtyPlanIds();
      // Act
      EventRepositoryImpl.markPlanDirty(3001);
      EventRepositoryImpl.markPlanDirty(3002);
      EventRepositoryImpl.markPlanDirty(3003);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(ids[0]).assertEqual(3001);
      expect(ids[1]).assertEqual(3002);
      expect(ids[2]).assertEqual(3003);
    });

    it('combined: dirty_plan_ids_should_merge_multi_round_valid_and_invalid_marks', 0, () => {
      // Arrange
      resetDirtyPlanIds();
      // Act
      EventRepositoryImpl.markPlanDirty(4001);
      EventRepositoryImpl.markPlanDirty(0);
      EventRepositoryImpl.markPlanDirty(4002);
      EventRepositoryImpl.markPlanDirty(4001);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      // Assert
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual(4001);
      expect(ids[1]).assertEqual(4002);
    });
  });
}
