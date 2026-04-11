import { describe, it, expect } from '@ohos/hypium';
import {
  resolveCompanionFocusedActionMode,
  shouldRenderFocusedSwitchCards,
  shouldShowFocusedPlannedRange
} from '../main/ets/pages/components/views/companion/CompanionFocusedCardHost';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

function buildEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  return event;
}

export default function companionFocusedCardHostHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionFocusedCardHostHelper', () => {
    it('normal: planned_range_should_show_for_non_pending_state', 0, () => {
      // Arrange
      const state = 'ACTIVE';

      // Act
      const visible = shouldShowFocusedPlannedRange(state);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: focused_action_mode_should_match_paused_current_event', 0, () => {
      // Arrange
      const mode = resolveCompanionFocusedActionMode('COMPLETED', 'PAUSED', 10, 10);

      // Act
      const isPausedActive = mode === 'PAUSED_ACTIVE';

      // Assert
      expect(isPausedActive).assertTrue();
    });

    it('invalid: focused_action_mode_should_fallback_to_disabled_for_unknown_state', 0, () => {
      // Arrange
      const state = 'UNKNOWN';

      // Act
      const mode = resolveCompanionFocusedActionMode(state, 'IDLE', -1, 1);

      // Assert
      expect(mode).assertEqual('DISABLED');
    });

    it('conflict: focused_action_mode_should_prioritize_active_over_paused', 0, () => {
      // Arrange
      const state = 'ACTIVE';

      // Act
      const mode = resolveCompanionFocusedActionMode(state, 'PAUSED', 1, 1);

      // Assert
      expect(mode).assertEqual('ACTIVE');
    });

    it('regression: switch_cards_should_require_both_outgoing_and_incoming', 0, () => {
      // Arrange
      const outgoing = buildEvent(1);

      // Act
      const renderable = shouldRenderFocusedSwitchCards(true, outgoing, null);

      // Assert
      expect(renderable).assertFalse();
    });

    it('combined: focused_helper_matrix_should_cover_pending_active_and_switch_render', 0, () => {
      // Arrange
      const outgoing = buildEvent(11);
      const incoming = buildEvent(12);

      // Act
      const pendingMode = resolveCompanionFocusedActionMode('PENDING', 'IDLE', -1, 11);
      const activeMode = resolveCompanionFocusedActionMode('ACTIVE', 'IDLE', 11, 11);
      const renderable = shouldRenderFocusedSwitchCards(true, outgoing, incoming);

      // Assert
      expect(pendingMode).assertEqual('PENDING');
      expect(activeMode).assertEqual('ACTIVE');
      expect(renderable).assertTrue();
    });
  });
}
