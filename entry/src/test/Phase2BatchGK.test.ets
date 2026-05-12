import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  buildIndexTimelineHeaderText,
  IndexTimelineView,
  resolveIndexTimelineBottomSpacerHeight,
  resolveIndexTimelineVisiblePlaceCount,
  shouldEnableIndexTimelineItem,
  shouldShowIndexTimelineGapHint,
  shouldShowIndexTimelineGroupItems
} from '../main/ets/pages/index/IndexTimelineView';
import {
  AddItemDialogCallbacks,
  DateFilterOpenCallbacks,
  GapResolutionCallbacks,
  IndexDialogManager,
  ShareDialogCallbacks
} from '../main/ets/pages/index/IndexDialogManager';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface IndexTimelineGroupGK {
  dayOffset: number;
  actualDateMs: number;
  dateHeader: string;
  events: EventEntity[];
}

interface IndexTimelineParamsGK {
  groupedEvents?: IndexTimelineGroupGK[];
  allEvents?: EventEntity[];
  isArchived?: boolean;
  isCompanionMode?: boolean;
  showWeather?: boolean;
  isPageRefreshing?: boolean;
  gapsCount?: number;
  onIsDayCollapsed?: (dayOffset: number) => boolean;
}

interface IndexTimelinePrivateGK {
  buildDateHeader(text: string, dayOffset: number, placeCount: number): void;
  swipeStartAction(item: EventEntity): void;
  swipeEndAction(item: EventEntity): void;
  setInitiallyProvidedValue(params: IndexTimelineParamsGK): void;
  initialRender(): void;
}

interface DatePickerDialogOptionsGK {
  start: Date;
  end: Date;
  selected: Date;
  onAccept: (value: DatePickerResult) => void;
}

class DatePickerResultGK {
  year: number;
  month: number;
  day: number;

  constructor(year: number, month: number, day: number) {
    this.year = year;
    this.month = month;
    this.day = day;
  }
}

class PickerUiContextGK {
  showCount: number = 0;
  dialogs: DatePickerDialogOptionsGK[] = [];

  showDatePickerDialog(options: DatePickerDialogOptionsGK): void {
    this.showCount += 1;
    this.dialogs.push(options);
  }
}

class VmMockGK {
  planId: number = 17;
}

function buildEventGK(id: number, name: string): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.sort_order = id;
  event.status = 1;
  return event;
}

export default function phase2BatchGKTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGK_index_timeline_dialog_manager_lines', () => {
    it('combined: index_timeline_view_should_cover_header_swipe_helpers_and_render_matrix', 0, () => {
      const page = new IndexTimelineView(undefined, {} as LocalStorage) as Object as IndexTimelinePrivateGK;
      const first = buildEventGK(401, 'museum');
      const second = buildEventGK(402, 'station');
      let headerThrew = false;
      let startThrew = false;
      let endThrew = false;
      let listRenderThrew = false;
      let archivedRenderThrew = false;

      try {
        page.buildDateHeader('Day 1', 0, 2);
      } catch (_error) {
        headerThrew = true;
      }
      try {
        page.swipeStartAction(first);
      } catch (_error) {
        startThrew = true;
      }
      try {
        page.swipeEndAction(first);
      } catch (_error) {
        endThrew = true;
      }

      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 0,
          actualDateMs: 1,
          dateHeader: 'Day 1',
          events: [first, second]
        }],
        allEvents: [first, second],
        isArchived: false,
        isCompanionMode: false,
        showWeather: true,
        isPageRefreshing: false,
        gapsCount: 2,
        onIsDayCollapsed: (_dayOffset: number) => false
      });
      try {
        page.initialRender();
      } catch (_error) {
        listRenderThrew = true;
      }

      page.setInitiallyProvidedValue({
        groupedEvents: [{
          dayOffset: 1,
          actualDateMs: 2,
          dateHeader: 'Day 2',
          events: [first]
        }],
        allEvents: [first],
        isArchived: true,
        isCompanionMode: true,
        showWeather: false,
        isPageRefreshing: true,
        gapsCount: 0,
        onIsDayCollapsed: (_dayOffset: number) => true
      });
      try {
        page.initialRender();
      } catch (_error) {
        archivedRenderThrew = true;
      }

      expect(headerThrew).assertFalse();
      expect(startThrew).assertFalse();
      expect(endThrew).assertFalse();
      expect(listRenderThrew).assertFalse();
      expect(archivedRenderThrew).assertFalse();
      expect(resolveIndexTimelineVisiblePlaceCount(-3)).assertEqual(0);
      expect(buildIndexTimelineHeaderText('Day 1', 2).length > 0).assertTrue();
      expect(shouldShowIndexTimelineGroupItems(false)).assertTrue();
      expect(shouldEnableIndexTimelineItem(true)).assertFalse();
      expect(shouldShowIndexTimelineGapHint(false, 2)).assertTrue();
      expect(resolveIndexTimelineBottomSpacerHeight(true)).assertEqual(24);
    });

    it('combined: index_dialog_manager_should_cover_date_filter_open_and_special_controller_creation', 0, async (done: Function) => {
      const uiContext = new PickerUiContextGK();
      const vm = new VmMockGK();
      let showAllCount = 0;
      let singleDateMs = -1;
      let rangeStartMs = -1;
      let rangeEndMs = -1;
      const callbacks: DateFilterOpenCallbacks = {
        onShowAll: (): void => { showAllCount += 1; },
        onSelectDate: (dateMs: number): void => { singleDateMs = dateMs; },
        onSelectRange: (startMs: number, endMs: number): void => {
          rangeStartMs = startMs;
          rangeEndMs = endMs;
        }
      };

      const dialogController = IndexDialogManager.openDateFilterDialog(
        uiContext as Object as UIContext,
        new Date(2026, 0, 1).getTime(),
        callbacks
      ) as Object;

      const gapController = IndexDialogManager.createGapResolutionController({
        vm: vm as Object as TimelineViewModel,
        currentGap: null
      } as GapResolutionCallbacks) as Object;

      const addController = IndexDialogManager.createAddItemController({
        initName: 'spot',
        initNote: 'note',
        initDuration: 60,
        initIsAnchor: false,
        initFixedTime: '09:00',
        initSuggestedTime: '09:20',
        initIsSchedule: true,
        initDayOffset: 1,
        initPreTravel: 0,
        initPriority: 0,
        storageScopePlanId: 8,
        planStartDate: 9,
        initLat: 0,
        initLng: 0,
        onDateChangedRecommendTime: (_dayOffset: number, currentTime: string) => currentTime,
        onConfirm: async (
          _name: string,
          _duration: number,
          _isSchedule: boolean
        ): Promise<void> => {}
      } as AddItemDialogCallbacks) as Object;

      const shareController = IndexDialogManager.createShareController({
        planId: 1,
        planTitle: 'share',
        startDate: 2,
        endDate: 3,
        totalDays: 1,
        totalEvents: 1,
        compressedJson: '{}'
      } as ShareDialogCallbacks) as Object;

      expect(typeof Reflect.get(dialogController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(gapController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(addController, 'open')).assertEqual('function');
      expect(typeof Reflect.get(shareController, 'open')).assertEqual('function');

      IndexDialogManager.openSingleDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 0, 1).getTime(),
        callbacks.onSelectDate
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      uiContext.dialogs[0].onAccept(new DatePickerResultGK(2026, 0, 5) as Object as DatePickerResult);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });

      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 0, 1).getTime(),
        callbacks.onSelectRange
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      uiContext.dialogs[1].onAccept(new DatePickerResultGK(2026, 0, 7) as Object as DatePickerResult);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 360);
      });
      uiContext.dialogs[2].onAccept(new DatePickerResultGK(2026, 0, 9) as Object as DatePickerResult);

      callbacks.onShowAll();

      expect(uiContext.showCount).assertEqual(3);
      expect(singleDateMs > 0).assertTrue();
      expect(rangeStartMs > 0).assertTrue();
      expect(rangeEndMs >= rangeStartMs).assertTrue();
      expect(showAllCount).assertEqual(1);
      done();
    });
  });
}
