import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  getCompanionEventStateLabel,
  getCompanionFilterLabel,
  getCompanionFilterOptions,
  getCompanionStateCoreColor
} from '../main/ets/pages/components/views/companion/CompanionDisplayHelper';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';

function buildEvent(id: number, state: 'PENDING' | 'ACTIVE' | 'COMPLETED' | 'SKIPPED'): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  if (state === 'ACTIVE') {
    event.actual_start_time = Date.now() - 60000;
  } else if (state === 'COMPLETED') {
    event.completion_status = EventEntity.STATE_COMPLETED;
    event.actual_start_time = Date.now() - 7200000;
    event.actual_end_time = Date.now() - 3600000;
  } else if (state === 'SKIPPED') {
    event.completion_status = EventEntity.STATE_SKIPPED;
  }
  return event;
}

export default function companionDisplayHelperPaletteMatrixTest() {
  describe('unit_test_case_generator_autofill_CompanionDisplayHelperPaletteMatrix', () => {
    it('normal: core_color_should_map_active_event_to_success_palette', 0, () => {
      // Arrange
      const palette = ThemeCenter.getPalette('light');
      const active = buildEvent(1, 'ACTIVE');

      // Act
      const color = getCompanionStateCoreColor(active, palette);

      // Assert
      expect(color as string).assertEqual(palette.success);
    });

    it('boundary: core_color_should_map_completed_and_skipped_to_dedicated_palette_tokens', 0, () => {
      // Arrange
      const palette = ThemeCenter.getPalette('light');
      const completed = buildEvent(2, 'COMPLETED');
      const skipped = buildEvent(3, 'SKIPPED');

      // Act
      const completedColor = getCompanionStateCoreColor(completed, palette);
      const skippedColor = getCompanionStateCoreColor(skipped, palette);

      // Assert
      expect(completedColor as string).assertEqual(palette.statusCompleted);
      expect(skippedColor as string).assertEqual(palette.statusSkipped);
    });

    it('invalid: core_color_should_fallback_to_pending_palette_for_pending_state', 0, () => {
      // Arrange
      const palette = ThemeCenter.getPalette('light');
      const pending = buildEvent(4, 'PENDING');

      // Act
      const color = getCompanionStateCoreColor(pending, palette);

      // Assert
      expect(color as string).assertEqual(palette.statusPending);
    });

    it('conflict: filter_label_should_be_state_specific_and_not_all_equal', 0, () => {
      // Arrange
      const all = getCompanionFilterLabel('ALL');
      const pending = getCompanionFilterLabel('PENDING');
      const active = getCompanionFilterLabel('ACTIVE');
      const completed = getCompanionFilterLabel('COMPLETED');
      const skipped = getCompanionFilterLabel('SKIPPED');

      // Act
      const uniqueCount = new Set<string>([all, pending, active, completed, skipped]).size;

      // Assert
      expect(all.length > 0).assertTrue();
      expect(uniqueCount >= 4).assertTrue();
    });

    it('regression: filter_options_should_keep_full_state_order', 0, () => {
      // Arrange
      const expected = ['ALL', 'PENDING', 'ACTIVE', 'COMPLETED', 'SKIPPED'];

      // Act
      const actual = getCompanionFilterOptions();

      // Assert
      expect(actual.length).assertEqual(5);
      expect(actual[0]).assertEqual(expected[0]);
      expect(actual[1]).assertEqual(expected[1]);
      expect(actual[2]).assertEqual(expected[2]);
      expect(actual[3]).assertEqual(expected[3]);
      expect(actual[4]).assertEqual(expected[4]);
    });

    it('combined: event_state_labels_should_remain_non_empty_across_four_states', 0, () => {
      // Arrange
      const pending = buildEvent(5, 'PENDING');
      const active = buildEvent(6, 'ACTIVE');
      const completed = buildEvent(7, 'COMPLETED');
      const skipped = buildEvent(8, 'SKIPPED');

      // Act
      const pendingLabel = getCompanionEventStateLabel(pending);
      const activeLabel = getCompanionEventStateLabel(active);
      const completedLabel = getCompanionEventStateLabel(completed);
      const skippedLabel = getCompanionEventStateLabel(skipped);

      // Assert
      expect(pendingLabel.length > 0).assertTrue();
      expect(activeLabel.length > 0).assertTrue();
      expect(completedLabel.length > 0).assertTrue();
      expect(skippedLabel.length > 0).assertTrue();
    });
  });
}
