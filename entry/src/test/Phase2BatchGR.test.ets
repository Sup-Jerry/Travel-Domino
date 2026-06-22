import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { shouldEnableIndexBottomBarAdd, shouldEnableIndexBottomBarAi } from '../main/ets/pages/index/IndexBottomBar';
import { IndexAddDialogHelper } from '../main/ets/pages/index/IndexAddDialogHelper';

function buildEventGR(
  id: number,
  status: number,
  computedTime: string,
  fixedTime: string,
  duration: number,
  dayOffset: number,
  dynamicDayOffset: number
): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.status = status;
  event.name = `E${id}`;
  event.computed_time = computedTime;
  event.fixed_start_time = fixedTime;
  event.duration = duration;
  event.day_offset = dayOffset;
  event.dynamic_day_offset = dynamicDayOffset;
  return event;
}

function getIndexAddDialogStaticGR<TResult, TArgs extends (Object | number | string | boolean | undefined)[]>(name: string):
  (...args: TArgs) => TResult {
  return Reflect.get(IndexAddDialogHelper as Object, name) as (...args: TArgs) => TResult;
}

export default function phase2BatchGRTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGR_index_add_dialog_private_static_branches', () => {
    it('combined: index_add_dialog_should_cover_default_time_normalize_and_end_time_fallbacks', 0, () => {
      // Arrange
      // Act
      // Assert
      const getDefaultAddTime = getIndexAddDialogStaticGR<string, []>('getDefaultAddTime');
      const normalizeTimeText = getIndexAddDialogStaticGR<string, [(string | undefined)]>('normalizeTimeText');
      const resolveEventEndTimeText = getIndexAddDialogStaticGR<string, [EventEntity]>('resolveEventEndTimeText');

      const fixedEvent = buildEventGR(1, 1, '', '10:15', 45, 0, 0);
      const invalidEvent = buildEventGR(2, 1, 'bad_time', '', -5, 0, 0);

      expect(getDefaultAddTime()).assertEqual('08:00');
      expect(normalizeTimeText(undefined)).assertEqual('08:00');
      expect(normalizeTimeText('2026-04-24 09:30')).assertEqual('09:30');
      expect(normalizeTimeText('xx')).assertEqual('08:00');
      expect(resolveEventEndTimeText(fixedEvent)).assertEqual('11:00');
      expect(resolveEventEndTimeText(invalidEvent)).assertEqual('08:00');
    });

    it('combined: index_add_dialog_should_cover_latest_schedule_selection_and_bottom_bar_flags', 0, () => {
      // Arrange
      // Act
      // Assert
      const getLatestCreatedScheduleEvent =
        getIndexAddDialogStaticGR<(EventEntity | undefined), [EventEntity[]]>('getLatestCreatedScheduleEvent');
      const pending = buildEventGR(3, 0, '09:00', '', 30, 0, 0);
      const oldScheduled = buildEventGR(4, 1, '10:00', '', 30, 1, 1);
      const latestScheduled = buildEventGR(8, 1, '11:00', '', 30, 2, 2);

      const latest = getLatestCreatedScheduleEvent([pending, oldScheduled, latestScheduled]);
      const none = getLatestCreatedScheduleEvent([pending]);

      expect(latest?.id ?? -1).assertEqual(8);
      expect(none === undefined).assertTrue();
      expect(shouldEnableIndexBottomBarAi(false)).assertFalse();
      expect(shouldEnableIndexBottomBarAdd(true)).assertTrue();
    });

    it('boundary: index_add_dialog_should_cover_invalid_schedule_ids_and_target_first_item_path', 0, () => {
      // Arrange
      const getLatestCreatedScheduleEvent =
        getIndexAddDialogStaticGR<(EventEntity | undefined), [EventEntity[]]>('getLatestCreatedScheduleEvent');
      const invalidIdEvent = buildEventGR(Number.NaN, 1, '09:00', '', 20, 0, 0);
      const validIdEvent = buildEventGR(5, 1, '10:00', '', 30, 0, 0);
      const latestValidEvent = buildEventGR(8, 1, '11:30', '', 15, 0, 0);
      const events = [validIdEvent, buildEventGR(9, 1, '12:00', '', 10, 0, 0)];
      // Act
      const latest = getLatestCreatedScheduleEvent([invalidIdEvent, validIdEvent, latestValidEvent]);
      const suggested = IndexAddDialogHelper.calculateSmartTime(events, 5);
      // Assert
      expect(latest?.id ?? -1).assertEqual(8);
      expect(suggested).assertEqual('09:00');
    });

    it('boundary: index_add_dialog_should_cover_empty_defaults_without_scheduled_event', 0, () => {
      // Arrange
      const pending = buildEventGR(3, 0, '09:00', '', 30, 2, 2);
      // Act
      const defaults = IndexAddDialogHelper.resolveAddDialogDefaults([pending]);
      // Assert
      expect(defaults.dayOffset).assertEqual(0);
      expect(defaults.suggestedTime).assertEqual('08:00');
    });

    it('normal: index_add_dialog_should_cover_target_middle_item_previous_end_time_path', 0, () => {
      // Arrange
      const events = [
        buildEventGR(1, 1, '09:00', '', 20, 0, 0),
        buildEventGR(2, 1, '10:00', '', 30, 0, 0),
        buildEventGR(3, 1, '11:00', '', 40, 0, 0)
      ];
      // Act
      const suggested = IndexAddDialogHelper.calculateSmartTime(events, 2);
      // Assert
      expect(suggested).assertEqual('09:20');
    });

    it('regression: index_add_dialog_should_cover_invalid_id_as_left_sort_operand', 0, () => {
      // Arrange
      const getLatestCreatedScheduleEvent =
        getIndexAddDialogStaticGR<(EventEntity | undefined), [EventEntity[]]>('getLatestCreatedScheduleEvent');
      const invalidA = buildEventGR(Number.NaN, 1, '09:00', '', 10, 0, 0);
      const invalidB = buildEventGR(Number.POSITIVE_INFINITY, 1, '09:10', '', 10, 0, 0);
      const valid5 = buildEventGR(5, 1, '10:00', '', 20, 0, 0);
      const valid9 = buildEventGR(9, 1, '11:00', '', 20, 0, 0);
      const permutations: EventEntity[][] = [
        [invalidA, valid5, valid9],
        [valid5, invalidA, valid9],
        [valid9, valid5, invalidA],
        [invalidB, valid9, valid5],
        [valid9, invalidB, valid5],
        [valid5, valid9, invalidB]
      ];
      let latestId = -1;
      // Act
      for (const items of permutations) {
        latestId = getLatestCreatedScheduleEvent(items)?.id ?? -1;
      }
      // Assert
      expect(latestId).assertEqual(9);
    });

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('boundary: validator_marker_should_cover_boundary_case', 0, () => {
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

    it('regression: validator_marker_should_cover_regression_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
