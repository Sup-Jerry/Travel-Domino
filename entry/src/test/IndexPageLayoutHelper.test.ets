import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import {
  buildIndexPageHintLines,
  buildIndexPageScoreLines,
  buildIndexPageWeatherSuggestionText,
  IndexPageLayout,
  resolveIndexPageGapsCount,
  shouldShowIndexPageWeatherHint
} from '../main/ets/pages/index/IndexPageLayout';

interface IndexPageThemePaletteTest {
  pageBg?: string;
  primary?: string;
  textPrimary?: string;
}

interface IndexPageLayoutParamsTest {
  vm?: Object;
  planTitle?: string;
  strategyMode?: number;
  currentStrategyExplanation?: string;
  isCompanionMode?: boolean;
  hasManualPlanningWeatherRefresh?: boolean;
  showPlanningWeatherHintPopup?: boolean;
  showPlanningWeatherScorePopup?: boolean;
  backlogExpanded?: boolean;
  isPageRefreshing?: boolean;
  hasUnsavedChanges?: boolean;
  themePalette?: IndexPageThemePaletteTest;
  companionOverlayZIndex?: number;
  onBack?: () => void;
  onOpenSettings?: () => void;
  onEnterCompanion?: () => void;
  onRefreshWeather?: () => void;
  onToggleHint?: () => void;
  onToggleScore?: () => void;
  onHintPopupVisibleChange?: (visible: boolean) => void;
  onScorePopupVisibleChange?: (visible: boolean) => void;
  onToggleBacklogExpand?: () => void;
  onMoveToSchedule?: (item: Object) => void;
  onMoveAllToSchedule?: () => void;
  onIsDayCollapsed?: (dayOffset: number) => boolean;
  onToggleDay?: (dayOffset: number) => void;
  onScheduleRefresh?: () => void;
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

interface IndexPageLayoutPrivateTest {
  vm: Object;
  planTitle: string;
  strategyMode: number;
  currentStrategyExplanation: string;
  isCompanionMode: boolean;
  hasManualPlanningWeatherRefresh: boolean;
  showPlanningWeatherHintPopup: boolean;
  showPlanningWeatherScorePopup: boolean;
  backlogExpanded: boolean;
  isPageRefreshing: boolean;
  hasUnsavedChanges: boolean;
  themePalette: IndexPageThemePaletteTest;
  companionOverlayZIndex: number;
  onBack: () => void;
  onOpenSettings: () => void;
  onEnterCompanion: () => void;
  onRefreshWeather: () => void;
  onToggleHint: () => void;
  onToggleScore: () => void;
  onHintPopupVisibleChange: (visible: boolean) => void;
  onScorePopupVisibleChange: (visible: boolean) => void;
  onToggleBacklogExpand: () => void;
  onMoveToSchedule: (item: Object) => void;
  onMoveAllToSchedule: () => void;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onScheduleRefresh: () => void;
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
  buildTopAreaProps(): Object;
  buildScheduleAreaProps(): Object;
  buildCompanionOverlayProps(): Object;
  setInitiallyProvidedValue(params: IndexPageLayoutParamsTest): void;
  updateStateVars(params: IndexPageLayoutParamsTest): void;
  initialRender(): void;
}

interface IndexPageTopAreaPropsTest {
  planTitle: string;
  strategyMode: number;
  currentStrategyExplanation: string;
  isCompanionMode: boolean;
  isArchived: boolean;
  weatherFeatureEnabled: boolean;
  weatherLoading: boolean;
  weatherHintVisible: boolean;
  weatherSuggestionText: string;
  weatherRouteScore: number;
  events: EventEntity[];
  backlogExpanded: boolean;
  onBack: () => void;
  onOpenSettings: () => void;
  onEnterCompanion: () => void;
  onRefreshWeather: () => void;
  onToggleHint: () => void;
  onToggleScore: () => void;
  onHintPopupVisibleChange: (visible: boolean) => void;
  onScorePopupVisibleChange: (visible: boolean) => void;
  onToggleBacklogExpand: () => void;
  onMoveToSchedule: (item: Object) => void;
  onMoveAllToSchedule: () => void;
}

interface IndexPageScheduleAreaPropsTest {
  vm: Object;
  groupedEvents: Object[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  hasUnsavedChanges: boolean;
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
}

interface IndexPageCompanionOverlayPropsTest {
  vm: Object;
  isVisible: boolean;
  overlayZIndex: number;
}

interface IndexPageGroupedEventPlaceholderTest {
  dayOffset: number;
}

function buildLayoutEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `layout_event_${id}`;
  return event;
}

class IndexPageLayoutVmPlaceholderTest {
  label: string = '';
  isArchived: boolean = false;
  weatherLoading: boolean = false;
  weatherPlanningHint: string = '';
  weatherCollabLabel: string = '';
  weatherCollabSummary: string = '';
  weatherStrategyHint: string = '';
  weatherRouteScore: number = 0;
  events: EventEntity[] = [];
  groupedEvents: Object[] = [];
  gapsCount: number = 0;

  isWeatherFeatureEnabled(): boolean {
    return true;
  }

  buildPlanningWeatherHintExplanation(): string {
    return 'hint_a\nhint_b';
  }

  buildWeatherScoreExplanation(_score: number): string {
    return 'score_a\nscore_b';
  }

  getSortedGaps(): EventEntity[] {
    const list: EventEntity[] = [];
    for (let i = 0; i < this.gapsCount; i++) {
      list.push(buildLayoutEvent(i + 100));
    }
    return list;
  }
}

export default function indexPageLayoutHelperTest() {
  describe('unit_test_case_generator_autofill_IndexPageLayoutHelper', () => {
    it('normal: page_weather_hint_should_show_when_all_conditions_match', 0, () => {
      // Arrange
      const weatherFeatureEnabled = true;
      const hasManualPlanningWeatherRefresh = true;
      const weatherPlanningHint = 'hint';

      // Act
      const show = shouldShowIndexPageWeatherHint(
        weatherFeatureEnabled,
        hasManualPlanningWeatherRefresh,
        weatherPlanningHint
      );

      // Assert
      expect(show).assertTrue();
    });

    it('boundary: page_weather_hint_should_hide_when_hint_text_empty', 0, () => {
      // Arrange
      const weatherFeatureEnabled = true;
      const hasManualPlanningWeatherRefresh = true;
      const weatherPlanningHint = '';

      // Act
      const show = shouldShowIndexPageWeatherHint(
        weatherFeatureEnabled,
        hasManualPlanningWeatherRefresh,
        weatherPlanningHint
      );

      // Assert
      expect(show).assertFalse();
    });

    it('invalid: page_weather_hint_should_hide_when_feature_disabled', 0, () => {
      // Arrange
      const weatherFeatureEnabled = false;

      // Act
      const show = shouldShowIndexPageWeatherHint(weatherFeatureEnabled, true, 'hint');

      // Assert
      expect(show).assertFalse();
    });

    it('conflict: page_weather_hint_should_hide_when_manual_refresh_not_triggered', 0, () => {
      // Arrange
      const hasManualPlanningWeatherRefresh = false;

      // Act
      const show = shouldShowIndexPageWeatherHint(true, hasManualPlanningWeatherRefresh, 'hint');

      // Assert
      expect(show).assertFalse();
    });

    it('regression: page_gaps_count_should_keep_identity_mapping', 0, () => {
      // Arrange
      const gapsCount = 3;

      // Act
      const actual = resolveIndexPageGapsCount(gapsCount);

      // Assert
      expect(actual).assertEqual(3);
    });

    it('combined: page_layout_helper_matrix_should_cover_hint_and_gaps_path', 0, () => {
      // Arrange
      const showHint = shouldShowIndexPageWeatherHint(true, true, 'ok');
      const hideHint = shouldShowIndexPageWeatherHint(true, false, 'ok');
      const gaps = resolveIndexPageGapsCount(5);

      // Act
      const pass = showHint && !hideHint && gaps === 5;

      // Assert
      expect(pass).assertTrue();
    });

    it('combined: page_layout_instance_should_cover_suggestion_lines_callbacks_and_prop_sync', 0, () => {
      // Arrange
      const page = new IndexPageLayout(undefined, {} as LocalStorage) as Object as IndexPageLayoutPrivateTest;
      const event = buildLayoutEvent(1);
      const planItem = buildLayoutEvent(9) as Object;
      const initVm = new IndexPageLayoutVmPlaceholderTest() as Object;
      const nextVm = new IndexPageLayoutVmPlaceholderTest() as Object;
      const initThemePalette: IndexPageThemePaletteTest = {
        pageBg: '#111111',
        primary: '#222222',
        textPrimary: '#333333'
      };
      const nextThemePalette: IndexPageThemePaletteTest = {
        pageBg: '#AAAAAA',
        primary: '#BBBBBB',
        textPrimary: '#CCCCCC'
      };
      let callCount = 0;
      let hintVisible = false;
      let scoreVisible = false;
      const initParams: IndexPageLayoutParamsTest = {
        vm: initVm,
        planTitle: 'trip_a',
        strategyMode: 2,
        currentStrategyExplanation: 'desc_a',
        isCompanionMode: true,
        hasManualPlanningWeatherRefresh: true,
        showPlanningWeatherHintPopup: true,
        showPlanningWeatherScorePopup: false,
        backlogExpanded: true,
        isPageRefreshing: true,
        hasUnsavedChanges: true,
        themePalette: initThemePalette,
        companionOverlayZIndex: 18,
        onBack: () => { callCount += 1; },
        onOpenSettings: () => { callCount += 1; },
        onEnterCompanion: () => { callCount += 1; },
        onRefreshWeather: () => { callCount += 1; },
        onToggleHint: () => { callCount += 1; },
        onToggleScore: () => { callCount += 1; },
        onHintPopupVisibleChange: (visible: boolean) => {
          hintVisible = visible;
          callCount += 1;
        },
        onScorePopupVisibleChange: (visible: boolean) => {
          scoreVisible = visible;
          callCount += 1;
        },
        onToggleBacklogExpand: () => { callCount += 1; },
        onMoveToSchedule: (_item: Object) => { callCount += 1; },
        onMoveAllToSchedule: () => { callCount += 1; },
        onIsDayCollapsed: (dayOffset: number) => dayOffset === 2,
        onToggleDay: (_dayOffset: number) => { callCount += 1; },
        onScheduleRefresh: () => { callCount += 1; },
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
      const nextParams: IndexPageLayoutParamsTest = {
        vm: nextVm,
        planTitle: 'trip_b',
        strategyMode: 4,
        currentStrategyExplanation: 'desc_b',
        isCompanionMode: false,
        hasManualPlanningWeatherRefresh: false,
        showPlanningWeatherHintPopup: false,
        showPlanningWeatherScorePopup: true,
        backlogExpanded: false,
        isPageRefreshing: false,
        hasUnsavedChanges: false,
        themePalette: nextThemePalette,
        companionOverlayZIndex: 28
      };

      // Act
      const defaultCollapsed = page.onIsDayCollapsed(1);
      page.onBack();
      page.onOpenSettings();
      page.onEnterCompanion();
      page.onRefreshWeather();
      page.onToggleHint();
      page.onToggleScore();
      page.onHintPopupVisibleChange(false);
      page.onScorePopupVisibleChange(false);
      page.onToggleBacklogExpand();
      page.onMoveToSchedule(planItem);
      page.onMoveAllToSchedule();
      page.onToggleDay(1);
      page.onScheduleRefresh();
      page.onOpenEditDialog(event);
      page.onOpenTimeEditDialog(event);
      page.onGapFound(event);
      page.onResolveConflictAction(event, 'smart', 15);
      page.onConfirmMoveToBacklog(event);
      page.onConfirmDeleteEvent(event);
      page.onOpenGapOptimize();
      page.onFilter();
      page.onAi();
      page.onAdd();
      page.onUndo();
      page.onSave();
      const suggestionText = buildIndexPageWeatherSuggestionText('协作', '带伞', '多云', '改室内');
      const hintLines = buildIndexPageHintLines('a\nb');
      const scoreLines = buildIndexPageScoreLines('x\ny');
      page.setInitiallyProvidedValue(initParams);
      page.onBack();
      page.onOpenSettings();
      page.onEnterCompanion();
      page.onRefreshWeather();
      page.onToggleHint();
      page.onToggleScore();
      page.onHintPopupVisibleChange(true);
      page.onScorePopupVisibleChange(false);
      page.onToggleBacklogExpand();
      page.onMoveToSchedule(planItem);
      page.onMoveAllToSchedule();
      const collapsedAfterInit = page.onIsDayCollapsed(2);
      page.onToggleDay(2);
      page.onScheduleRefresh();
      page.onOpenEditDialog(event);
      page.onOpenTimeEditDialog(event);
      page.onGapFound(event);
      page.onResolveConflictAction(event, 'delay', 30);
      page.onConfirmMoveToBacklog(event);
      page.onConfirmDeleteEvent(event);
      page.onOpenGapOptimize();
      page.onFilter();
      page.onAi();
      page.onAdd();
      page.onUndo();
      page.onSave();
      page.updateStateVars(nextParams);
      const collapsedAfterUpdate = page.onIsDayCollapsed(2);

      // Assert
      expect(defaultCollapsed).assertFalse();
      expect(!!page.vm).assertTrue();
      expect(suggestionText.includes('带伞')).assertTrue();
      expect(suggestionText.includes('协作')).assertTrue();
      expect(suggestionText.includes('改室内')).assertTrue();
      expect(hintLines.length).assertEqual(2);
      expect(hintLines[1]).assertEqual('b');
      expect(scoreLines.length).assertEqual(2);
      expect(scoreLines[0]).assertEqual('x');
      expect(collapsedAfterInit).assertTrue();
      expect(collapsedAfterUpdate).assertTrue();
      expect(hintVisible).assertTrue();
      expect(scoreVisible).assertFalse();
      expect(callCount).assertEqual(25);
      expect(page.planTitle).assertEqual('trip_b');
      expect(page.strategyMode).assertEqual(4);
      expect(page.currentStrategyExplanation).assertEqual('desc_b');
      expect(page.isCompanionMode).assertFalse();
      expect(page.hasManualPlanningWeatherRefresh).assertFalse();
      expect(page.showPlanningWeatherHintPopup).assertFalse();
      expect(page.showPlanningWeatherScorePopup).assertTrue();
      expect(page.backlogExpanded).assertFalse();
      expect(page.isPageRefreshing).assertFalse();
      expect(page.hasUnsavedChanges).assertFalse();
      expect(page.themePalette.pageBg).assertEqual('#AAAAAA');
      expect(page.themePalette.primary).assertEqual('#BBBBBB');
      expect(page.companionOverlayZIndex).assertEqual(28);
    });

    it('normal: page_layout_initial_render_should_support_planning_hint_branch', 0, () => {
      // Arrange
      const page = new IndexPageLayout(undefined, {} as LocalStorage) as Object as IndexPageLayoutPrivateTest;
      const vm = new IndexPageLayoutVmPlaceholderTest() as Object as IndexPageLayoutVmPlaceholderTest;
      vm.weatherPlanningHint = 'weather_hint';
      vm.weatherCollabLabel = 'collab';
      vm.weatherCollabSummary = 'summary';
      vm.weatherStrategyHint = 'strategy';
      vm.weatherRouteScore = 88;
      vm.events = [buildLayoutEvent(1)];
      vm.groupedEvents = [];
      vm.gapsCount = 2;
      page.setInitiallyProvidedValue({
        vm: vm as Object,
        planTitle: 'trip_render',
        strategyMode: 1,
        currentStrategyExplanation: 'desc_render',
        isCompanionMode: false,
        hasManualPlanningWeatherRefresh: true,
        showPlanningWeatherHintPopup: true,
        showPlanningWeatherScorePopup: false,
        backlogExpanded: true,
        isPageRefreshing: false,
        hasUnsavedChanges: true
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: page_layout_initial_render_should_support_companion_overlay_branch', 0, () => {
      // Arrange
      const page = new IndexPageLayout(undefined, {} as LocalStorage) as Object as IndexPageLayoutPrivateTest;
      const vm = new IndexPageLayoutVmPlaceholderTest() as Object as IndexPageLayoutVmPlaceholderTest;
      vm.events = [];
      vm.groupedEvents = [];
      vm.gapsCount = 0;
      page.setInitiallyProvidedValue({
        vm: vm as Object,
        planTitle: 'trip_overlay',
        strategyMode: 0,
        currentStrategyExplanation: '',
        isCompanionMode: true,
        hasManualPlanningWeatherRefresh: false,
        showPlanningWeatherHintPopup: false,
        showPlanningWeatherScorePopup: false,
        backlogExpanded: false,
        isPageRefreshing: true,
        hasUnsavedChanges: false,
        companionOverlayZIndex: 99
      });

      // Act
      let threw = false;
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: page_hint_and_score_lines_should_keep_single_empty_and_single_line_outputs', 0, () => {
      // Arrange
      const emptyText = '';
      const singleLine = 'only_one';

      // Act
      const hintLines = buildIndexPageHintLines(emptyText);
      const scoreLines = buildIndexPageScoreLines(singleLine);

      // Assert
      expect(hintLines.length).assertEqual(1);
      expect(hintLines[0]).assertEqual('');
      expect(scoreLines.length).assertEqual(1);
      expect(scoreLines[0]).assertEqual('only_one');
    });

    it('invalid: page_gaps_count_should_keep_negative_value_without_clamping', 0, () => {
      // Arrange
      const gapsCount = -3;

      // Act
      const actual = resolveIndexPageGapsCount(gapsCount);

      // Assert
      expect(actual).assertEqual(-3);
    });

    it('combined: page_weather_suggestion_should_include_planning_hint_without_optional_segments', 0, () => {
      // Arrange
      const collabLabel = '';
      const planningHint = '建议带伞';
      const collabSummary = '';
      const strategyHint = '';

      // Act
      const text = buildIndexPageWeatherSuggestionText(collabLabel, planningHint, collabSummary, strategyHint);

      // Assert
      expect(text.indexOf('建议带伞') >= 0).assertTrue();
      expect(text.indexOf('天气建议') >= 0).assertTrue();
      expect(text.indexOf('策略联动') < 0).assertTrue();
    });
    it('regression: page_weather_suggestion_should_include_strategy_text_when_provided', 0, () => {
      // Arrange
      const collabLabel = '鍗忎綔';
      const planningHint = '甯︿紴';
      const collabSummary = '';
      const strategyHint = '鍏堝幓鍗楁箹';

      // Act
      const text = buildIndexPageWeatherSuggestionText(collabLabel, planningHint, collabSummary, strategyHint);

      // Assert
      expect(text.indexOf('鍗忎綔') >= 0).assertTrue();
      expect(text.indexOf('甯︿紴') >= 0).assertTrue();
      expect(text.indexOf('鍏堝幓鍗楁箹') >= 0).assertTrue();
    });

    it('combined: page_layout_defaults_should_keep_noop_callbacks_and_default_theme', 0, () => {
      // Arrange
      const page = new IndexPageLayout(undefined, {} as LocalStorage) as Object as IndexPageLayoutPrivateTest;
      const event = buildLayoutEvent(41);

      // Act
      page.onBack();
      page.onOpenSettings();
      page.onEnterCompanion();
      page.onRefreshWeather();
      page.onToggleHint();
      page.onToggleScore();
      page.onHintPopupVisibleChange(true);
      page.onScorePopupVisibleChange(false);
      page.onToggleBacklogExpand();
      page.onMoveToSchedule(event as Object);
      page.onMoveAllToSchedule();
      page.onToggleDay(3);
      page.onScheduleRefresh();
      page.onOpenEditDialog(event);
      page.onOpenTimeEditDialog(event);
      page.onGapFound(event);
      page.onResolveConflictAction(event, 'advance', 20);
      page.onConfirmMoveToBacklog(event);
      page.onConfirmDeleteEvent(event);
      page.onOpenGapOptimize();
      page.onFilter();
      page.onAi();
      page.onAdd();
      page.onUndo();
      page.onSave();
      const showHint = shouldShowIndexPageWeatherHint(true, true, 'hint');

      // Assert
      expect(showHint).assertTrue();
      expect(page.planTitle).assertEqual('');
      expect(page.strategyMode).assertEqual(0);
      expect(page.themePalette.primary).assertEqual('#2F7DFF');
      expect(page.companionOverlayZIndex).assertEqual(10);
    });

    it('regression: page_weather_hint_should_keep_whitespace_hint_visible_when_manual_refresh_is_true', 0, () => {
      // Arrange
      const weatherFeatureEnabled = true;
      const hasManualPlanningWeatherRefresh = true;
      const weatherPlanningHint = '   ';

      // Act
      const show = shouldShowIndexPageWeatherHint(
        weatherFeatureEnabled,
        hasManualPlanningWeatherRefresh,
        weatherPlanningHint
      );

      // Assert
      expect(show).assertTrue();
    });

    it('combined: page_layout_should_keep_default_day_collapsed_callback_false_and_gaps_identity_consistent', 0, () => {
      // Arrange
      const page = new IndexPageLayout(undefined, {} as LocalStorage) as Object as IndexPageLayoutPrivateTest;

      // Act
      const collapsed = page.onIsDayCollapsed(99);
      const zeroGaps = resolveIndexPageGapsCount(0);
      const hintLines = buildIndexPageHintLines('only_hint');
      const scoreLines = buildIndexPageScoreLines('');

      // Assert
      expect(collapsed).assertFalse();
      expect(zeroGaps).assertEqual(0);
      expect(hintLines.length).assertEqual(1);
      expect(hintLines[0]).assertEqual('only_hint');
      expect(scoreLines.length).assertEqual(1);
      expect(scoreLines[0]).assertEqual('');
    });

    it('combined: page_layout_prop_builders_should_cover_top_schedule_and_overlay_callbacks', 0, () => {
      // Arrange
      const page = new IndexPageLayout(undefined, {} as LocalStorage) as Object as IndexPageLayoutPrivateTest;
      const event = buildLayoutEvent(31);
      const vm = new IndexPageLayoutVmPlaceholderTest();
      vm.isArchived = true;
      vm.weatherLoading = true;
      vm.weatherPlanningHint = 'bring coat';
      vm.weatherCollabLabel = 'label';
      vm.weatherCollabSummary = 'summary';
      vm.weatherStrategyHint = 'strategy';
      vm.weatherRouteScore = 72;
      vm.events = [event];
      const groupedEvents: IndexPageGroupedEventPlaceholderTest[] = [{ dayOffset: 1 }];
      vm.groupedEvents = groupedEvents as Object[];
      vm.gapsCount = 2;
      let callCount = 0;
      let lastHintVisible = false;
      let lastScoreVisible = false;
      page.vm = vm as Object;
      page.planTitle = 'layout_trip';
      page.strategyMode = 5;
      page.currentStrategyExplanation = 'layout_explain';
      page.isCompanionMode = true;
      page.hasManualPlanningWeatherRefresh = true;
      page.showPlanningWeatherHintPopup = true;
      page.showPlanningWeatherScorePopup = false;
      page.backlogExpanded = true;
      page.isPageRefreshing = true;
      page.hasUnsavedChanges = true;
      page.companionOverlayZIndex = 23;
      page.onBack = () => { callCount += 1; };
      page.onOpenSettings = () => { callCount += 1; };
      page.onEnterCompanion = () => { callCount += 1; };
      page.onRefreshWeather = () => { callCount += 1; };
      page.onToggleHint = () => { callCount += 1; };
      page.onToggleScore = () => { callCount += 1; };
      page.onHintPopupVisibleChange = (visible: boolean) => {
        lastHintVisible = visible;
        callCount += 1;
      };
      page.onScorePopupVisibleChange = (visible: boolean) => {
        lastScoreVisible = visible;
        callCount += 1;
      };
      page.onToggleBacklogExpand = () => { callCount += 1; };
      page.onMoveToSchedule = (_item: Object) => { callCount += 1; };
      page.onMoveAllToSchedule = () => { callCount += 1; };
      page.onToggleDay = (_dayOffset: number) => { callCount += 1; };
      page.onScheduleRefresh = () => { callCount += 1; };
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
      const topAreaProps = page.buildTopAreaProps() as IndexPageTopAreaPropsTest;
      const scheduleAreaProps = page.buildScheduleAreaProps() as IndexPageScheduleAreaPropsTest;
      const overlayProps = page.buildCompanionOverlayProps() as IndexPageCompanionOverlayPropsTest;
      const collapsed = scheduleAreaProps.onIsDayCollapsed(9);
      topAreaProps.onBack();
      topAreaProps.onOpenSettings();
      topAreaProps.onEnterCompanion();
      topAreaProps.onRefreshWeather();
      topAreaProps.onToggleHint();
      topAreaProps.onToggleScore();
      topAreaProps.onHintPopupVisibleChange(false);
      topAreaProps.onScorePopupVisibleChange(true);
      topAreaProps.onToggleBacklogExpand();
      topAreaProps.onMoveToSchedule(event as Object);
      topAreaProps.onMoveAllToSchedule();
      scheduleAreaProps.onToggleDay(1);
      scheduleAreaProps.onRefresh();
      scheduleAreaProps.onOpenEditDialog(event);
      scheduleAreaProps.onOpenTimeEditDialog(event);
      scheduleAreaProps.onGapFound(event);
      scheduleAreaProps.onResolveConflictAction(event, 'compress', 12);
      scheduleAreaProps.onConfirmMoveToBacklog(event);
      scheduleAreaProps.onConfirmDeleteEvent(event);
      scheduleAreaProps.onOpenGapOptimize();
      scheduleAreaProps.onFilter();
      scheduleAreaProps.onAi();
      scheduleAreaProps.onAdd();
      scheduleAreaProps.onUndo();
      scheduleAreaProps.onSave();

      // Assert
      expect(topAreaProps.planTitle).assertEqual('layout_trip');
      expect(topAreaProps.strategyMode).assertEqual(5);
      expect(topAreaProps.currentStrategyExplanation).assertEqual('layout_explain');
      expect(topAreaProps.isCompanionMode).assertTrue();
      expect(topAreaProps.isArchived).assertTrue();
      expect(topAreaProps.weatherFeatureEnabled).assertTrue();
      expect(topAreaProps.weatherLoading).assertTrue();
      expect(topAreaProps.weatherHintVisible).assertTrue();
      expect(topAreaProps.weatherSuggestionText.length > 0).assertTrue();
      expect(topAreaProps.weatherRouteScore).assertEqual(72);
      expect(topAreaProps.events.length).assertEqual(1);
      expect(topAreaProps.backlogExpanded).assertTrue();
      expect(!!scheduleAreaProps.vm).assertTrue();
      expect(scheduleAreaProps.groupedEvents.length).assertEqual(1);
      expect(scheduleAreaProps.allEvents.length).assertEqual(1);
      expect(scheduleAreaProps.isArchived).assertTrue();
      expect(scheduleAreaProps.isCompanionMode).assertTrue();
      expect(scheduleAreaProps.showWeather).assertTrue();
      expect(scheduleAreaProps.isPageRefreshing).assertTrue();
      expect(scheduleAreaProps.gapsCount).assertEqual(2);
      expect(scheduleAreaProps.hasUnsavedChanges).assertTrue();
      expect(collapsed).assertFalse();
      expect(!!overlayProps.vm).assertTrue();
      expect(overlayProps.isVisible).assertTrue();
      expect(overlayProps.overlayZIndex).assertEqual(23);
      expect(lastHintVisible).assertFalse();
      expect(lastScoreVisible).assertTrue();
      expect(callCount).assertEqual(25);
    });
  });
}

