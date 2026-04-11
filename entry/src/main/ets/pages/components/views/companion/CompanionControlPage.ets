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

  onExit: () => void = () => {};

  onRefreshWeather: () => void = () => {};
  onToggleExpanded: () => void = () => {};
  onToggleScorePopup: () => void = () => {};
  onToggleHintPopup: () => void = () => {};
  onToggleSuggestionPopup: () => void = () => {};
  onScorePopupStateChange: (visible: boolean) => void = (_visible: boolean) => {};
  onHintPopupStateChange: (visible: boolean) => void = (_visible: boolean) => {};
  onSuggestionPopupStateChange: (visible: boolean) => void = (_visible: boolean) => {};
  onOpenSuggestionGuide: () => void = () => {};
  onOpenSuggestionDetail: (item: WeatherSuggestion) => void = (_item: WeatherSuggestion) => {};
  onApplySuggestion: (item: WeatherSuggestion) => void = (_item: WeatherSuggestion) => {};
  onLaterSuggestion: (suggestionId: string) => void = (_suggestionId: string) => {};
  onIgnoreSuggestion: (suggestionId: string) => void = (_suggestionId: string) => {};

  onNavigate: (event: EventEntity) => void = (_event: EventEntity) => {};
  onStartFocused: () => Promise<void> | void = () => {};
  onSkipFocused: () => Promise<void> | void = () => {};
  onEndFocused: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onReopenFocused: () => Promise<void> | void = () => {};
  onAdjustFocused: (event: EventEntity) => Promise<void> | void = (_event: EventEntity) => {};
  onSkipDisabledTap: () => void = () => {};
  onEnterImmersive: () => void = () => {};

  onTimelineItemTap: (event: EventEntity, index: number) => void = (_event: EventEntity, _index: number) => {};
  onTimelineScrollIndex: (start: number, end: number, center: number) => void = (_start: number, _end: number, _center: number) => {};
  onTimelineScrollStop: () => void = () => {};

  onHistory: () => void = () => {};
  onImmersive: () => void = () => {};
  onSearch: () => void = () => {};
  onFilter: () => void = () => {};

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private getCardTranslateX(phase: CompanionCardPhase): number {
    return getCompanionCardTranslateX(this.isCardSwitching, this.cardSwitchProgress, phase);
  }

  private getCardOpacity(phase: CompanionCardPhase): number {
    return getCompanionCardOpacity(this.isCardSwitching, this.cardSwitchProgress, phase);
  }

  private getCardScale(phase: CompanionCardPhase): number {
    return getCompanionCardScale(this.isCardSwitching, this.cardSwitchProgress, phase);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column({ space: 10 }) {
        CompanionControlTopBar({
          safeTopInset: this.safeTopInset,
          runtimeDescription: getCompanionRuntimeDescription(this.context, Date.now()),
          onExit: () => {
            this.onExit();
          }
        });

        if (this.isWeatherFeatureEnabled) {
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
            onRefreshWeather: () => {
              this.onRefreshWeather();
            },
            onToggleExpanded: () => {
              this.onToggleExpanded();
            },
            onToggleScorePopup: () => {
              this.onToggleScorePopup();
            },
            onToggleHintPopup: () => {
              this.onToggleHintPopup();
            },
            onToggleSuggestionPopup: () => {
              this.onToggleSuggestionPopup();
            },
            onScorePopupStateChange: (visible: boolean) => {
              this.onScorePopupStateChange(visible);
            },
            onHintPopupStateChange: (visible: boolean) => {
              this.onHintPopupStateChange(visible);
            },
            onSuggestionPopupStateChange: (visible: boolean) => {
              this.onSuggestionPopupStateChange(visible);
            },
            onOpenSuggestionGuide: () => {
              this.onOpenSuggestionGuide();
            },
            onOpenSuggestionDetail: (item: WeatherSuggestion) => {
              this.onOpenSuggestionDetail(item);
            },
            onApplySuggestion: (item: WeatherSuggestion) => {
              this.onApplySuggestion(item);
            },
            onLaterSuggestion: (suggestionId: string) => {
              this.onLaterSuggestion(suggestionId);
            },
            onIgnoreSuggestion: (suggestionId: string) => {
              this.onIgnoreSuggestion(suggestionId);
            }
          });
        }

        CompanionFocusedCardHost({
          canRenderSwitchCards: this.canRenderSwitchCards,
          outgoingEvent: this.outgoingEvent,
          incomingEvent: this.incomingEvent,
          stableEvent: this.stableEvent,
          runtimeState: this.context.runtimeState,
          currentEventId: this.context.currentEvent ? this.context.currentEvent.id : -1,
          getEventStateLabel: (event: EventEntity) => getCompanionEventStateLabel(event),
          getStateTagTextColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getStateTagBackgroundColor: (event: EventEntity) => getCompanionStateTagBackgroundColor(event),
          getStateBorderColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getMainCardTimeText: (event: EventEntity) => getCompanionMainCardTimeText(event),
          getPlannedRange: (event: EventEntity) => getCompanionPlannedRange(event),
          getEventState: (event: EventEntity) => getCompanionEventState(event),
          canStartFocused: (event: EventEntity) => canCompanionStartFocused(event, this.scheduledEvents),
          canEndFocused: (event: EventEntity) => canCompanionEndFocused(event, this.context),
          getCardTranslateX: (phase: CompanionCardPhase) => this.getCardTranslateX(phase),
          getCardOpacity: (phase: CompanionCardPhase) => this.getCardOpacity(phase),
          getCardScale: (phase: CompanionCardPhase) => this.getCardScale(phase),
          onNavigate: (event: EventEntity) => {
            this.onNavigate(event);
          },
          onStart: async (_event: EventEntity) => {
            await this.onStartFocused();
          },
          onSkip: async (_event: EventEntity) => {
            await this.onSkipFocused();
          },
          onEnd: async (event: EventEntity) => {
            await this.onEndFocused(event);
          },
          onReopen: async (_event: EventEntity) => {
            await this.onReopenFocused();
          },
          onAdjust: async (event: EventEntity) => {
            await this.onAdjustFocused(event);
          },
          onSkipDisabledTap: () => {
            this.onSkipDisabledTap();
          },
          onEnterImmersive: () => {
            this.onEnterImmersive();
          }
        });

        CompanionTimelineSection({
          focusedEventId: this.focusedEventId,
          filterLabel: getCompanionFilterLabel(this.companionFilterState),
          focusPosition: this.focusPosition,
          timelineCount: this.timelineCount,
          events: this.timelineEvents,
          timelineScroller: this.timelineScroller,
          getStateDotColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getEventStateLabel: (event: EventEntity) => getCompanionEventStateLabel(event),
          getStateTagTextColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getStateTagBackgroundColor: (event: EventEntity) => getCompanionStateTagBackgroundColor(event),
          getStateBorderColor: (event: EventEntity) => getCompanionStateCoreColor(event, this.getThemePalette()),
          getTimelineSupplement: (event: EventEntity) => getCompanionTimelineSupplement(event),
          onItemTap: (event: EventEntity, index: number) => {
            this.onTimelineItemTap(event, index);
          },
          onScrollIndex: (start: number, end: number, center: number) => {
            this.onTimelineScrollIndex(start, end, center);
          },
          onScrollStop: () => {
            this.onTimelineScrollStop();
          }
        });
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, bottom: this.safeBottomInset + 90 })
      .backgroundColor(this.getThemePalette().companionBg);

      CompanionBottomActionBar({
        onHistory: () => {
          this.onHistory();
        },
        onImmersive: () => {
          this.onImmersive();
        },
        onSearch: () => {
          this.onSearch();
        },
        onFilter: () => {
          this.onFilter();
        }
      })
        .zIndex(20);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}
