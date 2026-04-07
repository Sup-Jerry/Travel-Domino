import { ThemePalette } from '../../common/utils/ThemeCenter';
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexHelpers } from './IndexHelpers';
import { IndexCompanionOverlay } from './IndexCompanionOverlay';
import { IndexScheduleArea } from './IndexScheduleArea';
import { IndexTopArea } from './IndexTopArea';
import { IndexLayoutCallbacksHelper, IndexPageLayoutCallbacks } from './IndexLayoutCallbacksHelper';

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

  private isWeatherHintVisible(): boolean {
    return this.vm.isWeatherFeatureEnabled() && this.hasManualPlanningWeatherRefresh && !!this.vm.weatherPlanningHint;
  }

  private buildWeatherSuggestionText(): string {
    return IndexHelpers.buildWeatherSuggestionText({
      collabLabel: this.vm.weatherCollabLabel,
      planningHint: this.vm.weatherPlanningHint,
      collabSummary: this.vm.weatherCollabSummary,
      strategyHint: this.vm.weatherStrategyHint
    });
  }

  private buildHintLines(): string[] {
    return IndexHelpers.splitLines(this.vm.buildPlanningWeatherHintExplanation());
  }

  private buildScoreLines(): string[] {
    return IndexHelpers.splitLines(this.vm.buildWeatherScoreExplanation(this.vm.weatherRouteScore));
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        IndexTopArea({
          planTitle: this.planTitle,
          strategyMode: this.strategyMode,
          currentStrategyExplanation: this.currentStrategyExplanation,
          isCompanionMode: this.isCompanionMode,
          isArchived: this.vm.isArchived,
          weatherFeatureEnabled: this.vm.isWeatherFeatureEnabled(),
          weatherLoading: this.vm.weatherLoading,
          weatherHintVisible: this.isWeatherHintVisible(),
          weatherSuggestionText: this.buildWeatherSuggestionText(),
          weatherRouteScore: this.vm.weatherRouteScore,
          hintPopupVisible: this.showPlanningWeatherHintPopup,
          scorePopupVisible: this.showPlanningWeatherScorePopup,
          hintLines: this.buildHintLines(),
          scoreLines: this.buildScoreLines(),
          events: this.vm.events,
          backlogExpanded: this.backlogExpanded,
          dividerColor: this.themePalette.divider,
          toolbarTheme: {
            primary: this.themePalette.primary,
            textTertiary: this.themePalette.textTertiary,
            cardBgSoft: this.themePalette.cardBgSoft,
            textPrimary: this.themePalette.textPrimary
          },
          weatherTheme: {
            primary: this.themePalette.primary,
            textPrimary: this.themePalette.textPrimary,
            cardBgSoft: this.themePalette.cardBgSoft
          },
          onBack: () => this.callbacks.onBack(),
          onOpenSettings: () => this.callbacks.onOpenSettings(),
          onEnterCompanion: () => this.callbacks.onEnterCompanion(),
          onRefreshWeather: () => this.callbacks.onRefreshWeather(),
          onToggleHint: () => this.callbacks.onToggleHint(),
          onToggleScore: () => this.callbacks.onToggleScore(),
          onHintPopupVisibleChange: (visible: boolean) => this.callbacks.onHintPopupVisibleChange(visible),
          onScorePopupVisibleChange: (visible: boolean) => this.callbacks.onScorePopupVisibleChange(visible),
          onToggleBacklogExpand: () => this.callbacks.onToggleBacklogExpand(),
          onMoveToSchedule: (item: TravelPlanItem) => this.callbacks.onMoveToSchedule(item),
          onMoveAllToSchedule: () => this.callbacks.onMoveAllToSchedule()
        })

        IndexScheduleArea({
          vm: this.vm,
          groupedEvents: this.vm.groupedEvents,
          allEvents: this.vm.events,
          isArchived: this.vm.isArchived,
          isCompanionMode: this.isCompanionMode,
          showWeather: this.vm.isWeatherFeatureEnabled(),
          isPageRefreshing: this.isPageRefreshing,
          gapsCount: this.vm.getSortedGaps().length,
          hasUnsavedChanges: this.hasUnsavedChanges,
          timelineTheme: {
            pageBg: this.themePalette.pageBg,
            textPrimary: this.themePalette.textPrimary,
            textSecondary: this.themePalette.textSecondary,
            textTertiary: this.themePalette.textTertiary,
            warning: this.themePalette.warning
          },
          unsavedTheme: {
            textPrimary: this.themePalette.textPrimary,
            textSecondary: this.themePalette.textSecondary,
            divider: this.themePalette.divider,
            primary: this.themePalette.primary,
            cardBg: this.themePalette.cardBg
          },
          onIsDayCollapsed: (dayOffset: number) => this.callbacks.onIsDayCollapsed(dayOffset),
          onToggleDay: (dayOffset: number) => this.callbacks.onToggleDay(dayOffset),
          onRefresh: () => this.callbacks.onScheduleRefresh(),
          onOpenEditDialog: (item: EventEntity) => this.callbacks.onOpenEditDialog(item),
          onOpenTimeEditDialog: (item: EventEntity) => this.callbacks.onOpenTimeEditDialog(item),
          onGapFound: (item: EventEntity) => this.callbacks.onGapFound(item),
          onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => {
            this.callbacks.onResolveConflictAction(item, strategy, gapMinutes);
          },
          onConfirmMoveToBacklog: (item: EventEntity) => this.callbacks.onConfirmMoveToBacklog(item),
          onConfirmDeleteEvent: (item: EventEntity) => this.callbacks.onConfirmDeleteEvent(item),
          onOpenGapOptimize: () => this.callbacks.onOpenGapOptimize(),
          onFilter: () => this.callbacks.onFilter(),
          onAi: () => this.callbacks.onAi(),
          onAdd: () => this.callbacks.onAdd(),
          onUndo: () => this.callbacks.onUndo(),
          onSave: () => this.callbacks.onSave()
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themePalette.pageBg)

      IndexCompanionOverlay({
        vm: this.vm,
        isVisible: this.isCompanionMode,
        overlayZIndex: this.companionOverlayZIndex,
        backRequestToken: this.companionBackRequestToken
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themePalette.pageBg)
  }
}
