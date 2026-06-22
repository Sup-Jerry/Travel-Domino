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
  buildTimelineViewProps(): Object;
  buildBottomBarProps(): Object;
  buildUnsavedActionBarProps(): Object;
  setInitiallyProvidedValue(params: IndexScheduleAreaParamsTest): void;
  updateStateVars(params: IndexScheduleAreaParamsTest): void;
  initialRender(): void;
}

interface IndexScheduleTimelineViewPropsTest {
  groupedEvents: IndexScheduleGroupTest[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onRefresh: () => void;
  onMoveUp: (item: EventEntity) => void;
  onMoveDown: (item: EventEntity) => void;
  onMainContentClick: (item: EventEntity) => void;
  onTimeClick: (item: EventEntity) => void;
  onTravelModeChange: (item: EventEntity, mode: number) => void;
  onManualTravelInput: (item: EventEntity, minutes: number) => void;
  onCommuteChange: (item: EventEntity, minutes: number) => void;
  onConflictAction: (item: EventEntity, strategy: string, gapMinutes: number) => void;
  onMoveToBacklog: (item: EventEntity) => void;
  onDeleteEvent: (item: EventEntity) => void;
  onOpenGapOptimize: () => void;
}

interface IndexScheduleBottomBarPropsTest {
  aiEnabled: boolean;
  addEnabled: boolean;
  onFilter: () => void;
  onAi: () => void;
  onAdd: () => void;
}

interface IndexScheduleUnsavedPropsTest {
  isVisible: boolean;
  marginBottom: number;
  onUndo: () => void;
  onSave: () => void;
}

function buildScheduleEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `schedule_event_${id}`;
  return event;
}

class IndexScheduleVmPlaceholderTest {
  label: string = '';
  events: EventEntity[] = [];
  moveEvent(_index: number, _direction: string): void {}
  updateTravelMode(_item: EventEntity, _mode: number): void {}
  updateManualCommute(_item: EventEntity, _minutes: number): void {}
  updateCommute(_index: number, _minutes: number): void {}
  getSortedGaps(): EventEntity[] {
    return [];
  }
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

    it('boundary: schedule_helper_matrix_should_disable_actions_but_keep_margin_in_normal_archived_mode', 0, () => {
      // Arrange
      const isArchived = true;
      const isCompanionMode = false;

      // Act
      const showBottomBar = shouldShowIndexScheduleBottomBar(isCompanionMode);
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(isArchived);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(isArchived);
      const margin = resolveIndexScheduleUnsavedMarginBottom(isCompanionMode);

      // Assert
      expect(showBottomBar).assertTrue();
      expect(aiEnabled).assertFalse();
      expect(addEnabled).assertFalse();
      expect(margin).assertEqual(96);
    });

    it('combined: schedule_helper_matrix_should_hide_bottom_bar_but_keep_actions_computable_in_companion_mode', 0, () => {
      // Arrange
      const isArchived = false;
      const isCompanionMode = true;

      // Act
      const showBottomBar = shouldShowIndexScheduleBottomBar(isCompanionMode);
      const aiEnabled = resolveIndexScheduleBottomBarAiEnabled(isArchived);
      const addEnabled = resolveIndexScheduleBottomBarAddEnabled(isArchived);
      const margin = resolveIndexScheduleUnsavedMarginBottom(isCompanionMode);

      // Assert
      expect(showBottomBar).assertFalse();
      expect(aiEnabled).assertTrue();
      expect(addEnabled).assertTrue();
      expect(margin).assertEqual(30);
    });

    it('combined: schedule_area_prop_builders_should_cover_timeline_bottom_bar_and_unsaved_callbacks', 0, () => {
      // Arrange
      const page = new IndexScheduleArea(undefined, {} as LocalStorage) as Object as IndexScheduleAreaPrivateTest;
      const event = buildScheduleEvent(20);
      let callCount = 0;
      const vm = new IndexScheduleVmPlaceholderTest();
      vm.events = [event];
      page.vm = vm as Object;
      page.groupedEvents = [{
        dayOffset: 3,
        actualDateMs: 33,
        dateHeader: 'Day 4',
        events: [event]
      }];
      page.allEvents = [event];
      page.isArchived = false;
      page.isCompanionMode = true;
      page.showWeather = true;
      page.isPageRefreshing = true;
      page.gapsCount = 4;
      page.hasUnsavedChanges = true;
      page.onIsDayCollapsed = (dayOffset: number) => dayOffset === 3;
      page.onToggleDay = (_dayOffset: number) => { callCount += 1; };
      page.onRefresh = () => { callCount += 1; };
      page.onOpenEditDialog = (_item: EventEntity) => { callCount += 1; };
      page.onOpenTimeEditDialog = (_item: EventEntity) => { callCount += 1; };
      page.onGapFound = (_item: EventEntity) => { callCount += 1; };
      page.onResolveConflictAction = (_item: EventEntity, _strategy: string, _gapMinutes: number) => { callCount += 1; };
      page.onConfirmMoveToBacklog = (_item: EventEntity) => { callCount += 1; };
      page.onConfirmDeleteEvent = (_item: EventEntity) => { callCount += 1; };
      page.onOpenGapOptimize = () => { callCount += 1; };
      page.onFilter = () => { callCount += 1; };
      page.onAi = () => { callCount += 1; };
      page.onAdd = () => { callCount += 1; };
      page.onUndo = () => { callCount += 1; };
      page.onSave = () => { callCount += 1; };

      // Act
      const timelineProps = page.buildTimelineViewProps() as IndexScheduleTimelineViewPropsTest;
      const bottomBarProps = page.buildBottomBarProps() as IndexScheduleBottomBarPropsTest;
      const unsavedProps = page.buildUnsavedActionBarProps() as IndexScheduleUnsavedPropsTest;
      const collapsed = timelineProps.onIsDayCollapsed(3);
      timelineProps.onToggleDay(3);
      timelineProps.onRefresh();
      timelineProps.onMoveUp(event);
      timelineProps.onMoveDown(event);
      timelineProps.onMainContentClick(event);
      timelineProps.onTimeClick(event);
      timelineProps.onTravelModeChange(event, 2);
      timelineProps.onManualTravelInput(event, 15);
      timelineProps.onCommuteChange(event, 25);
      timelineProps.onConflictAction(event, 'delay', 18);
      timelineProps.onMoveToBacklog(event);
      timelineProps.onDeleteEvent(event);
      timelineProps.onOpenGapOptimize();
      bottomBarProps.onFilter();
      bottomBarProps.onAi();
      bottomBarProps.onAdd();
      unsavedProps.onUndo();
      unsavedProps.onSave();

      // Assert
      expect(timelineProps.groupedEvents.length).assertEqual(1);
      expect(timelineProps.allEvents.length).assertEqual(1);
      expect(timelineProps.isArchived).assertFalse();
      expect(timelineProps.isCompanionMode).assertTrue();
      expect(timelineProps.showWeather).assertTrue();
      expect(timelineProps.isPageRefreshing).assertTrue();
      expect(timelineProps.gapsCount).assertEqual(4);
      expect(collapsed).assertTrue();
      expect(bottomBarProps.aiEnabled).assertTrue();
      expect(bottomBarProps.addEnabled).assertTrue();
      expect(unsavedProps.isVisible).assertTrue();
      expect(unsavedProps.marginBottom).assertEqual(30);
      expect(callCount).assertEqual(13);
    });
  });
}

