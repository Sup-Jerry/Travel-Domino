import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  CompanionControlPage,
  getCompanionControlCurrentEventId,
  resolveCompanionControlCardOpacity,
  resolveCompanionControlCardScale,
  resolveCompanionControlCardTranslateX,
  shouldShowCompanionWeatherCard
} from '../main/ets/pages/components/views/companion/CompanionControlPage';
import { CompanionCardPhase } from '../main/ets/pages/components/views/companion/CompanionAnimationHelper';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompanionContext } from '../main/ets/viewmodel/TimelineViewModel';

interface CompanionControlPagePaletteTest {
  companionBg: Object;
  pageBg: Object;
  primary: Object;
}

interface CompanionControlPageParamsTest {
  context?: CompanionContext;
  safeTopInset?: number;
  safeBottomInset?: number;
  companionFilterState?: string;
  isWeatherFeatureEnabled?: boolean;
  weatherExpanded?: boolean;
  showWeatherScorePopup?: boolean;
  showWeatherHintPopup?: boolean;
  showWeatherSuggestionPopup?: boolean;
  weatherSuggestionPopupText?: string;
  executionWeatherCollabBadge?: string;
  executionWeatherLoading?: boolean;
  executionWeatherHint?: string;
  executionWeatherLevel?: string;
  executionWeatherCurrentText?: string;
  executionWeatherNextText?: string;
  executionWeatherScore?: number;
  executionWeatherCollabSummary?: string;
  executionWeatherAppliedSummary?: string;
  executionWeatherSuggestions?: Object[];
  weatherScoreLines?: string[];
  weatherHintLines?: string[];
  canRenderSwitchCards?: boolean;
  outgoingEvent?: EventEntity | null;
  incomingEvent?: EventEntity | null;
  stableEvent?: EventEntity | null;
  focusedEventId?: number;
  isCardSwitching?: boolean;
  cardSwitchProgress?: number;
  scheduledEvents?: EventEntity[];
  timelineEvents?: EventEntity[];
  focusPosition?: number;
  timelineCount?: number;
}

interface CompanionControlPagePrivateTest {
  context: CompanionContext;
  safeTopInset: number;
  safeBottomInset: number;
  companionFilterState: string;
  isWeatherFeatureEnabled: boolean;
  weatherExpanded: boolean;
  showWeatherScorePopup: boolean;
  showWeatherHintPopup: boolean;
  showWeatherSuggestionPopup: boolean;
  weatherSuggestionPopupText: string;
  executionWeatherCollabBadge: string;
  executionWeatherLoading: boolean;
  executionWeatherHint: string;
  executionWeatherLevel: string;
  executionWeatherCurrentText: string;
  executionWeatherNextText: string;
  executionWeatherScore: number;
  executionWeatherCollabSummary: string;
  executionWeatherAppliedSummary: string;
  executionWeatherSuggestions: Object[];
  weatherScoreLines: string[];
  weatherHintLines: string[];
  canRenderSwitchCards: boolean;
  outgoingEvent: EventEntity | null;
  incomingEvent: EventEntity | null;
  stableEvent: EventEntity | null;
  focusedEventId: number;
  isCardSwitching: boolean;
  cardSwitchProgress: number;
  scheduledEvents: EventEntity[];
  timelineEvents: EventEntity[];
  focusPosition: number;
  timelineCount: number;
  effectiveTheme: string;
  onExit: () => void;
  onRefreshWeather: () => void;
  onToggleExpanded: () => void;
  onToggleScorePopup: () => void;
  onToggleHintPopup: () => void;
  onToggleSuggestionPopup: () => void;
  onScorePopupStateChange: (visible: boolean) => void;
  onHintPopupStateChange: (visible: boolean) => void;
  onSuggestionPopupStateChange: (visible: boolean) => void;
  onOpenSuggestionGuide: () => void;
  onOpenSuggestionDetail: (item: Object) => void;
  onApplySuggestion: (item: Object) => void;
  onLaterSuggestion: (suggestionId: string) => void;
  onIgnoreSuggestion: (suggestionId: string) => void;
  onNavigate: (event: EventEntity) => void;
  onStartFocused: () => void;
  onSkipFocused: () => void;
  onEndFocused: (event: EventEntity) => void;
  onReopenFocused: () => void;
  onAdjustFocused: (event: EventEntity) => void;
  onSkipDisabledTap: () => void;
  onEnterImmersive: () => void;
  onTimelineItemTap: (event: EventEntity, index: number) => void;
  onTimelineScrollIndex: (start: number, end: number, center: number) => void;
  onTimelineScrollStop: () => void;
  onHistory: () => void;
  onImmersive: () => void;
  onSearch: () => void;
  onFilter: () => void;
  setInitiallyProvidedValue(params: CompanionControlPageParamsTest): void;
  updateStateVars(params: CompanionControlPageParamsTest): void;
  getThemePalette(): CompanionControlPagePaletteTest;
  getCardTranslateX(phase: CompanionCardPhase): number;
  getCardOpacity(phase: CompanionCardPhase): number;
  getCardScale(phase: CompanionCardPhase): number;
  initialRender(): void;
}

function buildEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event_${id}`;
  return event;
}

function buildControlContext(runtimeState: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP', current: EventEntity | null): CompanionContext {
  const context = {} as CompanionContext;
  context.runtimeState = runtimeState;
  context.currentEvent = current;
  context.nextEvent = null;
  context.hint = null;
  return context;
}

class CompanionControlSuggestionPlaceholderTest {}

class CompanionControlSuggestionRenderTest {
  suggestionId: string = 'control_weather_s1';
  level: string = 'NOTICE';
  triggerType: string = 'RAIN';
  actionType: string = 'SHIFT_TIME';
  title: string = 'move indoor';
  message: string = 'rain is coming';
  relatedNodeIds: string[] = ['n1'];
  createdAt: number = 1;
  reason: string = 'rain';
  expectedBenefit: string = 'less risk';
  canRollback: boolean = true;
  cooldownKey: string = 'control_weather_s1';
  expiresAt: number = 2;
}

export default function companionControlPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionControlPageHelper', () => {
    it('normal: weather_card_should_follow_feature_flag', 0, () => {
      // Arrange
      const enabled = true;

      // Act
      const visible = shouldShowCompanionWeatherCard(enabled);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: current_event_id_should_return_minus_one_for_null', 0, () => {
      // Arrange
      const currentEvent = null;

      // Act
      const id = getCompanionControlCurrentEventId(currentEvent);

      // Assert
      expect(id).assertEqual(-1);
    });

    it('invalid: weather_card_should_handle_false_flag', 0, () => {
      // Arrange
      const enabled = false;

      // Act
      const visible = shouldShowCompanionWeatherCard(enabled);

      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: current_event_id_should_prefer_event_id_when_present', 0, () => {
      // Arrange
      const event = buildEvent(22);

      // Act
      const id = getCompanionControlCurrentEventId(event);

      // Assert
      expect(id).assertEqual(22);
    });

    it('regression: current_event_id_should_not_depend_on_other_fields', 0, () => {
      // Arrange
      const event = buildEvent(33);
      event.name = '';

      // Act
      const id = getCompanionControlCurrentEventId(event);

      // Assert
      expect(id).assertEqual(33);
    });

    it('combined: control_helper_matrix_should_cover_visible_and_hidden_states', 0, () => {
      // Arrange
      const event = buildEvent(101);

      // Act
      const show = shouldShowCompanionWeatherCard(true);
      const hide = shouldShowCompanionWeatherCard(false);
      const id = getCompanionControlCurrentEventId(event);
      const none = getCompanionControlCurrentEventId(null);

      // Assert
      expect(show).assertTrue();
      expect(hide).assertFalse();
      expect(id).assertEqual(101);
      expect(none).assertEqual(-1);
    });

    it('normal: control_card_translate_should_move_outgoing_left_when_switching', 0, () => {
      // Arrange
      const phase: CompanionCardPhase = 'outgoing';

      // Act
      const x = resolveCompanionControlCardTranslateX(true, 0.5, phase);

      // Assert
      expect(x).assertEqual(-9);
    });

    it('boundary: control_card_opacity_should_keep_one_when_not_switching', 0, () => {
      // Arrange
      const phase: CompanionCardPhase = 'stable';

      // Act
      const opacity = resolveCompanionControlCardOpacity(false, 0.2, phase);

      // Assert
      expect(opacity).assertEqual(1);
    });

    it('regression: td-20260412-control-card-scale-incoming-should-follow-progress', 0, () => {
      // Arrange
      const phase: CompanionCardPhase = 'incoming';

      // Act
      const scale = resolveCompanionControlCardScale(true, 0.5, phase);

      // Assert
      expect(scale).assertEqual(0.996);
    });

    it('boundary: control_card_helpers_should_cover_zero_and_full_progress_edges', 0, () => {
      // Arrange
      const zero = 0;
      const full = 1;

      // Act
      const outgoingStartX = resolveCompanionControlCardTranslateX(true, zero, 'outgoing');
      const outgoingEndX = resolveCompanionControlCardTranslateX(true, full, 'outgoing');
      const incomingStartX = resolveCompanionControlCardTranslateX(true, zero, 'incoming');
      const incomingEndX = resolveCompanionControlCardTranslateX(true, full, 'incoming');
      const outgoingStartOpacity = resolveCompanionControlCardOpacity(true, zero, 'outgoing');
      const outgoingEndOpacity = resolveCompanionControlCardOpacity(true, full, 'outgoing');
      const incomingStartOpacity = resolveCompanionControlCardOpacity(true, zero, 'incoming');
      const incomingEndOpacity = resolveCompanionControlCardOpacity(true, full, 'incoming');
      const outgoingStartScale = resolveCompanionControlCardScale(true, zero, 'outgoing');
      const outgoingEndScale = resolveCompanionControlCardScale(true, full, 'outgoing');
      const incomingStartScale = resolveCompanionControlCardScale(true, zero, 'incoming');
      const incomingEndScale = resolveCompanionControlCardScale(true, full, 'incoming');

      // Assert
      expect(outgoingStartX).assertEqual(0);
      expect(outgoingEndX).assertEqual(-18);
      expect(incomingStartX).assertEqual(18);
      expect(incomingEndX).assertEqual(0);
      expect(outgoingStartOpacity).assertEqual(1);
      expect(outgoingEndOpacity).assertEqual(0);
      expect(incomingStartOpacity).assertEqual(0);
      expect(incomingEndOpacity).assertEqual(1);
      expect(outgoingStartScale).assertEqual(1);
      expect(outgoingEndScale).assertEqual(0.985);
      expect(incomingStartScale).assertEqual(0.992);
      expect(incomingEndScale).assertEqual(1);
    });

    it('combined: control_card_helpers_should_keep_stable_phase_fixed_while_switching', 0, () => {
      // Arrange
      const progressValues: number[] = [0, 0.35, 1];

      // Act
      const translateSum = progressValues
        .map((progress: number) => resolveCompanionControlCardTranslateX(true, progress, 'stable'))
        .reduce((sum: number, value: number) => sum + value, 0);
      const opacitySum = progressValues
        .map((progress: number) => resolveCompanionControlCardOpacity(true, progress, 'stable'))
        .reduce((sum: number, value: number) => sum + value, 0);
      const scaleSum = progressValues
        .map((progress: number) => resolveCompanionControlCardScale(true, progress, 'stable'))
        .reduce((sum: number, value: number) => sum + value, 0);

      // Assert
      expect(translateSum).assertEqual(0);
      expect(opacitySum).assertEqual(3);
      expect(scaleSum).assertEqual(3);
    });

    it('combined: control_page_instance_should_sync_props_callbacks_and_private_card_methods', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      const current = buildEvent(201);
      const outgoing = buildEvent(202);
      const incoming = buildEvent(203);
      const stable = buildEvent(204);
      const suggestion = new CompanionControlSuggestionPlaceholderTest() as Object;
      const initParams: CompanionControlPageParamsTest = {
        context: buildControlContext('READY', current),
        safeTopInset: 8,
        safeBottomInset: 10,
        companionFilterState: 'ALL',
        isWeatherFeatureEnabled: true,
        weatherExpanded: true,
        showWeatherScorePopup: true,
        showWeatherHintPopup: false,
        showWeatherSuggestionPopup: true,
        weatherSuggestionPopupText: 'line1\nline2',
        executionWeatherCollabBadge: 'badge',
        executionWeatherLoading: false,
        executionWeatherHint: 'rain',
        executionWeatherLevel: 'NOTICE',
        executionWeatherCurrentText: 'current',
        executionWeatherNextText: 'next',
        executionWeatherScore: 5,
        executionWeatherCollabSummary: 'collab',
        executionWeatherAppliedSummary: 'applied',
        executionWeatherSuggestions: [suggestion],
        weatherScoreLines: ['score'],
        weatherHintLines: ['hint'],
        canRenderSwitchCards: true,
        outgoingEvent: outgoing,
        incomingEvent: incoming,
        stableEvent: stable,
        focusedEventId: outgoing.id,
        isCardSwitching: true,
        cardSwitchProgress: 0.25,
        scheduledEvents: [current, outgoing],
        timelineEvents: [outgoing, incoming],
        focusPosition: 1,
        timelineCount: 2
      };
      const nextParams: CompanionControlPageParamsTest = {
        context: buildControlContext('PAUSED', stable),
        safeTopInset: 18,
        safeBottomInset: 20,
        companionFilterState: 'SKIPPED',
        isWeatherFeatureEnabled: false,
        weatherExpanded: false,
        showWeatherScorePopup: false,
        showWeatherHintPopup: true,
        showWeatherSuggestionPopup: false,
        weatherSuggestionPopupText: 'updated',
        executionWeatherCollabBadge: 'updated_badge',
        executionWeatherLoading: true,
        executionWeatherHint: 'wind',
        executionWeatherLevel: 'WARNING',
        executionWeatherCurrentText: 'updated_current',
        executionWeatherNextText: 'updated_next',
        executionWeatherScore: 8,
        executionWeatherCollabSummary: 'updated_collab',
        executionWeatherAppliedSummary: 'updated_applied',
        executionWeatherSuggestions: [suggestion, suggestion],
        weatherScoreLines: ['a', 'b'],
        weatherHintLines: ['c', 'd'],
        canRenderSwitchCards: false,
        outgoingEvent: stable,
        incomingEvent: null,
        stableEvent: current,
        focusedEventId: current.id,
        isCardSwitching: true,
        cardSwitchProgress: 0.5,
        scheduledEvents: [stable],
        timelineEvents: [current],
        focusPosition: 2,
        timelineCount: 1
      };

      // Act
      page.onExit();
      page.onRefreshWeather();
      page.onToggleExpanded();
      page.onToggleScorePopup();
      page.onToggleHintPopup();
      page.onToggleSuggestionPopup();
      page.onScorePopupStateChange(true);
      page.onHintPopupStateChange(false);
      page.onSuggestionPopupStateChange(true);
      page.onOpenSuggestionGuide();
      page.onOpenSuggestionDetail(suggestion);
      page.onApplySuggestion(suggestion);
      page.onLaterSuggestion('sg_1');
      page.onIgnoreSuggestion('sg_1');
      page.onNavigate(current);
      page.onStartFocused();
      page.onSkipFocused();
      page.onEndFocused(current);
      page.onReopenFocused();
      page.onAdjustFocused(current);
      page.onSkipDisabledTap();
      page.onEnterImmersive();
      page.onTimelineItemTap(current, 0);
      page.onTimelineScrollIndex(0, 1, 0);
      page.onTimelineScrollStop();
      page.onHistory();
      page.onImmersive();
      page.onSearch();
      page.onFilter();
      page.setInitiallyProvidedValue(initParams);
      page.updateStateVars(initParams);
      const initRuntimeState = page.context.runtimeState;
      const initSafeTopInset = page.safeTopInset;
      const initSafeBottomInset = page.safeBottomInset;
      const initFilterState = page.companionFilterState;
      const initWeatherExpanded = page.weatherExpanded;
      const initSuggestionText = page.weatherSuggestionPopupText;
      const initScoreLineCount = page.weatherScoreLines.length;
      const initHintLineCount = page.weatherHintLines.length;
      const initOutgoingId = page.outgoingEvent?.id ?? -1;
      const initIncomingId = page.incomingEvent?.id ?? -1;
      const initStableId = page.stableEvent?.id ?? -1;
      const initFocusPosition = page.focusPosition;
      const initTimelineCount = page.timelineCount;
      page.updateStateVars(nextParams);
      page.effectiveTheme = 'dark';
      const palette = page.getThemePalette();
      const translate = page.getCardTranslateX('incoming');
      const opacity = page.getCardOpacity('incoming');
      const scale = page.getCardScale('incoming');

      // Assert
      expect(page.context.runtimeState).assertEqual('PAUSED');
      expect(page.safeTopInset).assertEqual(18);
      expect(page.safeBottomInset).assertEqual(20);
      expect(page.companionFilterState).assertEqual('SKIPPED');
      expect(page.isWeatherFeatureEnabled).assertFalse();
      expect(page.weatherExpanded).assertFalse();
      expect(page.executionWeatherLoading).assertTrue();
      expect(page.executionWeatherLevel).assertEqual('WARNING');
      expect(page.executionWeatherSuggestions.length).assertEqual(2);
      expect(page.canRenderSwitchCards).assertFalse();
      expect(page.outgoingEvent?.id).assertEqual(stable.id);
      expect(page.stableEvent?.id).assertEqual(current.id);
      expect(page.focusedEventId).assertEqual(current.id);
      expect(page.scheduledEvents.length).assertEqual(1);
      expect(page.timelineEvents.length).assertEqual(1);
      expect(page.focusPosition).assertEqual(2);
      expect(page.timelineCount).assertEqual(1);
      expect(initRuntimeState).assertEqual('READY');
      expect(initSafeTopInset).assertEqual(8);
      expect(initSafeBottomInset).assertEqual(10);
      expect(initFilterState).assertEqual('ALL');
      expect(initWeatherExpanded).assertTrue();
      expect(initSuggestionText).assertEqual('line1\nline2');
      expect(initScoreLineCount).assertEqual(1);
      expect(initHintLineCount).assertEqual(1);
      expect(initOutgoingId).assertEqual(outgoing.id);
      expect(initIncomingId).assertEqual(incoming.id);
      expect(initStableId).assertEqual(stable.id);
      expect(initFocusPosition).assertEqual(1);
      expect(initTimelineCount).assertEqual(2);
      expect(translate).assertEqual(resolveCompanionControlCardTranslateX(true, 0.5, 'incoming'));
      expect(opacity).assertEqual(resolveCompanionControlCardOpacity(true, 0.5, 'incoming'));
      expect(scale).assertEqual(resolveCompanionControlCardScale(true, 0.5, 'incoming'));
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette('dark').companionBg);
      expect(palette.pageBg).assertEqual(ThemeCenter.getPalette('dark').pageBg);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
    });

    it('combined: control_page_accessors_should_cover_remaining_weather_and_timeline_state', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      const current = buildEvent(301);
      const incoming = buildEvent(302);
      const stable = buildEvent(303);
      const suggestion = new CompanionControlSuggestionPlaceholderTest() as Object;
      const replacement = new CompanionControlSuggestionPlaceholderTest() as Object;
      const nextContext = buildControlContext('ACTIVE', current);

      // Act
      page.showWeatherScorePopup = true;
      page.showWeatherHintPopup = true;
      page.showWeatherSuggestionPopup = true;
      page.weatherSuggestionPopupText = 'popup_text';
      page.executionWeatherCollabBadge = 'badge_text';
      page.executionWeatherHint = 'storm';
      page.executionWeatherCurrentText = 'current_weather';
      page.executionWeatherNextText = 'next_weather';
      page.executionWeatherScore = 9;
      page.executionWeatherCollabSummary = 'collab_summary';
      page.executionWeatherAppliedSummary = 'applied_summary';
      page.executionWeatherSuggestions = [suggestion];
      page.weatherScoreLines = ['line_a', 'line_b'];
      page.weatherHintLines = ['hint_a'];
      page.incomingEvent = incoming;
      page.cardSwitchProgress = 0.75;
      page.context = nextContext;
      page.safeTopInset = 30;
      page.safeBottomInset = 40;
      page.companionFilterState = 'ACTIVE';
      page.isWeatherFeatureEnabled = true;
      page.weatherExpanded = true;
      page.executionWeatherLoading = true;
      page.executionWeatherLevel = 'NOTICE';
      page.canRenderSwitchCards = true;
      page.outgoingEvent = current;
      page.stableEvent = stable;
      page.focusedEventId = stable.id;
      page.isCardSwitching = false;
      page.scheduledEvents = [current, stable];
      page.timelineEvents = [incoming, stable];
      page.focusPosition = 4;
      page.timelineCount = 6;
      page.executionWeatherSuggestions = [suggestion, replacement];

      const showScore = page.showWeatherScorePopup;
      const showHint = page.showWeatherHintPopup;
      const showSuggestion = page.showWeatherSuggestionPopup;
      const popupText = page.weatherSuggestionPopupText;
      const badge = page.executionWeatherCollabBadge;
      const hint = page.executionWeatherHint;
      const currentText = page.executionWeatherCurrentText;
      const nextText = page.executionWeatherNextText;
      const score = page.executionWeatherScore;
      const collabSummary = page.executionWeatherCollabSummary;
      const appliedSummary = page.executionWeatherAppliedSummary;
      const suggestionCount = page.executionWeatherSuggestions.length;
      const scoreLineCount = page.weatherScoreLines.length;
      const hintLineCount = page.weatherHintLines.length;
      const incomingId = page.incomingEvent?.id ?? -1;
      const contextState = page.context.runtimeState;
      const safeTopInset = page.safeTopInset;
      const safeBottomInset = page.safeBottomInset;
      const filterState = page.companionFilterState;
      const featureEnabled = page.isWeatherFeatureEnabled;
      const expanded = page.weatherExpanded;
      const loading = page.executionWeatherLoading;
      const level = page.executionWeatherLevel;
      const canRenderSwitchCards = page.canRenderSwitchCards;
      const outgoingId = page.outgoingEvent?.id ?? -1;
      const stableId = page.stableEvent?.id ?? -1;
      const focusedEventId = page.focusedEventId;
      const isCardSwitching = page.isCardSwitching;
      const progress = page.cardSwitchProgress;
      const scheduledCount = page.scheduledEvents.length;
      const timelineCount = page.timelineEvents.length;
      const focusPosition = page.focusPosition;
      const totalTimelineCount = page.timelineCount;

      // Assert
      expect(showScore).assertTrue();
      expect(showHint).assertTrue();
      expect(showSuggestion).assertTrue();
      expect(popupText).assertEqual('popup_text');
      expect(badge).assertEqual('badge_text');
      expect(hint).assertEqual('storm');
      expect(currentText).assertEqual('current_weather');
      expect(nextText).assertEqual('next_weather');
      expect(score).assertEqual(9);
      expect(collabSummary).assertEqual('collab_summary');
      expect(appliedSummary).assertEqual('applied_summary');
      expect(suggestionCount).assertEqual(2);
      expect(scoreLineCount).assertEqual(2);
      expect(hintLineCount).assertEqual(1);
      expect(incomingId).assertEqual(incoming.id);
      expect(contextState).assertEqual('ACTIVE');
      expect(safeTopInset).assertEqual(30);
      expect(safeBottomInset).assertEqual(40);
      expect(filterState).assertEqual('ACTIVE');
      expect(featureEnabled).assertTrue();
      expect(expanded).assertTrue();
      expect(loading).assertTrue();
      expect(level).assertEqual('NOTICE');
      expect(canRenderSwitchCards).assertTrue();
      expect(outgoingId).assertEqual(current.id);
      expect(stableId).assertEqual(stable.id);
      expect(focusedEventId).assertEqual(stable.id);
      expect(isCardSwitching).assertFalse();
      expect(progress).assertEqual(0.75);
      expect(scheduledCount).assertEqual(2);
      expect(timelineCount).assertEqual(2);
      expect(focusPosition).assertEqual(4);
      expect(totalTimelineCount).assertEqual(6);
    });

    it('boundary: control_page_empty_param_updates_should_keep_constructor_defaults', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;

      // Act
      page.setInitiallyProvidedValue({});
      page.updateStateVars({});
      const palette = page.getThemePalette();
      const translate = page.getCardTranslateX('stable');
      const opacity = page.getCardOpacity('stable');
      const scale = page.getCardScale('stable');

      // Assert
      expect(page.context.runtimeState).assertEqual('IDLE');
      expect(page.safeTopInset).assertEqual(0);
      expect(page.safeBottomInset).assertEqual(0);
      expect(page.companionFilterState).assertEqual('ALL');
      expect(page.isWeatherFeatureEnabled).assertFalse();
      expect(page.weatherExpanded).assertFalse();
      expect(page.showWeatherScorePopup).assertFalse();
      expect(page.showWeatherHintPopup).assertFalse();
      expect(page.showWeatherSuggestionPopup).assertFalse();
      expect(page.weatherSuggestionPopupText).assertEqual('');
      expect(page.executionWeatherScore).assertEqual(-1);
      expect(page.executionWeatherSuggestions.length).assertEqual(0);
      expect(page.canRenderSwitchCards).assertFalse();
      expect(page.focusedEventId).assertEqual(-1);
      expect(page.isCardSwitching).assertFalse();
      expect(page.cardSwitchProgress).assertEqual(1);
      expect(page.scheduledEvents.length).assertEqual(0);
      expect(page.timelineEvents.length).assertEqual(0);
      expect(page.focusPosition).assertEqual(0);
      expect(page.timelineCount).assertEqual(0);
      expect(translate).assertEqual(0);
      expect(opacity).assertEqual(1);
      expect(scale).assertEqual(1);
      expect(palette.companionBg).assertEqual(ThemeCenter.getPalette(page.effectiveTheme).companionBg);
    });

    it('regression: control_page_initial_render_should_not_throw_with_minimal_ready_state', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      page.context = buildControlContext('READY', buildEvent(401));
      page.isWeatherFeatureEnabled = false;
      page.timelineEvents = [buildEvent(402)];
      page.scheduledEvents = [buildEvent(403)];
      page.focusedEventId = 402;
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('normal: control_page_initial_render_should_cover_weather_switch_and_timeline_branches', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      const current = buildEvent(501);
      const outgoing = buildEvent(502);
      const incoming = buildEvent(503);
      const stable = buildEvent(504);
      const suggestion = new CompanionControlSuggestionRenderTest() as Object;
      page.context = buildControlContext('ACTIVE', current);
      page.safeTopInset = 12;
      page.safeBottomInset = 16;
      page.companionFilterState = 'ACTIVE';
      page.isWeatherFeatureEnabled = true;
      page.weatherExpanded = true;
      page.showWeatherScorePopup = false;
      page.showWeatherHintPopup = false;
      page.showWeatherSuggestionPopup = false;
      page.weatherSuggestionPopupText = 'line1\nline2';
      page.executionWeatherCollabBadge = 'badge';
      page.executionWeatherLoading = false;
      page.executionWeatherHint = 'rain warning';
      page.executionWeatherLevel = 'NOTICE';
      page.executionWeatherCurrentText = 'sunny';
      page.executionWeatherNextText = 'rain';
      page.executionWeatherScore = 76;
      page.executionWeatherCollabSummary = 'city sync';
      page.executionWeatherAppliedSummary = 'shifted';
      page.executionWeatherSuggestions = [suggestion];
      page.weatherScoreLines = ['score'];
      page.weatherHintLines = ['hint'];
      page.canRenderSwitchCards = true;
      page.outgoingEvent = outgoing;
      page.incomingEvent = incoming;
      page.stableEvent = stable;
      page.focusedEventId = incoming.id;
      page.isCardSwitching = true;
      page.cardSwitchProgress = 0.4;
      page.scheduledEvents = [current, outgoing, incoming];
      page.timelineEvents = [outgoing, incoming, stable];
      page.focusPosition = 2;
      page.timelineCount = 3;
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.isWeatherFeatureEnabled).assertTrue();
      expect(page.executionWeatherSuggestions.length).assertEqual(1);
    });

    it('boundary: control_page_initial_render_should_cover_hidden_weather_stable_empty_timeline', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      const stable = buildEvent(601);
      page.context = buildControlContext('IDLE', null);
      page.safeTopInset = 0;
      page.safeBottomInset = 0;
      page.companionFilterState = 'ALL';
      page.isWeatherFeatureEnabled = false;
      page.weatherExpanded = false;
      page.canRenderSwitchCards = false;
      page.outgoingEvent = null;
      page.incomingEvent = null;
      page.stableEvent = stable;
      page.focusedEventId = -1;
      page.timelineEvents = [];
      page.scheduledEvents = [];
      page.focusPosition = 0;
      page.timelineCount = 0;
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.isWeatherFeatureEnabled).assertFalse();
      expect(page.timelineEvents.length).assertEqual(0);
    });

    it('combined: control_page_initial_render_should_cover_paused_collapsed_weather_and_bottom_actions', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      const current = buildEvent(701);
      const next = buildEvent(702);
      page.context = buildControlContext('PAUSED', current);
      page.safeTopInset = 20;
      page.safeBottomInset = 24;
      page.companionFilterState = 'SKIPPED';
      page.isWeatherFeatureEnabled = true;
      page.weatherExpanded = false;
      page.showWeatherScorePopup = false;
      page.showWeatherHintPopup = false;
      page.showWeatherSuggestionPopup = false;
      page.executionWeatherLoading = true;
      page.executionWeatherHint = 'wind';
      page.executionWeatherScore = -1;
      page.executionWeatherSuggestions = [];
      page.canRenderSwitchCards = false;
      page.stableEvent = current;
      page.focusedEventId = current.id;
      page.timelineEvents = [current, next];
      page.scheduledEvents = [current, next];
      page.focusPosition = 1;
      page.timelineCount = 2;
      page.effectiveTheme = 'dark';
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.context.runtimeState).assertEqual('PAUSED');
      expect(page.weatherExpanded).assertFalse();
    });

    it('invalid: control_page_initial_render_should_handle_gap_state_without_current_event', 0, () => {
      // Arrange
      const page = new CompanionControlPage(undefined, {} as LocalStorage) as Object as CompanionControlPagePrivateTest;
      const blocked = buildEvent(801);
      page.context = buildControlContext('GAP', null);
      page.safeTopInset = -2;
      page.safeBottomInset = -4;
      page.companionFilterState = 'SKIPPED';
      page.isWeatherFeatureEnabled = true;
      page.weatherExpanded = true;
      page.executionWeatherLevel = 'WARNING';
      page.executionWeatherScore = 0;
      page.canRenderSwitchCards = true;
      page.outgoingEvent = null;
      page.incomingEvent = null;
      page.stableEvent = blocked;
      page.focusedEventId = -1;
      page.timelineEvents = [blocked];
      page.scheduledEvents = [];
      page.focusPosition = 0;
      page.timelineCount = 1;
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(getCompanionControlCurrentEventId(page.context.currentEvent)).assertEqual(-1);
      expect(page.context.runtimeState).assertEqual('GAP');
      expect(page.executionWeatherLevel).assertEqual('WARNING');
      expect(page.timelineEvents.length).assertEqual(1);
    });
  });
}
