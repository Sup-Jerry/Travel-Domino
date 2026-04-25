import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  isCompanionOverlayVisible,
  resolveCompanionBackAction,
  resolveCompanionBackLevel,
  resolveCompanionDefaultFocusId,
  resolveCompanionSearchResults,
  resolveCompanionVisibleFocusId,
  resolveCompanionVisibleFocusPosition
} from '../main/ets/pages/components/views/CompanionView';

function buildPhase2BatchFTEvent(id: number, name: string, address: string = ''): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.address = address;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  return event;
}

export default function phase2BatchFTTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFT_companion_view_pure_helpers', () => {
    it('normal: companion_overlay_and_back_helpers_should_follow_overlay_control_and_exit_paths', 0, () => {
      // Arrange
      const overlayVisible = isCompanionOverlayVisible(true, false, false);
      const overlayLevel = resolveCompanionBackLevel(false, true, false, 'immersive');
      const controlLevel = resolveCompanionBackLevel(false, false, false, 'control');
      const overlayAction = resolveCompanionBackAction(false, false, true, 'control');
      const exitAction = resolveCompanionBackAction(false, false, false, 'immersive');

      // Assert
      expect(overlayVisible).assertTrue();
      expect(overlayLevel).assertEqual('overlay');
      expect(controlLevel).assertEqual('control');
      expect(overlayAction).assertEqual('close_overlay');
      expect(exitAction).assertEqual('exit');
    });

    it('boundary: companion_search_results_should_trim_keyword_and_limit_blank_search_to_twenty_items', 0, () => {
      // Arrange
      const events: EventEntity[] = [];
      for (let i = 1; i <= 22; i++) {
        events.push(buildPhase2BatchFTEvent(i, `Spot ${i}`, `Street ${i}`));
      }
      const customSearch = new Map<number, string>([
        [events[5].id, 'special museum keyword']
      ]);

      // Act
      const blankResults = resolveCompanionSearchResults(events, '   ');
      const filteredResults = resolveCompanionSearchResults(events, '  KEYword ', customSearch);

      // Assert
      expect(blankResults.length).assertEqual(20);
      expect(filteredResults.length).assertEqual(1);
      expect(filteredResults[0].id).assertEqual(events[5].id);
    });

    it('invalid: companion_focus_helpers_should_return_negative_or_zero_for_missing_visible_targets', 0, () => {
      // Arrange
      const visibleIndexById = new Map<number, number>();

      // Act
      const visibleFocusId = resolveCompanionVisibleFocusId([], 99);
      const visibleFocusPosition = resolveCompanionVisibleFocusPosition(99, visibleIndexById);
      const defaultFocusId = resolveCompanionDefaultFocusId([], 0, 0);

      // Assert
      expect(visibleFocusId).assertEqual(-1);
      expect(visibleFocusPosition).assertEqual(0);
      expect(defaultFocusId).assertEqual(-1);
    });

    it('conflict: companion_default_focus_should_prefer_active_event_over_current_next_and_pending', 0, () => {
      // Arrange
      const pending = buildPhase2BatchFTEvent(1, 'Pending');
      const active = buildPhase2BatchFTEvent(2, 'Active');
      active.actual_start_time = 1000;
      const next = buildPhase2BatchFTEvent(3, 'Next');

      // Act
      const focusId = resolveCompanionDefaultFocusId([pending, active, next], next.id, pending.id);

      // Assert
      expect(focusId).assertEqual(active.id);
    });

    it('regression: companion_default_focus_should_fallback_to_current_next_pending_and_first_in_order', 0, () => {
      // Arrange
      const first = buildPhase2BatchFTEvent(11, 'First');
      const second = buildPhase2BatchFTEvent(12, 'Second');

      // Act
      const currentFocusId = resolveCompanionDefaultFocusId([first, second], second.id, 999);
      const nextFocusId = resolveCompanionDefaultFocusId([first, second], 999, second.id);
      const firstFallbackId = resolveCompanionDefaultFocusId([first, second], 999, 998);

      // Assert
      expect(currentFocusId).assertEqual(second.id);
      expect(nextFocusId).assertEqual(second.id);
      expect(firstFallbackId).assertEqual(first.id);
    });

    it('combined: companion_visible_focus_helpers_should_keep_existing_focus_or_fallback_to_first_visible_position', 0, () => {
      // Arrange
      const first = buildPhase2BatchFTEvent(21, 'Museum');
      const second = buildPhase2BatchFTEvent(22, 'Hotel');
      const visibleIndexById = new Map<number, number>([
        [first.id, 0],
        [second.id, 4]
      ]);

      // Act
      const keptFocusId = resolveCompanionVisibleFocusId([first, second], second.id);
      const fallbackFocusId = resolveCompanionVisibleFocusId([first, second], 999);
      const keptPosition = resolveCompanionVisibleFocusPosition(second.id, visibleIndexById);
      const missingPosition = resolveCompanionVisibleFocusPosition(999, visibleIndexById);

      // Assert
      expect(keptFocusId).assertEqual(second.id);
      expect(fallbackFocusId).assertEqual(first.id);
      expect(keptPosition).assertEqual(5);
      expect(missingPosition).assertEqual(0);
    });
  });
}
