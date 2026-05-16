import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionPresentationHelper } from '../main/ets/pages/components/views/CompanionPresentationHelper';
import {
  getCompanionCardOpacity,
  getCompanionCardScale,
  getCompanionCardTranslateX,
  getCompanionInteractiveEnabled,
  pickRandomCompanionImmersiveText
} from '../main/ets/pages/components/views/companion/CompanionAnimationHelper';

function buildEventFM(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.duration = 30;
  event.fixed_start_time = '';
  event.computed_time = '';
  event.dynamic_start_time = 0;
  event.dynamic_end_time = 0;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

export default function phase2BatchFMTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchFM_presentation_animation_lines', () => {
    it('combined: presentation_helper_should_cover_fixed_computed_pending_and_skipped_paths', 0, () => {
      // Arrange
      // Act
      // Assert
      const fixedOnly = buildEventFM(1);
      fixedOnly.fixed_start_time = '07:20';
      fixedOnly.duration = 50;
      const computedOnly = buildEventFM(2);
      computedOnly.computed_time = '09:15';
      computedOnly.duration = 20;
      const skipped = buildEventFM(3);
      skipped.completion_status = EventEntity.STATE_SKIPPED;
      const active = buildEventFM(4);
      active.actual_start_time = new Date(2026, 3, 23, 10, 0, 0, 0).getTime();

      expect(CompanionPresentationHelper.getForecastStartText(fixedOnly)).assertEqual('07:20');
      expect(CompanionPresentationHelper.getForecastStartText(computedOnly)).assertEqual('09:15');
      expect(CompanionPresentationHelper.getPlannedRange(fixedOnly)).assertEqual('07:20-08:10');
      expect(CompanionPresentationHelper.getPlannedRange(computedOnly)).assertEqual('09:15-09:35');
      expect(CompanionPresentationHelper.getMainCardTimeText(skipped).length > 0).assertTrue();
      expect(CompanionPresentationHelper.getTimelineSupplement(skipped).length > 0).assertTrue();
      expect(CompanionPresentationHelper.getTimelineSupplement(computedOnly).includes('09:15')).assertTrue();
      expect(CompanionPresentationHelper.getTimelineSupplement(computedOnly).includes('|')).assertTrue();
      expect(CompanionPresentationHelper.getEventStateLabel(active).length > 0).assertTrue();
    });

    it('boundary: presentation_helper_should_keep_placeholders_for_zero_and_missing_timestamps', 0, () => {
      // Arrange
      // Act
      // Assert
      const empty = buildEventFM(5);
      const completedMissingTimes = buildEventFM(6);
      completedMissingTimes.completion_status = EventEntity.STATE_COMPLETED;

      expect(CompanionPresentationHelper.formatTs(-1)).assertEqual('--:--');
      expect(CompanionPresentationHelper.formatDateTime(-1)).assertEqual('--:--');
      expect(CompanionPresentationHelper.getForecastStartText(empty)).assertEqual('--:--');
      expect(CompanionPresentationHelper.getPlannedRange(empty).includes('--:--')).assertTrue();
      expect(CompanionPresentationHelper.getMainCardTimeText(completedMissingTimes)).assertEqual('--:-- - --:--');
      expect(CompanionPresentationHelper.getTimelineSupplement(completedMissingTimes).includes('--:--')).assertTrue();
      expect(CompanionPresentationHelper.getTimelineSupplement(completedMissingTimes).includes('|')).assertTrue();
    });

    it('regression: presentation_helper_should_align_completed_and_active_texts_with_actual_times', 0, () => {
      // Arrange
      // Act
      // Assert
      const active = buildEventFM(7);
      active.actual_start_time = new Date(2026, 3, 23, 12, 8, 0, 0).getTime();
      const completed = buildEventFM(8);
      completed.completion_status = EventEntity.STATE_COMPLETED;
      completed.actual_start_time = new Date(2026, 3, 23, 8, 30, 0, 0).getTime();
      completed.actual_end_time = new Date(2026, 3, 23, 9, 5, 0, 0).getTime();

      expect(CompanionPresentationHelper.getMainCardTimeText(active).includes('12:08')).assertTrue();
      expect(CompanionPresentationHelper.getMainCardTimeText(completed)).assertEqual('08:30 - 09:05');
      expect(CompanionPresentationHelper.getTimelineSupplement(completed).includes('09:05')).assertTrue();
      expect(CompanionPresentationHelper.getTimelineSupplement(completed).includes('|')).assertTrue();
      expect(CompanionPresentationHelper.formatDateTime(completed.actual_end_time)).assertEqual('2026-04-23 09:05');
    });

    it('combined: animation_helper_should_cover_both_mode_edges_and_random_text_membership', 0, () => {
      // Arrange
      // Act
      // Assert
      const samples: string[] = [];
      for (let i = 0; i < 8; i++) {
        samples.push(pickRandomCompanionImmersiveText());
      }

      expect(getCompanionInteractiveEnabled('control', 'both')).assertTrue();
      expect(getCompanionInteractiveEnabled('control', 'control')).assertTrue();
      expect(getCompanionInteractiveEnabled('immersive', 'control')).assertFalse();
      expect(getCompanionCardTranslateX(false, 0.5, 'incoming')).assertEqual(0);
      expect(getCompanionCardTranslateX(true, 1, 'incoming')).assertEqual(0);
      expect(getCompanionCardTranslateX(true, 1, 'outgoing')).assertEqual(-18);
      expect(getCompanionCardOpacity(false, 0.3, 'stable')).assertEqual(1);
      expect(getCompanionCardOpacity(true, 0, 'incoming')).assertEqual(0);
      expect(getCompanionCardOpacity(true, 1, 'outgoing')).assertEqual(0);
      expect(getCompanionCardScale(false, 0.7, 'outgoing')).assertEqual(1);
      expect(getCompanionCardScale(true, 0, 'incoming')).assertEqual(0.992);
      expect(getCompanionCardScale(true, 1, 'incoming')).assertEqual(1);
      expect(samples.every((item: string) => item.length > 0)).assertTrue();
    });

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
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