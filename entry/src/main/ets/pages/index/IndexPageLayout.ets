import { ThemeCenter, ThemePalette } from '../../common/utils/ThemeCenter';
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexHelpers } from './IndexHelpers';
import { IndexCompanionOverlay } from './IndexCompanionOverlay';
import { IndexScheduleArea } from './IndexScheduleArea';
import { IndexTopArea } from './IndexTopArea';
import { IndexLayoutCallbacksHelper, IndexPageLayoutCallbacks } from './IndexLayoutCallbacksHelper';
import { NavigationHelper } from '../../common/utils/NavigationHelper';

@Component
export struct IndexPageLayout {
  @Prop vm: TimelineViewModel = new TimelineViewModel();
  @Prop planTitle: string = '';
  @Prop strategyMode: number = 0;
  @Prop currentStrategyExplanation: string = '';
  @Prop isCompanionMode: boolean = false;
  @Prop hasManualPlanningWeatherRefresh: boolean = false;
  @Prop showPlanningWeatherHintPopup: boolean = false;
  @Prop showPlanningWeatherScorePopup: boolean = false;
  @Prop backlogExpanded: boolean = false;
  @Prop isPageRefreshing: boolean = false;
  @Prop hasUnsavedChanges: boolean = false;
  @Prop themePalette: ThemePalette = {
    pageBg: '#F6F8FC',
    cardBg: '#FFFFFF',
    cardBgSoft: '#F5F7FA',
    companionBg: '#EEF3FA',
    companionCardBg: '#FFFFFF',
    immersiveBg: '#EAF0FA',
    statusPending: '#6F97D8',
    statusSkipped: '#C79A53',
    statusCompleted: '#68A57B',
    textPrimary: '#1F2937',
    textSecondary: '#5B6B82',
    textTertiary: '#8FA1B8',
    primary: '#2F7DFF',
    border: '#DCE5F2',
    divider: '#E7EDF5',
    success: '#2D7C5C',
    warning: '#C58A2A',
    danger: '#B95B72',
    toolboxBall: '#2C5E9C',
    toolboxBallDisabled: '#7A8A9E'
  };
  @Prop companionOverlayZIndex: number = 10;
  @Prop companionBackRequestToken: number = 0;

  @Prop callbacks: IndexPageLayoutCallbacks = IndexLayoutCallbacksHelper.createEmpty();
  private callbacksCache: IndexPageLayoutCallbacks = IndexLayoutCallbacksHelper.createEmpty();

  private getThemePalette(): ThemePalette {
    return this.themePalette ?? ThemeCenter.getPalette('light');
  }

  private getVm(): TimelineViewModel {
    return this.vm ?? new TimelineViewModel();
  }

  private getCallbacks(): IndexPageLayoutCallbacks {
    if (this.callbacks) {
      this.callbacksCache = this.callbacks;
      return this.callbacks;
    }
    return this.callbacksCache;
  }

  private getCompanionModeSafe(): boolean {
    if (!this.callbacks) {
      return false;
    }
    return this.isCompanionMode;
  }

  private callBack(): void {
    const callbacks = this.getCallbacks();
    if (callbacks && typeof callbacks.onBack === 'function') {
      callbacks.onBack();
      return;
    }
    void NavigationHelper.backOrFallbackToPlanList(this.getUIContext());
  }

  private callOpenSettings(): void {
    const callbacks = this.getCallbacks();
    if (callbacks && typeof callbacks.onOpenSettings === 'function') {
      callbacks.onOpenSettings();
    }
  }

  private callEnterCompanion(): void {
    const callbacks = this.getCallbacks();
    if (callbacks && typeof callbacks.onEnterCompanion === 'function') {
      callbacks.onEnterCompanion();
    }
  }

  private callAdd(): void {
    const callbacks = this.getCallbacks();
    if (callbacks && typeof callbacks.onAdd === 'function') {
      callbacks.onAdd();
    }
  }

  private isWeatherHintVisible(): boolean {
    return this.getVm().isWeatherFeatureEnabled() && this.hasManualPlanningWeatherRefresh && !!this.getVm().weatherPlanningHint;
  }

  private buildWeatherSuggestionText(): string {
    return IndexHelpers.buildWeatherSuggestionText({
      collabLabel: this.getVm().weatherCollabLabel,
      planningHint: this.getVm().weatherPlanningHint,
      collabSummary: this.getVm().weatherCollabSummary,
      strategyHint: this.getVm().weatherStrategyHint
    });
  }

  private buildHintLines(): string[] {
    return IndexHelpers.splitLines(this.getVm().buildPlanningWeatherHintExplanation());
  }

  private buildScoreLines(): string[] {
    return IndexHelpers.splitLines(this.getVm().buildWeatherScoreExplanation(this.getVm().weatherRouteScore));
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        IndexTopArea({
          planTitle: this.planTitle,
          strategyMode: this.strategyMode,
          currentStrategyExplanation: this.currentStrategyExplanation,
          isCompanionMode: this.getCompanionModeSafe(),
          isArchived: this.getVm().isArchived,
          weatherFeatureEnabled: this.getVm().isWeatherFeatureEnabled(),
          weatherLoading: this.getVm().weatherLoading,
          weatherHintVisible: this.isWeatherHintVisible(),
          weatherSuggestionText: this.buildWeatherSuggestionText(),
          weatherRouteScore: this.getVm().weatherRouteScore,
          hintPopupVisible: this.showPlanningWeatherHintPopup,
          scorePopupVisible: this.showPlanningWeatherScorePopup,
          hintLines: this.buildHintLines(),
          scoreLines: this.buildScoreLines(),
          events: this.getVm().events,
          backlogExpanded: this.backlogExpanded,
          dividerColor: this.getThemePalette().divider,
          toolbarTheme: {
            primary: this.getThemePalette().primary,
            textTertiary: this.getThemePalette().textTertiary,
            cardBgSoft: this.getThemePalette().cardBgSoft,
            textPrimary: this.getThemePalette().textPrimary
          },
          weatherTheme: {
            primary: this.getThemePalette().primary,
            textPrimary: this.getThemePalette().textPrimary,
            cardBgSoft: this.getThemePalette().cardBgSoft
          },
          onBack: () => this.callBack(),
          onOpenSettings: () => this.callOpenSettings(),
          onEnterCompanion: () => this.callEnterCompanion(),
          onRefreshWeather: () => this.getCallbacks().onRefreshWeather(),
          onToggleHint: () => this.getCallbacks().onToggleHint(),
          onToggleScore: () => this.getCallbacks().onToggleScore(),
          onHintPopupVisibleChange: (visible: boolean) => this.getCallbacks().onHintPopupVisibleChange(visible),
          onScorePopupVisibleChange: (visible: boolean) => this.getCallbacks().onScorePopupVisibleChange(visible),
          onToggleBacklogExpand: () => this.getCallbacks().onToggleBacklogExpand(),
          onMoveToSchedule: (item: TravelPlanItem) => this.getCallbacks().onMoveToSchedule(item),
          onMoveAllToSchedule: () => this.getCallbacks().onMoveAllToSchedule()
        })

        IndexScheduleArea({
          vm: this.getVm(),
          groupedEvents: this.getVm().groupedEvents,
          allEvents: this.getVm().events,
          isArchived: this.getVm().isArchived,
          isCompanionMode: this.getCompanionModeSafe(),
          showWeather: this.getVm().isWeatherFeatureEnabled(),
          isPageRefreshing: this.isPageRefreshing,
          gapsCount: this.getVm().getSortedGaps().length,
          hasUnsavedChanges: this.hasUnsavedChanges,
          timelineTheme: {
            pageBg: this.getThemePalette().pageBg,
            textPrimary: this.getThemePalette().textPrimary,
            textSecondary: this.getThemePalette().textSecondary,
            textTertiary: this.getThemePalette().textTertiary,
            warning: this.getThemePalette().warning
          },
          unsavedTheme: {
            textPrimary: this.getThemePalette().textPrimary,
            textSecondary: this.getThemePalette().textSecondary,
            divider: this.getThemePalette().divider,
            primary: this.getThemePalette().primary,
            cardBg: this.getThemePalette().cardBg
          },
          onIsDayCollapsed: (dayOffset: number) => this.getCallbacks().onIsDayCollapsed(dayOffset),
          onToggleDay: (dayOffset: number) => this.getCallbacks().onToggleDay(dayOffset),
          onRefresh: () => this.getCallbacks().onScheduleRefresh(),
          onOpenEditDialog: (item: EventEntity) => this.getCallbacks().onOpenEditDialog(item),
          onOpenTimeEditDialog: (item: EventEntity) => this.getCallbacks().onOpenTimeEditDialog(item),
          onGapFound: (item: EventEntity) => this.getCallbacks().onGapFound(item),
          onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => {
            this.getCallbacks().onResolveConflictAction(item, strategy, gapMinutes);
          },
          onConfirmMoveToBacklog: (item: EventEntity) => this.getCallbacks().onConfirmMoveToBacklog(item),
          onConfirmDeleteEvent: (item: EventEntity) => this.getCallbacks().onConfirmDeleteEvent(item),
          onOpenGapOptimize: () => this.getCallbacks().onOpenGapOptimize(),
          onFilter: () => this.getCallbacks().onFilter(),
          onAi: () => this.getCallbacks().onAi(),
          onAdd: () => this.callAdd(),
          onUndo: () => this.getCallbacks().onUndo(),
          onSave: () => this.getCallbacks().onSave()
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getThemePalette().pageBg)

      IndexCompanionOverlay({
        vm: this.getVm(),
        isVisible: this.getCompanionModeSafe(),
        overlayZIndex: this.companionOverlayZIndex,
        backRequestToken: this.companionBackRequestToken
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg)
  }
}

