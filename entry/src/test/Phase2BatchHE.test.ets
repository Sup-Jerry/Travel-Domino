import { describe, expect, it } from '@ohos/hypium';
import { AddDialogDefaults, InitDialogData, PendingItemData } from '../main/ets/pages/index/IndexTypes';

function buildInitDialogDataHE(defaults: AddDialogDefaults, name: string, duration: number): InitDialogData {
  return {
    name: name,
    note: 'note',
    duration: duration,
    isAnchor: true,
    fixedTime: defaults.suggestedTime,
    dayOffset: defaults.dayOffset
  };
}

function buildPendingItemHE(data: InitDialogData, id: number, targetDateMs: number): PendingItemData {
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

export default function phase2BatchHETest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHE_index_types_optional_fields', () => {
    it('combined: index_types_should_default_pending_is_schedule_to_false_when_init_data_omits_flag', 0, () => {
      const defaults = new AddDialogDefaults();
      defaults.dayOffset = 2;
      defaults.suggestedTime = '11:10';
      const initData = buildInitDialogDataHE(defaults, 'gallery', 70);

      const pending = buildPendingItemHE(initData, 301, new Date(2026, 7, 9).getTime());

      expect(initData.isSchedule === undefined).assertTrue();
      expect(pending.isSchedule).assertFalse();
      expect(pending.fixedTime).assertEqual('11:10');
      expect(pending.dayOffset).assertEqual(2);
    });

    it('combined: index_types_should_keep_lat_lng_and_note_when_optional_fields_are_provided', 0, () => {
      const defaults = new AddDialogDefaults();
      const initData = buildInitDialogDataHE(defaults, 'lake', 95);
      initData.isSchedule = true;
      initData.note = 'bring camera';
      initData.lat = 30.567;
      initData.lng = 114.321;

      const targetDateMs = new Date(2026, 8, 10).getTime();
      const pending = buildPendingItemHE(initData, 302, targetDateMs);

      expect(pending.isSchedule).assertTrue();
      expect(pending.note).assertEqual('bring camera');
      expect(pending.lat).assertEqual(30.567);
      expect(pending.lng).assertEqual(114.321);
      expect(pending.targetDateMs).assertEqual(targetDateMs);
    });
  });
}
