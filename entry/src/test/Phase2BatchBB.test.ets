import { describe, expect, it } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IndexDialogManager } from '../main/ets/pages/index/IndexDialogManager';
import { InitDialogData } from '../main/ets/pages/index/IndexTypes';
import { IndexPageShowHelper } from '../main/ets/pages/index/IndexPageShowHelper';
import { IndexTimelineActionHelper } from '../main/ets/pages/index/IndexTimelineActionHelper';
import {
  resolveIndexToolbarDisplayTitle,
  shouldShowIndexToolbarModeExplanation,
  shouldShowIndexToolbarModeTag,
  shouldShowIndexToolbarWeatherAction
} from '../main/ets/pages/index/IndexToolbar';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface DatePickerDialogOptionsLikeBB {
  start: Date;
  end: Date;
  selected: Date;
  onAccept: (value: DatePickerResult) => void;
}

class DatePickerResultMockBB {
  year: number;
  month: number;
  day: number;

  constructor(year: number, month: number, day: number) {
    this.year = year;
    this.month = month;
    this.day = day;
  }
}

class PickerUiContextMockBB {
  showCount: number = 0;
  dialogs: DatePickerDialogOptionsLikeBB[] = [];

  showDatePickerDialog(options: DatePickerDialogOptionsLikeBB): void {
    this.showCount += 1;
    this.dialogs.push(options);
  }
}

interface TimelineActionVmBB {
  refreshTimelineView(): void;
  moveToBacklog(item: EventEntity): Promise<void>;
}

class TimelineActionVmMockBB implements TimelineActionVmBB {
  refreshCount: number = 0;
  moveItemId: number = -1;
  private readonly rejectMove: boolean;

  constructor(rejectMove: boolean) {
    this.rejectMove = rejectMove;
  }

  refreshTimelineView(): void {
    this.refreshCount += 1;
  }

  moveToBacklog(item: EventEntity): Promise<void> {
    this.moveItemId = item.id;
    if (this.rejectMove) {
      return Promise.reject(new Error('move_failed_bb'));
    }
    return Promise.resolve();
  }
}

interface PageShowVmBB {
  reloadMinEventDurationLimit(): Promise<void>;
  reloadRouteSwitches(): Promise<void>;
}

class PageShowVmMockBB implements PageShowVmBB {
  minReloadCount: number = 0;
  routeReloadCount: number = 0;
  private readonly rejectMinReload: boolean;
  private readonly rejectRouteReload: boolean;

  constructor(rejectMinReload: boolean, rejectRouteReload: boolean) {
    this.rejectMinReload = rejectMinReload;
    this.rejectRouteReload = rejectRouteReload;
  }

  reloadMinEventDurationLimit(): Promise<void> {
    this.minReloadCount += 1;
    if (this.rejectMinReload) {
      return Promise.reject(new Error('reload_min_failed_bb'));
    }
    return Promise.resolve();
  }

  reloadRouteSwitches(): Promise<void> {
    this.routeReloadCount += 1;
    if (this.rejectRouteReload) {
      return Promise.reject(new Error('reload_route_failed_bb'));
    }
    return Promise.resolve();
  }
}

class PageShowProbeBB {
  startCount: number = 0;
  refreshCount: number = 0;
  clearCount: number = 0;
  toastCount: number = 0;
  sanitizeCount: number = 0;
  openCount: number = 0;
  lastToastMessage: string = '';
  lastDialogData?: InitDialogData;
  private readonly tempStateRaw: string;
  private readonly pickedRaw: string;

  constructor(tempStateRaw: string, pickedRaw: string) {
    this.tempStateRaw = tempStateRaw;
    this.pickedRaw = pickedRaw;
  }

  run(vm: PageShowVmMockBB): void {
    IndexPageShowHelper.handlePageShow({
      vm: vm as Object as TimelineViewModel,
      onStartArrivalReminderEngine: () => {
        this.startCount += 1;
      },
      onRefreshUnsavedFlag: () => {
        this.refreshCount += 1;
      },
      onReadDraftStorage: (key: string) => {
        if (key === AppStorageKeys.TEMP_DIALOG_STATE) {
          return this.tempStateRaw;
        }
        if (key === AppStorageKeys.PICKED_LOCATION_STR) {
          return this.pickedRaw;
        }
        return '';
      },
      onClearDraftStorage: () => {
        this.clearCount += 1;
      },
      onOpenDialog: (initData?: InitDialogData) => {
        this.openCount += 1;
        this.lastDialogData = initData;
      },
      onSafeToast: (message: string) => {
        this.toastCount += 1;
        this.lastToastMessage = message;
      },
      onSanitizeError: (_error: Object) => {
        this.sanitizeCount += 1;
        return 'sanitized_bb';
      }
    });
  }
}

function sleepBB(ms: number): Promise<void> {
  return new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
    setTimeout(() => resolve(), ms);
  });
}

function buildExpectedDayStartBB(year: number, month: number, day: number): number {
  const date = new Date();
  date.setFullYear(year, month, day);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

function buildExpectedDayEndBB(year: number, month: number, day: number): number {
  const date = new Date();
  date.setFullYear(year, month, day);
  date.setHours(23, 59, 59, 999);
  return date.getTime();
}

function buildTimelineEventBB(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  event.note = `note_${id}`;
  event.duration = 45;
  event.fixed_start_time = '10:30';
  event.lock_status = 1;
  event.day_offset = 1;
  event.dynamic_day_offset = 2;
  event.status = 1;
  event.latitude = 31.23;
  event.longitude = 121.47;
  return event;
}

function buildTempStateRawBB(name: string, dayOffset: number): string {
  return JSON.stringify({
    name: name,
    note: 'draft_note_bb',
    duration: 61,
    isAnchor: false,
    fixedTime: '09:00',
    dayOffset: dayOffset,
    isSchedule: true,
    lat: 30.12,
    lng: 120.34
  });
}

function buildPickedRawBB(address: string, lat: number, lng: number): string {
  return JSON.stringify({
    address: address,
    lat: lat,
    lng: lng
  });
}

export default function phase2BatchBBTest() {
  describe('phase2BatchBBTest', () => {
    it('normal: index_dialog_manager_open_single_date_filter_picker_should_emit_day_start_timestamp', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      let actualDateMs = -1;
      // Act
      IndexDialogManager.openSingleDateFilterPicker(uiContext as Object as UIContext, new Date(2026, 3, 1).getTime(), (dateMs: number) => {
        actualDateMs = dateMs;
      });
      await sleepBB(140);
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 8) as Object as DatePickerResult);
      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(actualDateMs).assertEqual(buildExpectedDayStartBB(2026, 3, 8));
      done();
    });

    it('boundary: index_dialog_manager_open_single_date_filter_picker_should_fallback_to_current_date_when_plan_start_invalid', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const before = Date.now();
      // Act
      IndexDialogManager.openSingleDateFilterPicker(uiContext as Object as UIContext, 0, (_dateMs: number) => {});
      await sleepBB(140);
      const after = Date.now();
      const startMs = uiContext.dialogs[0].start.getTime();
      const selectedMs = uiContext.dialogs[0].selected.getTime();
      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(startMs >= before && startMs <= after).assertTrue();
      expect(selectedMs >= before && selectedMs <= after).assertTrue();
      done();
    });

    it('invalid: index_dialog_manager_open_single_date_filter_picker_should_follow_date_overflow_normalization', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      let actualDateMs = -1;
      // Act
      IndexDialogManager.openSingleDateFilterPicker(uiContext as Object as UIContext, new Date(2026, 0, 1).getTime(), (dateMs: number) => {
        actualDateMs = dateMs;
      });
      await sleepBB(140);
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 1, 31) as Object as DatePickerResult);
      const expected = new Date();
      expected.setFullYear(2026, 1, 31);
      expected.setHours(0, 0, 0, 0);
      // Assert
      expect(actualDateMs).assertEqual(expected.getTime());
      done();
    });

    it('normal: index_dialog_manager_open_range_date_filter_picker_should_emit_start_and_end_when_both_dates_selected', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      let actualStartMs = -1;
      let actualEndMs = -1;
      // Act
      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 3, 5).getTime(),
        (startMs: number, endMs: number) => {
          actualStartMs = startMs;
          actualEndMs = endMs;
        }
      );
      await sleepBB(140);
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 11) as Object as DatePickerResult);
      await sleepBB(340);
      uiContext.dialogs[1].onAccept(new DatePickerResultMockBB(2026, 3, 13) as Object as DatePickerResult);
      // Assert
      expect(actualStartMs).assertEqual(buildExpectedDayStartBB(2026, 3, 11));
      expect(actualEndMs).assertEqual(buildExpectedDayEndBB(2026, 3, 13));
      done();
    });

    it('boundary: index_dialog_manager_open_range_date_filter_picker_should_open_end_picker_before_callback_fires', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      let actualStartMs = -1;
      let actualEndMs = -1;
      // Act
      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 3, 5).getTime(),
        (startMs: number, endMs: number) => {
          actualStartMs = startMs;
          actualEndMs = endMs;
        }
      );
      await sleepBB(140);
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 12) as Object as DatePickerResult);
      await sleepBB(340);
      // Assert
      expect(uiContext.showCount).assertEqual(2);
      expect(uiContext.dialogs[1].start.getTime()).assertEqual(buildExpectedDayStartBB(2026, 3, 12));
      expect(actualStartMs).assertEqual(-1);
      expect(actualEndMs).assertEqual(-1);
      done();
    });

    it('invalid: index_dialog_manager_open_range_date_filter_picker_should_still_open_first_picker_when_plan_start_is_zero', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const before = Date.now();
      // Act
      IndexDialogManager.openRangeDateFilterPicker(uiContext as Object as UIContext, 0, (_startMs: number, _endMs: number) => {});
      await sleepBB(140);
      const after = Date.now();
      const startMs = uiContext.dialogs[0].start.getTime();
      const selectedMs = uiContext.dialogs[0].selected.getTime();
      // Assert
      expect(uiContext.showCount).assertEqual(1);
      expect(startMs >= before && startMs <= after).assertTrue();
      expect(selectedMs >= before && selectedMs <= after).assertTrue();
      done();
    });

    it('normal: index_dialog_manager_open_range_end_date_picker_should_emit_end_of_day_timestamp', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const startDate = new Date(2026, 3, 9, 0, 0, 0, 0);
      let actualStartMs = -1;
      let actualEndMs = -1;
      // Act
      IndexDialogManager.openRangeEndDatePicker(uiContext as Object as UIContext, startDate, (startMs: number, endMs: number) => {
        actualStartMs = startMs;
        actualEndMs = endMs;
      });
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 10) as Object as DatePickerResult);
      // Assert
      expect(actualStartMs).assertEqual(startDate.getTime());
      expect(actualEndMs).assertEqual(buildExpectedDayEndBB(2026, 3, 10));
    });

    it('boundary: index_dialog_manager_open_range_end_date_picker_should_support_same_day_range', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const startDate = new Date(2026, 3, 10, 0, 0, 0, 0);
      let actualEndMs = -1;
      // Act
      IndexDialogManager.openRangeEndDatePicker(uiContext as Object as UIContext, startDate, (_startMs: number, endMs: number) => {
        actualEndMs = endMs;
      });
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 10) as Object as DatePickerResult);
      // Assert
      expect(actualEndMs).assertEqual(buildExpectedDayEndBB(2026, 3, 10));
    });

    it('invalid: index_dialog_manager_open_range_end_date_picker_should_forward_earlier_end_date_without_guard', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const startDate = new Date(2026, 3, 10, 0, 0, 0, 0);
      let actualStartMs = -1;
      let actualEndMs = -1;
      // Act
      IndexDialogManager.openRangeEndDatePicker(uiContext as Object as UIContext, startDate, (startMs: number, endMs: number) => {
        actualStartMs = startMs;
        actualEndMs = endMs;
      });
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 9) as Object as DatePickerResult);
      // Assert
      expect(actualStartMs).assertEqual(startDate.getTime());
      expect(actualEndMs).assertEqual(buildExpectedDayEndBB(2026, 3, 9));
      expect(actualStartMs > actualEndMs).assertTrue();
    });

    it('normal: index_dialog_manager_open_plan_date_picker_should_emit_day_start_timestamp', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      let actualDateMs = -1;
      // Act
      IndexDialogManager.openPlanDatePicker(uiContext as Object as UIContext, new Date(2026, 3, 1).getTime(), (dateMs: number) => {
        actualDateMs = dateMs;
      });
      uiContext.dialogs[0].onAccept(new DatePickerResultMockBB(2026, 3, 20) as Object as DatePickerResult);
      // Assert
      expect(actualDateMs).assertEqual(buildExpectedDayStartBB(2026, 3, 20));
    });

    it('boundary: index_dialog_manager_open_plan_date_picker_should_keep_selected_timestamp_from_plan_start', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const planStartDate = new Date(2026, 5, 6, 13, 45, 0, 0).getTime();
      // Act
      IndexDialogManager.openPlanDatePicker(uiContext as Object as UIContext, planStartDate, (_dateMs: number) => {});
      // Assert
      expect(uiContext.dialogs[0].selected.getTime()).assertEqual(planStartDate);
    });

    it('invalid: index_dialog_manager_open_plan_date_picker_should_fallback_selected_date_when_plan_start_is_zero', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMockBB();
      const before = Date.now();
      // Act
      IndexDialogManager.openPlanDatePicker(uiContext as Object as UIContext, 0, (_dateMs: number) => {});
      const after = Date.now();
      const selectedMs = uiContext.dialogs[0].selected.getTime();
      // Assert
      expect(selectedMs >= before && selectedMs <= after).assertTrue();
    });

    it('normal: index_timeline_action_helper_handle_move_to_backlog_should_refresh_before_and_after_success', 0, async (done: Function) => {
      // Arrange
      const event = buildTimelineEventBB(1);
      const vm = new TimelineActionVmMockBB(false);
      let toastCount = 0;
      // Act
      IndexTimelineActionHelper.handleMoveToBacklog(
        vm as Object as TimelineViewModel,
        event,
        (_message: string) => {
          toastCount += 1;
        }
      );
      await sleepBB(30);
      // Assert
      expect(vm.moveItemId).assertEqual(1);
      expect(vm.refreshCount).assertEqual(2);
      expect(toastCount).assertEqual(0);
      done();
    });

    it('boundary: index_timeline_action_helper_handle_move_to_backlog_should_block_non_schedule_event', 0, () => {
      // Arrange
      const event = buildTimelineEventBB(2);
      event.status = 0;
      const vm = new TimelineActionVmMockBB(false);
      let toastMessage = '';
      // Act
      IndexTimelineActionHelper.handleMoveToBacklog(
        vm as Object as TimelineViewModel,
        event,
        (message: string) => {
          toastMessage = message;
        }
      );
      // Assert
      expect(vm.moveItemId).assertEqual(-1);
      expect(vm.refreshCount).assertEqual(0);
      expect(toastMessage).assertEqual('该地点不在日程表中');
    });

    it('invalid: index_timeline_action_helper_handle_move_to_backlog_should_toast_when_move_rejected', 0, async (done: Function) => {
      // Arrange
      const event = buildTimelineEventBB(3);
      const vm = new TimelineActionVmMockBB(true);
      let toastMessage = '';
      // Act
      IndexTimelineActionHelper.handleMoveToBacklog(
        vm as Object as TimelineViewModel,
        event,
        (message: string) => {
          toastMessage = message;
        }
      );
      await sleepBB(30);
      // Assert
      expect(vm.moveItemId).assertEqual(3);
      expect(vm.refreshCount).assertEqual(1);
      expect(toastMessage).assertEqual('暂存失败，请重试');
      done();
    });

    it('normal: index_timeline_action_helper_build_edit_dialog_data_should_prefer_dynamic_day_offset', 0, () => {
      // Arrange
      const event = buildTimelineEventBB(4);
      event.day_offset = 0;
      event.dynamic_day_offset = 5;
      // Act
      const data = IndexTimelineActionHelper.buildEditDialogData(event);
      // Assert
      expect(data.name).assertEqual('event_4');
      expect(data.dayOffset).assertEqual(5);
      expect(data.isAnchor).assertTrue();
      expect(data.fixedTime).assertEqual('10:30');
    });

    it('boundary: index_timeline_action_helper_build_edit_dialog_data_should_fallback_to_persisted_day_offset', 0, () => {
      // Arrange
      const event = buildTimelineEventBB(5);
      event.dynamic_day_offset = Number.NaN;
      event.day_offset = 7;
      event.lock_status = 0;
      // Act
      const data = IndexTimelineActionHelper.buildEditDialogData(event);
      // Assert
      expect(data.dayOffset).assertEqual(7);
      expect(data.isAnchor).assertFalse();
    });

    it('invalid: index_timeline_action_helper_build_edit_dialog_data_should_default_day_offset_to_zero_when_all_offsets_invalid', 0, () => {
      // Arrange
      const event = buildTimelineEventBB(6);
      event.dynamic_day_offset = Number.NaN;
      event.day_offset = Number.NaN;
      event.fixed_start_time = '';
      event.latitude = 999;
      event.longitude = -999;
      // Act
      const data = IndexTimelineActionHelper.buildEditDialogData(event);
      // Assert
      expect(data.dayOffset).assertEqual(0);
      expect(data.fixedTime).assertEqual('');
      expect(data.lat).assertEqual(999);
      expect(data.lng).assertEqual(-999);
    });

    it('normal: index_page_show_helper_handle_page_show_should_restore_temp_draft_and_clear_storage', 0, () => {
      // Arrange
      const probe = new PageShowProbeBB(buildTempStateRawBB('draft_name_bb', 2), '');
      const vm = new PageShowVmMockBB(false, false);
      // Act
      probe.run(vm);
      // Assert
      expect(probe.startCount).assertEqual(1);
      expect(probe.refreshCount).assertEqual(1);
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(1);
      expect((probe.lastDialogData as InitDialogData).name).assertEqual('draft_name_bb');
      expect(vm.minReloadCount).assertEqual(1);
      expect(vm.routeReloadCount).assertEqual(1);
    });

    it('boundary: index_page_show_helper_handle_page_show_should_skip_recovery_when_both_caches_empty', 0, () => {
      // Arrange
      const probe = new PageShowProbeBB('', '');
      // Act
      probe.run(new PageShowVmMockBB(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(0);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(0);
    });

    it('invalid: index_page_show_helper_handle_page_show_should_clear_and_toast_for_broken_temp_draft', 0, () => {
      // Arrange
      const probe = new PageShowProbeBB('broken_json_bb', '');
      // Act
      probe.run(new PageShowVmMockBB(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(1);
      expect(probe.lastToastMessage).assertEqual('草稿已损坏，已自动清理。');
    });

    it('conflict: index_page_show_helper_handle_page_show_should_prefer_cleanup_when_picked_cache_invalid', 0, () => {
      // Arrange
      const probe = new PageShowProbeBB(buildTempStateRawBB('draft_conflict_bb', 4), 'invalid_picked_bb');
      // Act
      probe.run(new PageShowVmMockBB(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(1);
      expect(probe.lastToastMessage).assertEqual('地图选点缓存损坏，已自动清理。');
    });

    it('regression: index_page_show_helper_handle_page_show_should_fallback_to_coordinate_label_when_picked_address_blank', 0, () => {
      // Arrange
      const probe = new PageShowProbeBB(buildTempStateRawBB('draft_regression_bb', 5), buildPickedRawBB('   ', 22.54321, 114.05789));
      // Act
      probe.run(new PageShowVmMockBB(false, false));
      const restoredName = (probe.lastDialogData as InitDialogData).name;
      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(1);
      expect(restoredName.indexOf('已选位置(') === 0).assertTrue();
      expect((probe.lastDialogData as InitDialogData).lat).assertEqual(22.54321);
      expect((probe.lastDialogData as InitDialogData).lng).assertEqual(114.05789);
    });

    it('combined: index_page_show_helper_handle_page_show_should_sanitize_reload_errors_without_blocking_merged_restore', 0, async (done: Function) => {
      // Arrange
      const probe = new PageShowProbeBB(
        buildTempStateRawBB('draft_combined_bb', 6),
        buildPickedRawBB('深圳湾公园', 22.50, 113.94)
      );
      const vm = new PageShowVmMockBB(true, true);
      // Act
      probe.run(vm);
      await sleepBB(30);
      // Assert
      expect(probe.sanitizeCount).assertEqual(2);
      expect(probe.openCount).assertEqual(1);
      expect((probe.lastDialogData as InitDialogData).name).assertEqual('深圳湾公园');
      expect((probe.lastDialogData as InitDialogData).dayOffset).assertEqual(6);
      done();
    });

    it('normal: index_toolbar_resolve_display_title_should_truncate_title_when_exceeds_default_limit', 0, () => {
      // Arrange
      const title = '123456789';
      // Act
      const displayTitle = resolveIndexToolbarDisplayTitle(title);
      // Assert
      expect(displayTitle).assertEqual('1234567...');
    });

    it('boundary: index_toolbar_resolve_display_title_should_keep_original_when_equal_to_limit', 0, () => {
      // Arrange
      const title = '1234567';
      // Act
      const displayTitle = resolveIndexToolbarDisplayTitle(title);
      // Assert
      expect(displayTitle).assertEqual('1234567');
    });

    it('invalid: index_toolbar_resolve_display_title_should_return_ellipsis_when_max_length_is_negative', 0, () => {
      // Arrange
      const title = '旅行计划';
      // Act
      const displayTitle = resolveIndexToolbarDisplayTitle(title, -1);
      // Assert
      expect(displayTitle).assertEqual('...');
    });

    it('normal: index_toolbar_should_show_mode_tag_for_non_zero_strategy_mode', 0, () => {
      // Arrange
      const strategyMode = 1;
      // Act
      const show = shouldShowIndexToolbarModeTag(strategyMode);
      // Assert
      expect(show).assertTrue();
    });

    it('boundary: index_toolbar_should_hide_mode_tag_for_zero_strategy_mode', 0, () => {
      // Arrange
      const strategyMode = 0;
      // Act
      const show = shouldShowIndexToolbarModeTag(strategyMode);
      // Assert
      expect(show).assertFalse();
    });

    it('invalid: index_toolbar_should_treat_nan_strategy_mode_as_non_zero_for_mode_tag', 0, () => {
      // Arrange
      const strategyMode = Number.NaN;
      // Act
      const show = shouldShowIndexToolbarModeTag(strategyMode);
      // Assert
      expect(show).assertTrue();
    });

    it('normal: index_toolbar_should_show_mode_explanation_when_mode_enabled_and_text_present', 0, () => {
      // Arrange
      const strategyMode = 2;
      const explanation = '节奏更轻松';
      // Act
      const show = shouldShowIndexToolbarModeExplanation(strategyMode, explanation);
      // Assert
      expect(show).assertTrue();
    });

    it('boundary: index_toolbar_should_hide_mode_explanation_when_strategy_mode_is_zero', 0, () => {
      // Arrange
      const strategyMode = 0;
      const explanation = '仍然有文案';
      // Act
      const show = shouldShowIndexToolbarModeExplanation(strategyMode, explanation);
      // Assert
      expect(show).assertFalse();
    });

    it('invalid: index_toolbar_should_treat_whitespace_explanation_as_truthy_when_mode_enabled', 0, () => {
      // Arrange
      const strategyMode = 1;
      const explanation = '   ';
      // Act
      const show = shouldShowIndexToolbarModeExplanation(strategyMode, explanation);
      // Assert
      expect(show).assertTrue();
    });

    it('normal: index_toolbar_should_show_weather_action_when_not_in_companion_mode_and_feature_enabled', 0, () => {
      // Arrange
      // Act
      const show = shouldShowIndexToolbarWeatherAction(false, true);
      // Assert
      expect(show).assertTrue();
    });

    it('boundary: index_toolbar_should_hide_weather_action_when_feature_disabled', 0, () => {
      // Arrange
      // Act
      const show = shouldShowIndexToolbarWeatherAction(false, false);
      // Assert
      expect(show).assertFalse();
    });

    it('invalid: index_toolbar_should_hide_weather_action_when_companion_mode_blocks_entry', 0, () => {
      // Arrange
      // Act
      const show = shouldShowIndexToolbarWeatherAction(true, true);
      // Assert
      expect(show).assertFalse();
    });
  });
}
