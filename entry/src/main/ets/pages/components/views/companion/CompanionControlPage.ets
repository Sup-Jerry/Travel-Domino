import { EventEntity } from '../../../../model/entity/EventEntity';
import { WeatherSuggestion } from '../../../../domain/services/WeatherModels';
import { CompanionContext } from '../../../../viewmodel/TimelineViewModel';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';
import { CompanionBottomActionBar } from '../BottomNavBar';
import { CompanionControlTopBar } from './CompanionControlTopBar';
import { CompanionExecutionWeatherCard } from './CompanionExecutionWeatherCard';
import { CompanionFocusedCardHost } from './CompanionFocusedCardHost';
import { CompanionTimelineSection } from './CompanionTimelineSection';
import {
  CompanionDisplayFilterState,
  canCompanionEndFocused,
  canCompanionStartFocused,
  getCompanionEventState,
  getCompanionEventStateLabel,
  getCompanionFilterLabel,
  getCompanionMainCardTimeText,
  getCompanionPlannedRange,
  getCompanionRuntimeDescription,
  getCompanionStateCoreColor,
  getCompanionStateTagBackgroundColor,
  getCompanionTimelineSupplement,
  getCompanionWeatherScoreSummary
} from './CompanionDisplayHelper';
import {
  CompanionCardPhase,
  getCompanionCardOpacity,
  getCompanionCardScale,
  getCompanionCardTranslateX
} from './CompanionAnimationHelper';

export function shouldShowCompanionWeatherCard(isWeatherFeatureEnabled: boolean): boolean {
  return isWeatherFeatureEnabled;
}

export function getCompanionControlCurrentEventId(currentEvent: EventEntity | null): number {
  return currentEvent ? currentEvent.id : -1;
}

export function resolveCompanionControlCardTranslateX(
  isCardSwitching: boolean,
  cardSwitchProgress: number,
  phase: CompanionCardPhase
): number {
  return getCompanionCardTranslateX(isCardSwitching, cardSwitchProgress, phase);
}

export function resolveCompanionControlCardOpacity(
  isCardSwitching: boolean,
  cardSwitchProgress: number,
  phase: CompanionCardPhase
): number {
  return getCompanionCardOpacity(isCardSwitching, cardSwitchProgress, phase);
}

export function resolveCompanionControlCardScale(
  isCardSwitching: boolean,
  cardSwitchProgress: number,
  phase: CompanionCardPhase
): number {
  return getCompanionCardScale(isCardSwitching, cardSwitchProgress, phase);
}

function noopCompanionControlVoid(): void {}

function noopCompanionControlVisible(_visible: boolean): void {}

function noopCompanionControlSuggestion(_item: WeatherSuggestion): void {}

function noopCompanionControlSuggestionId(_suggestionId: string): void {}

function noopCompanionControlEvent(_event: EventEntity): void {}

function noopCompanionControlTimelineTap(_event: EventEntity, _index: number): void {}

function noopCompanionControlTimelineScroll(_start: number, _end: number, _center: number): void {}

type CompanionControlVoidCallback = () => void;
type CompanionControlVisibleCallback = (visible: boolean) => void;
type CompanionControlSuggestionCallback = (item: WeatherSuggestion) => void;
type CompanionControlSuggestionIdCallback = (suggestionId: string) => void;
type CompanionControlEventCallback = (event: EventEntity) => void;
type CompanionControlAsyncVoidCallback = () => Promise<void> | void;
type CompanionControlAsyncEventCallback = (event: EventEntity) => Promise<void> | void;
type CompanionControlTimelineTapCallback = (event: EventEntity, index: number) => void;
type CompanionControlTimelineScrollCallback = (start: number, end: number, center: number) => void;

@Component
export struct CompanionControlPage {
  @Prop context: CompanionContext = {
    runtimeState: 'IDLE',
    currentEvent: null,
    nextEvent: null,
    hint: null,
    actions: {
      canStart: false,
      canPause: false,
      canResume: false,
      canEnd: false,
      canSkip: false,
      canNavigate: false,
      canViewDetail: false
    }
  };
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @Prop companionFilterState: CompanionDisplayFilterState = 'ALL';

  @Prop isWeatherFeatureEnabled: boolean = false;
  @Prop weatherExpanded: boolean = false;
  @Prop showWeatherScorePopup: boolean = false;
  @Prop showWeatherHintPopup: boolean = false;
  @Prop showWeatherSuggestionPopup: boolean = false;
  @Prop weatherSuggestionPopupText: string = '';

  @Prop executionWeatherCollabBadge: string = '';
  @Prop executionWeatherLoading: boolean = false;
  @Prop executionWeatherHint: string = '';
  @Prop executionWeatherLevel: 'INFO' | 'NOTICE' | 'WARNING' = 'INFO';
  @Prop executionWeatherCurrentText: string = '';
  @Prop executionWeatherNextText: string = '';
  @Prop executionWeatherScore: number = -1;
  @Prop executionWeatherCollabSummary: string = '';
  @Prop executionWeatherAppliedSummary: string = '';
  @Prop executionWeatherSuggestions: WeatherSuggestion[] = [];
  @Prop weatherScoreLines: string[] = [];
  @Prop weatherHintLines: string[] = [];

  @Prop canRenderSwitchCards: boolean = false;
  @Prop outgoingEvent: EventEntity | null = null;
  @Prop incomingEvent: EventEntity | null = null;
  @Prop stableEvent: EventEntity | null = null;
  @Prop focusedEventId: number = -1;
  @Prop isCardSwitching: boolean = false;
  @Prop cardSwitchProgress: number = 1;

  @Prop scheduledEvents: EventEntity[] = [];
  @Prop timelineEvents: EventEntity[] = [];
  @Prop focusPosition: number = 0;
  @Prop timelineCount: number = 0;
  timelineScroller: Scroller = new Scroller();

  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onExit: CompanionControlVoidCallback = noopCompanionControlVoid;

  onRefreshWeather: CompanionControlVoidCallback = noopCompanionControlVoid;
  onToggleExpanded: CompanionControlVoidCallback = noopCompanionControlVoid;
  onToggleScorePopup: CompanionControlVoidCallback = noopCompanionControlVoid;
  onToggleHintPopup: CompanionControlVoidCallback = noopCompanionControlVoid;
  onToggleSuggestionPopup: CompanionControlVoidCallback = noopCompanionControlVoid;
  onScorePopupStateChange: CompanionControlVisibleCallback = noopCompanionControlVisible;
  onHintPopupStateChange: CompanionControlVisibleCallback = noopCompanionControlVisible;
  onSuggestionPopupStateChange: CompanionControlVisibleCallback = noopCompanionControlVisible;
  onOpenSuggestionGuide: CompanionControlVoidCallback = noopCompanionControlVoid;
  onOpenSuggestionDetail: CompanionControlSuggestionCallback = noopCompanionControlSuggestion;
  onApplySuggestion: CompanionControlSuggestionCallback = noopCompanionControlSuggestion;
  onLaterSuggestion: CompanionControlSuggestionIdCallback = noopCompanionControlSuggestionId;
  onIgnoreSuggestion: CompanionControlSuggestionIdCallback = noopCompanionControlSuggestionId;

  onNavigate: CompanionControlEventCallback = noopCompanionControlEvent;
  onStartFocused: CompanionControlAsyncVoidCallback = noopCompanionControlVoid;
  onSkipFocused: CompanionControlAsyncVoidCallback = noopCompanionControlVoid;
  onEndFocused: CompanionControlAsyncEventCallback = noopCompanionControlEvent;
  onReopenFocused: CompanionControlAsyncVoidCallback = noopCompanionControlVoid;
  onAdjustFocused: CompanionControlAsyncEventCallback = noopCompanionControlEvent;
  onSkipDisabledTap: CompanionControlVoidCallback = noopCompanionControlVoid;
  onEnterImmersive: CompanionControlVoidCallback = noopCompanionControlVoid;

  onTimelineItemTap: CompanionControlTimelineTapCallback = noopCompanionControlTimelineTap;
  onTimelineScrollIndex: CompanionControlTimelineScrollCallback = noopCompanionControlTimelineScroll;
  onTimelineScrollStop: CompanionControlVoidCallback = noopCompanionControlVoid;

  onHistory: CompanionControlVoidCallback = noopCompanionControlVoid;
  onImmersive: CompanionControlVoidCallback = noopCompanionControlVoid;
  onSearch: CompanionControlVoidCallback = noopCompanionControlVoid;
  onFilter: CompanionControlVoidCallback = noopCompanionControlVoid;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private getCardTranslateX(phase: CompanionCardPhase): number {
    return resolveCompanionControlCardTranslateX(this.isCardSwitching, this.cardSwitchProgress, phase);
  }

  private getCardOpacity(phase: CompanionCardPhase): number {
    return resolveCompanionControlCardOpacity(this.isCardSwitching, this.cardSwitchProgress, phase);
  }

  private getCardScale(phase: CompanionCardPhase): number {
    return resolveCompanionControlCardScale(this.isCardSwitching, this.cardSwitchProgress, phase);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 10 }) {
        CompanionControlTopBar({
          safeTopInset: this.safeTopInset,
          runtimeDescription: getCompanionRuntimeDescription(this.context, Date.now()),
          onExit: this.onExit
        });

        if (shouldShowCompanionWeatherCard(this.isWeatherFeatureEnabled)) {
          CompanionExecutionWeatherCard({
            weatherExpanded: this.weatherExpanded,
            showWeatherScorePopup: this.showWeatherScorePopup,
            showWeatherHintPopup: this.showWeatherHintPopup,
            showWeatherSuggestionPopup: this.showWeatherSuggestionPopup,
            weatherSuggestionPopupText: this.weatherSuggestionPopupText,
            weatherScoreSummary: getCompanionWeatherScoreSummary(this.executionWeatherScore),
            weatherScoreLines: this.weatherScoreLines,
            weatherHintLines: this.weatherHintLines,
            executionWeatherCollabBadge: this.executionWeatherCollabBadge,
            executionWeatherLoading: this.executionWeatherLoading,
            executionWeatherHint: this.executionWeatherHint,
            executionWeatherLevel: this.executionWeatherLevel,
            executionWeatherCurrentText: this.executionWeatherCurrentText,
            executionWeatherNextText: this.executionWeatherNextText,
            executionWeatherScore: this.executionWeatherScore,
            executionWeatherCollabSummary: this.executionWeatherCollabSummary,
            executionWeatherAppliedSummary: this.executionWeatherAppliedSummary,
            executionWeatherSuggestions: this.executionWeatherSuggestions,
            onRefreshWeather: this.onRefreshWeather,
            onToggleExpanded: this.onToggleExpanded,
            onToggleScorePopup: this.onToggleScorePopup,
            onToggleHintPopup: this.onToggleHintPopup,
            onToggleSuggestionPopup: this.onToggleSuggestionPopup,
            onScorePopupStateChange: this.onScorePopupStateChange,
            onHintPopupStateChange: this.onHintPopupStateChange,
            onSuggestionPopupStateChange: this.onSuggestionPopupStateChange,
            onOpenSuggestionGuide: this.onOpenSuggestionGuide,
            onOpenSuggestionDetail: this.onOpenSuggestionDetail,
            onApplySuggestion: this.onApplySuggestion,
            onLaterSuggestion: this.onLaterSuggestion,
            onIgnoreSuggestion: this.onIgnoreSuggestion
          });
        }

        CompanionFocusedCardHost({
          canRenderSwitchCards: this.canRenderSwitchCards,
          outgoingEvent: this.outgoingEvent,
          incomingEvent: this.incomingEvent,
          stableEvent: this.stableEvent,
          runtimeState: this.context.runtimeState,
          currentEventId: getCompanionControlCurrentEventId(this.context.currentEvent),
          getEventStateLabel: getCompanionEventStateLabel,
          getStateTagTextColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getStateTagBackgroundColor: getCompanionStateTagBackgroundColor,
          getStateBorderColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getMainCardTimeText: getCompanionMainCardTimeText,
          getPlannedRange: getCompanionPlannedRange,
          getEventState: getCompanionEventState,
          canStartFocused: (event: EventEntity) => canCompanionStartFocused(event, this.scheduledEvents),
          canEndFocused: (event: EventEntity) => canCompanionEndFocused(event, this.context),
          getCardTranslateX: (phase: CompanionCardPhase) => this.getCardTranslateX(phase),
          getCardOpacity: (phase: CompanionCardPhase) => this.getCardOpacity(phase),
          getCardScale: (phase: CompanionCardPhase) => this.getCardScale(phase),
          onNavigate: this.onNavigate,
          onStart: async (_event: EventEntity) => {
            await this.onStartFocused();
          },
          onSkip: async (_event: EventEntity) => {
            await this.onSkipFocused();
          },
          onEnd: this.onEndFocused,
          onReopen: async (_event: EventEntity) => {
            await this.onReopenFocused();
          },
          onAdjust: this.onAdjustFocused,
          onSkipDisabledTap: this.onSkipDisabledTap,
          onEnterImmersive: this.onEnterImmersive
        });

        CompanionTimelineSection({
          focusedEventId: this.focusedEventId,
          filterLabel: getCompanionFilterLabel(this.companionFilterState),
          focusPosition: this.focusPosition,
          timelineCount: this.timelineCount,
          events: this.timelineEvents,
          timelineScroller: this.timelineScroller,
          getStateDotColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getEventStateLabel: getCompanionEventStateLabel,
          getStateTagTextColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getStateTagBackgroundColor: getCompanionStateTagBackgroundColor,
          getStateBorderColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getTimelineSupplement: getCompanionTimelineSupplement,
          onItemTap: this.onTimelineItemTap,
          onScrollIndex: this.onTimelineScrollIndex,
          onScrollStop: this.onTimelineScrollStop
        });
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, bottom: this.safeBottomInset + 90 })
      .backgroundColor(this.getThemePalette().companionBg);

      CompanionBottomActionBar({
        onHistory: this.onHistory,
        onImmersive: this.onImmersive,
        onSearch: this.onSearch,
        onFilter: this.onFilter
      })
        .zIndex(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}

