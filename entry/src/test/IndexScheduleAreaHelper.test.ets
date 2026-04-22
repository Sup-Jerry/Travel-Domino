import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  IndexScheduleArea,
  resolveIndexScheduleBottomBarAddEnabled,
  resolveIndexScheduleBottomBarAiEnabled,
  resolveIndexScheduleUnsavedMarginBottom,
  shouldShowIndexScheduleBottomBar
} from '../main/ets/pages/index/IndexScheduleArea';

interface IndexScheduleThemeTest {
  pageBg?: string;
  textPrimary?: string;
  primary?: string;
  divider?: string;
}

interface IndexScheduleGroupTest {
  dayOffset: number;
  actualDateMs: number;
  dateHeader: string;
  events: EventEntity[];
}

interface IndexScheduleAreaParamsTest {
  vm?: Object;
  groupedEvents?: IndexScheduleGroupTest[];
  allEvents?: EventEntity[];
  isArchived?: boolean;
  isCompanionMode?: boolean;
  showWeather?: boolean;
  isPageRefreshing?: boolean;
  gapsCount?: number;
  hasUnsavedChanges?: boolean;
  timelineTheme?: IndexScheduleThemeTest;
  unsavedTheme?: IndexScheduleThemeTest;
  onIsDayCollapsed?: (dayOffset: number) => boolean;
  onToggleDay?: (dayOffset: number) => void;
  onRefresh?: () => void;
  onOpenEditDialog?: (item: EventEntity) => void;
  onOpenTimeEditDialog?: (item: EventEntity) => void;
  onGapFound?: (item: EventEntity) => void;
  onResolveConflictAction?: (item: EventEntity, strategy: string, gapMinutes: number) => void;
  onConfirmMoveToBacklog?: (item: EventEntity) => void;
  onConfirmDeleteEvent?: (item: EventEntity) => void;
  onOpenGapOptimize?: () => void;
  onFilter?: () => void;
  onAi?: () => void;
  onAdd?: () => void;
  onUndo?: () => void;
  onSave?: () => void;
}

interface IndexScheduleAreaPrivateTest {
  vm: Object;
  groupedEvents: IndexScheduleGroupTest[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  hasUnsavedChanges: boolean;
  timelineTheme: IndexScheduleThemeTest;
  unsavedTheme: IndexScheduleThemeTest;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onRefresh: () => void;
  onOpenEditDialog: (item: EventEntity) => void;
  onOpenTimeEditDialog: (item: EventEntity) => void;
  onGapFound: (item: EventEntity) => void;
  onResolveConflictAction: (item: EventEntity, strategy: string, gapMinutes: number) => void;
  onConfirmMoveToBacklog: (item: EventEntity) => void;
  onConfirmDeleteEvent: (item: EventEntity) => void;
  onOpenGapOptimize: () => void;
  onFilter: () => void;
  onAi: () => void;
  onAdd: () => void;
  onUndo: () => void;
  onSave: () => void;
  setInitiallyProvidedValue(params: IndexScheduleAreaParamsTest): void;
  updateStateVars(params: IndexScheduleAreaParamsTest): void;
  initialRender(): void;
}

function buildScheduleEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `schedule_event_${id}`;
  return event;
}

class IndexScheduleVmPlaceholderTest {
  label: string = '';
}

export default function indexScheduleAreaHelperTest() {
  describe('unit_test_case_generator_autofill_IndexScheduleAreaHelper', () => {
    it('normal: schedule_bottom_bar_should_show_when_not_in_companion_mode', 0, () => {
      // Arrange
      const isCompanionMode = false;

      // Act
      const show = shouldShowIndexScheduleBottomBar(isCompanionMode);

      // Assert
      expect(show).assertTrue();
    });

    it('boundary: schedule_bottom_bar_should_hide_in_companion_mode', 0, () => {
      // Arrange
      const isCompanionMode = true;

      // Act
      const show = shouldShowIndexScheduleBottomBar(isCompanionMode);

      // Assert
      expect(show).assertFalse();
    });

    it('invalid: schedule_bottom_bar_actions_should_disable_when_archived', 0, () => {
      // Arrange
      const isArchived = true;

      // Act
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(isArchived);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(isArchived);

      // Assert
      expect(aiEnabled).assertFalse();
      expect(addEnabled).assertFalse();
    });

    it('conflict: schedule_bottom_bar_actions_should_enable_when_not_archived', 0, () => {
      // Arrange
      const isArchived = false;

      // Act
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(isArchived);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(isArchived);

      // Assert
      expect(aiEnabled).assertTrue();
      expect(addEnabled).assertTrue();
    });

    it('regression: schedule_unsaved_margin_should_match_mode_switch', 0, () => {
      // Arrange
      const companionMode = true;
      const normalMode = false;

      // Act
      const companionMargin = resolveIndexScheduleUnsavedMarginBottom(companionMode);
      const normalMargin = resolveIndexScheduleUnsavedMarginBottom(normalMode);

      // Assert
      expect(companionMargin).assertEqual(30);
      expect(normalMargin).assertEqual(96);
    });

    it('combined: schedule_helper_matrix_should_keep_visibility_enablement_and_margin_consistent', 0, () => {
      // Arrange
      const showBottomBar = shouldShowIndexScheduleBottomBar(false);
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(false);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(false);
      const margin = resolveIndexScheduleUnsavedMarginBottom(true);

      // Act
      const pass = showBottomBar && aiEnabled && addEnabled && margin === 30;

      // Assert
      expect(pass).assertTrue();
    });

    it('combined: schedule_area_instance_should_cover_default_callbacks_and_prop_sync', 0, () => {
      // Arrange
      const page = new IndexScheduleArea(undefined, {} as LocalStorage) as Object as IndexScheduleAreaPrivateTest;
      const event = buildScheduleEvent(1);
      const grouped: IndexScheduleGroupTest[] = [{
        dayOffset: 0,
        actualDateMs: 1,
        dateHeader: 'Day 1',
        events: [event]
      }];
      const initVm = new IndexScheduleVmPlaceholderTest() as Object;
      const nextVm = new IndexScheduleVmPlaceholderTest() as Object;
      const initTimelineTheme: IndexScheduleThemeTest = {
        pageBg: '#101010',
        textPrimary: '#202020'
      };
      const initUnsavedTheme: IndexScheduleThemeTest = {
        primary: '#303030',
        divider: '#404040'
      };
      const nextGrouped: IndexScheduleGroupTest[] = [{
        dayOffset: 1,
        actualDateMs: 2,
        dateHeader: 'Day 2',
        events: [buildScheduleEvent(2)]
      }];
      const nextTimelineTheme: IndexScheduleThemeTest = {
        pageBg: '#AAAAAA',
        textPrimary: '#BBBBBB'
      };
      const nextUnsavedTheme: IndexScheduleThemeTest = {
        primary: '#CCCCCC',
        divider: '#DDDDDD'
      };
      let callCount = 0;
      const initParams: IndexScheduleAreaParamsTest = {
        vm: initVm,
        groupedEvents: grouped,
        allEvents: [event],
        isArchived: true,
        isCompanionMode: true,
        showWeather: true,
        isPageRefreshing: true,
        gapsCount: 3,
        hasUnsavedChanges: true,
        timelineTheme: initTimelineTheme,
        unsavedTheme: initUnsavedTheme,
        onIsDayCollapsed: (dayOffset: number) => dayOffset === 0,
        onToggleDay: (_dayOffset: number) => { callCount += 1; },
        onRefresh: () => { callCount += 1; },
        onOpenEditDialog: (_item: EventEntity) => { callCount += 1; },
        onOpenTimeEditDialog: (_item: EventEntity) => { callCount += 1; },
        onGapFound: (_item: EventEntity) => { callCount += 1; },
        onResolveConflictAction: (_item: EventEntity, _strategy: string, _gapMinutes: number) => { callCount += 1; },
        onConfirmMoveToBacklog: (_item: EventEntity) => { callCount += 1; },
        onConfirmDeleteEvent: (_item: EventEntity) => { callCount += 1; },
        onOpenGapOptimize: () => { callCount += 1; },
        onFilter: () => { callCount += 1; },
        onAi: () => { callCount += 1; },
        onAdd: () => { callCount += 1; },
        onUndo: () => { callCount += 1; },
        onSave: () => { callCount += 1; }
      };
      const nextEvent = nextGrouped[0].events[0];
      const nextParams: IndexScheduleAreaParamsTest = {
        vm: nextVm,
        groupedEvents: nextGrouped,
        allEvents: [nextEvent],
        isArchived: false,
        isCompanionMode: false,
        showWeather: false,
        isPageRefreshing: false,
        gapsCount: 0,
        hasUnsavedChanges: false,
        timelineTheme: nextTimelineTheme,
        unsavedTheme: nextUnsavedTheme
      };

      // Act
      const defaultCollapsed = page.onIsDayCollapsed(3);
      page.onToggleDay(3);
      page.onRefresh();
      page.onOpenEditDialog(event);
      page.onOpenTimeEditDialog(event);
      page.onGapFound(event);
      page.onResolveConflictAction(event, 'smart', 12);
      page.onConfirmMoveToBacklog(event);
      page.onConfirmDeleteEvent(event);
      page.onOpenGapOptimize();
      page.onFilter();
      page.onAi();
      page.onAdd();
      page.onUndo();
      page.onSave();
      page.setInitiallyProvidedValue(initParams);
      const collapsedAfterInit = page.onIsDayCollapsed(0);
      page.onToggleDay(0);
      page.onRefresh();
      page.onOpenEditDialog(event);
      page.onOpenTimeEditDialog(event);
      page.onGapFound(event);
      page.onResolveConflictAction(event, 'delay', 18);
      page.onConfirmMoveToBacklog(event);
      page.onConfirmDeleteEvent(event);
      page.onOpenGapOptimize();
      page.onFilter();
      page.onAi();
      page.onAdd();
      page.onUndo();
      page.onSave();
      page.updateStateVars(nextParams);
      const collapsedAfterUpdate = page.onIsDayCollapsed(0);

      // Assert
      expect(defaultCollapsed).assertFalse();
      expect(collapsedAfterInit).assertTrue();
      expect(collapsedAfterUpdate).assertTrue();
      expect(callCount).assertEqual(14);
      expect(page.groupedEvents.length).assertEqual(1);
      expect(page.groupedEvents[0].dayOffset).assertEqual(1);
      expect(page.allEvents[0].id).assertEqual(2);
      expect(page.isArchived).assertFalse();
      expect(page.isCompanionMode).assertFalse();
      expect(page.showWeather).assertFalse();
      expect(page.isPageRefreshing).assertFalse();
      expect(page.gapsCount).assertEqual(0);
      expect(page.hasUnsavedChanges).assertFalse();
      expect(page.timelineTheme.pageBg).assertEqual('#AAAAAA');
      expect(page.unsavedTheme.primary).assertEqual('#CCCCCC');
      expect(!!page.vm).assertTrue();
    });

    it('combined: schedule_area_initial_render_should_cover_timeline_bottom_bar_and_unsaved_bar', 0, () => {
      // Arrange
      const page = new IndexScheduleArea(undefined, {} as LocalStorage) as Object as IndexScheduleAreaPrivateTest;
      const event = buildScheduleEvent(11);
      const grouped: IndexScheduleGroupTest[] = [{
        dayOffset: 0,
        actualDateMs: 100,
        dateHeader: 'Day 1',
        events: [event]
      }];
      let threw = false;

      // Act
      page.vm = new IndexScheduleVmPlaceholderTest() as Object;
      page.groupedEvents = grouped;
      page.allEvents = [event];
      page.isArchived = false;
      page.isCompanionMode = false;
      page.showWeather = true;
      page.isPageRefreshing = false;
      page.gapsCount = 2;
      page.hasUnsavedChanges = true;
      page.onIsDayCollapsed = (_dayOffset: number) => false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: schedule_area_initial_render_should_cover_companion_mode_without_bottom_bar', 0, () => {
      // Arrange
      const page = new IndexScheduleArea(undefined, {} as LocalStorage) as Object as IndexScheduleAreaPrivateTest;
      let threw = false;

      // Act
      page.vm = new IndexScheduleVmPlaceholderTest() as Object;
      page.groupedEvents = [];
      page.allEvents = [];
      page.isArchived = true;
      page.isCompanionMode = true;
      page.showWeather = false;
      page.isPageRefreshing = false;
      page.gapsCount = 0;
      page.hasUnsavedChanges = false;
      page.onIsDayCollapsed = (_dayOffset: number) => true;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}

