import { describe, it, expect } from '@ohos/hypium';
import { AddDialogDefaults, InitDialogData, PendingItemData } from '../main/ets/pages/index/IndexTypes';

function buildInitDialogData(defaults: AddDialogDefaults, name: string, duration: number): InitDialogData {
  return {
    name: name,
    note: '',
    duration: duration,
    isAnchor: false,
    fixedTime: defaults.suggestedTime,
    dayOffset: defaults.dayOffset,
    isSchedule: true
  };
}

function buildPendingItem(data: InitDialogData, id: number, targetDateMs: number): PendingItemData {
  return {
    id: id,
    name: data.name,
    duration: data.duration,
    isSchedule: data.isSchedule === true,
    fixedTime: data.fixedTime,
    dayOffset: data.dayOffset,
    targetDateMs: targetDateMs,
    note: data.note,
    lat: data.lat,
    lng: data.lng
  };
}

export default function indexTypesTest() {
  describe('unit_test_case_generator_autofill_IndexTypes', () => {
    it('normal: add_dialog_defaults_should_use_expected_initial_values', 0, () => {
      // Arrange
      const defaults = new AddDialogDefaults();

      // Act
      const actualDayOffset = defaults.dayOffset;
      const actualSuggestedTime = defaults.suggestedTime;

      // Assert
      expect(actualDayOffset).assertEqual(0);
      expect(actualSuggestedTime).assertEqual('08:00');
    });

    it('boundary: add_dialog_defaults_should_allow_edge_time_and_large_day_offset', 0, () => {
      // Arrange
      const defaults = new AddDialogDefaults();

      // Act
      defaults.dayOffset = 365;
      defaults.suggestedTime = '23:59';

      // Assert
      expect(defaults.dayOffset).assertEqual(365);
      expect(defaults.suggestedTime).assertEqual('23:59');
    });

    it('invalid: pending_item_should_keep_optional_fields_undefined_when_not_provided', 0, () => {
      // Arrange
      const defaults = new AddDialogDefaults();
      const initData = buildInitDialogData(defaults, 'museum', 90);

      // Act
      const pending = buildPendingItem(initData, 101, new Date(2026, 4, 1).getTime());

      // Assert
      expect(pending.fixedTime).assertEqual('08:00');
      expect(pending.lat === undefined).assertTrue();
      expect(pending.lng === undefined).assertTrue();
    });

    it('conflict: mutating_one_defaults_instance_should_not_affect_another_instance', 0, () => {
      // Arrange
      const first = new AddDialogDefaults();
      const second = new AddDialogDefaults();

      // Act
      first.dayOffset = 2;
      first.suggestedTime = '10:30';

      // Assert
      expect(first.dayOffset).assertEqual(2);
      expect(first.suggestedTime).assertEqual('10:30');
      expect(second.dayOffset).assertEqual(0);
      expect(second.suggestedTime).assertEqual('08:00');
    });

    it('regression: a_new_defaults_instance_should_still_return_original_baseline_values', 0, () => {
      // Arrange
      const previous = new AddDialogDefaults();
      previous.dayOffset = 9;
      previous.suggestedTime = '21:15';

      // Act
      const fresh = new AddDialogDefaults();

      // Assert
      expect(fresh.dayOffset).assertEqual(0);
      expect(fresh.suggestedTime).assertEqual('08:00');
    });

    it('combined: init_and_pending_data_should_share_same_day_offset_and_time_from_defaults', 0, () => {
      // Arrange
      const defaults = new AddDialogDefaults();
      defaults.dayOffset = 3;
      defaults.suggestedTime = '14:20';
      const targetDateMs = new Date(2026, 6, 8).getTime();

      // Act
      const initData = buildInitDialogData(defaults, 'park', 120);
      const pending = buildPendingItem(initData, 202, targetDateMs);

      // Assert
      expect(initData.dayOffset).assertEqual(3);
      expect(initData.fixedTime).assertEqual('14:20');
      expect(pending.dayOffset).assertEqual(3);
      expect(pending.fixedTime).assertEqual('14:20');
      expect(pending.targetDateMs).assertEqual(targetDateMs);
    });
  });
}
