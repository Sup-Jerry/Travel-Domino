import { ThemePalette } from '../../common/utils/ThemeCenter';
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { DateGroup, TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexHelpers } from './IndexHelpers';
import { IndexCompanionOverlay } from './IndexCompanionOverlay';
import { IndexScheduleArea } from './IndexScheduleArea';
import { IndexTopArea } from './IndexTopArea';
import { IndexTimelineTheme } from './IndexTimelineView';
import { IndexUnsavedActionTheme } from './IndexUnsavedActionBar';
import { IndexToolbarTheme } from './IndexToolbar';
import { IndexWeatherHintTheme } from './IndexWeatherHintBar';

export interface IndexPageTopAreaProps {
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
  hintPopupVisible: boolean;
  scorePopupVisible: boolean;
  hintLines: string[];
  scoreLines: string[];
  events: EventEntity[];
  backlogExpanded: boolean;
  dividerColor: string;
  toolbarTheme: IndexToolbarTheme;
  weatherTheme: IndexWeatherHintTheme;
  onBack: () => void;
  onOpenSettings: () => void;
  onEnterCompanion: () => void;
  onRefreshWeather: () => void;
  onToggleHint: () => void;
  onToggleScore: () => void;
  onHintPopupVisibleChange: (visible: boolean) => void;
  onScorePopupVisibleChange: (visible: boolean) => void;
  onToggleBacklogExpand: () => void;
  onMoveToSchedule: (item: TravelPlanItem) => void;
  onMoveAllToSchedule: () => void;
}

export interface IndexPageScheduleAreaProps {
  vm: TimelineViewModel;
  groupedEvents: DateGroup[];
  allEvents: EventEntity[];
  isArchived: boolean;
  isCompanionMode: boolean;
  showWeather: boolean;
  isPageRefreshing: boolean;
  gapsCount: number;
  hasUnsavedChanges: boolean;
  timelineTheme: IndexTimelineTheme;
  unsavedTheme: IndexUnsavedActionTheme;
  onIsDayCollapsed: (dayOffset: number) => boolean;
  onToggleDay: (dayOffset: number) => void;
  onRefresh: () => void;
  onOpenEditDialog: (item: EventEntity) => void;
  onOpenTimeEditDialog: (item: EventEntity) => void;
  onGapFound: (item: EventEntity) => void;
  onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => void;
  onConfirmMoveToBacklog: (item: EventEntity) => void;
  onConfirmDeleteEvent: (item: EventEntity) => void;
  onOpenGapOptimize: () => void;
  onFilter: () => void;
  onAi: () => void;
  onAdd: () => void;
  onUndo: () => void;
  onSave: () => void;
}

export interface IndexPageCompanionOverlayProps {
  vm: TimelineViewModel;
  isVisible: boolean;
  overlayZIndex: number;
}

export function shouldShowIndexPageWeatherHint(
  weatherFeatureEnabled: boolean,
  hasManualPlanningWeatherRefresh: boolean,
  weatherPlanningHint: string
): boolean {
  return weatherFeatureEnabled && hasManualPlanningWeatherRefresh && !!weatherPlanningHint;
}

export function resolveIndexPageGapsCount(gapsCount: number): number {
  return gapsCount;
}

export function buildIndexPageWeatherSuggestionText(
  collabLabel: string,
  planningHint: string,
  collabSummary: string,
  strategyHint: string
): string {
  return IndexHelpers.buildWeatherSuggestionText({
    collabLabel: collabLabel,
    planningHint: planningHint,
    collabSummary: collabSummary,
    strategyHint: strategyHint
  });
}

export function buildIndexPageHintLines(weatherHintExplanation: string): string[] {
  return IndexHelpers.splitLines(weatherHintExplanation);
}

export function buildIndexPageScoreLines(weatherScoreExplanation: string): string[] {
  return IndexHelpers.splitLines(weatherScoreExplanation);
}

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

  onBack: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onEnterCompanion: () => void = () => {};
  onRefreshWeather: () => void = () => {};
  onToggleHint: () => void = () => {};
  onToggleScore: () => void = () => {};
  onHintPopupVisibleChange: (visible: boolean) => void = (_visible: boolean) => {};
  onScorePopupVisibleChange: (visible: boolean) => void = (_visible: boolean) => {};
  onToggleBacklogExpand: () => void = () => {};
  onMoveToSchedule: (item: TravelPlanItem) => void = (_item: TravelPlanItem) => {};
  onMoveAllToSchedule: () => void = () => {};
  onIsDayCollapsed: (dayOffset: number) => boolean = (_dayOffset: number) => false;
  onToggleDay: (dayOffset: number) => void = (_dayOffset: number) => {};
  onScheduleRefresh: () => void = () => {};
  onOpenEditDialog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onOpenTimeEditDialog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onGapFound: (item: EventEntity) => void = (_item: EventEntity) => {};
  onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => void =
    (_item: EventEntity, _strategy: 'delay' | 'compress' | 'advance' | 'smart', _gapMinutes: number) => {};
  onConfirmMoveToBacklog: (item: EventEntity) => void = (_item: EventEntity) => {};
  onConfirmDeleteEvent: (item: EventEntity) => void = (_item: EventEntity) => {};
  onOpenGapOptimize: () => void = () => {};
  onFilter: () => void = () => {};
  onAi: () => void = () => {};
  onAdd: () => void = () => {};
  onUndo: () => void = () => {};
  onSave: () => void = () => {};

  buildTopAreaProps(): IndexPageTopAreaProps {
    return {
      planTitle: this.planTitle,
      strategyMode: this.strategyMode,
      currentStrategyExplanation: this.currentStrategyExplanation,
      isCompanionMode: this.isCompanionMode,
      isArchived: this.vm.isArchived,
      weatherFeatureEnabled: this.vm.isWeatherFeatureEnabled(),
      weatherLoading: this.vm.weatherLoading,
      weatherHintVisible: shouldShowIndexPageWeatherHint(
        this.vm.isWeatherFeatureEnabled(),
        this.hasManualPlanningWeatherRefresh,
        this.vm.weatherPlanningHint
      ),
      weatherSuggestionText: buildIndexPageWeatherSuggestionText(
        this.vm.weatherCollabLabel,
        this.vm.weatherPlanningHint,
        this.vm.weatherCollabSummary,
        this.vm.weatherStrategyHint
      ),
      weatherRouteScore: this.vm.weatherRouteScore,
      hintPopupVisible: this.showPlanningWeatherHintPopup,
      scorePopupVisible: this.showPlanningWeatherScorePopup,
      hintLines: buildIndexPageHintLines(this.vm.buildPlanningWeatherHintExplanation()),
      scoreLines: buildIndexPageScoreLines(this.vm.buildWeatherScoreExplanation(this.vm.weatherRouteScore)),
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
      onBack: () => this.onBack(),
      onOpenSettings: () => this.onOpenSettings(),
      onEnterCompanion: () => this.onEnterCompanion(),
      onRefreshWeather: () => this.onRefreshWeather(),
      onToggleHint: () => this.onToggleHint(),
      onToggleScore: () => this.onToggleScore(),
      onHintPopupVisibleChange: (visible: boolean) => this.onHintPopupVisibleChange(visible),
      onScorePopupVisibleChange: (visible: boolean) => this.onScorePopupVisibleChange(visible),
      onToggleBacklogExpand: () => this.onToggleBacklogExpand(),
      onMoveToSchedule: (item: TravelPlanItem) => this.onMoveToSchedule(item),
      onMoveAllToSchedule: () => this.onMoveAllToSchedule()
    };
  }

  buildScheduleAreaProps(): IndexPageScheduleAreaProps {
    return {
      vm: this.vm,
      groupedEvents: this.vm.groupedEvents,
      allEvents: this.vm.events,
      isArchived: this.vm.isArchived,
      isCompanionMode: this.isCompanionMode,
      showWeather: this.vm.isWeatherFeatureEnabled(),
      isPageRefreshing: this.isPageRefreshing,
      gapsCount: resolveIndexPageGapsCount(this.vm.getSortedGaps().length),
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
      onIsDayCollapsed: (dayOffset: number) => this.onIsDayCollapsed(dayOffset),
      onToggleDay: (dayOffset: number) => this.onToggleDay(dayOffset),
      onRefresh: () => this.onScheduleRefresh(),
      onOpenEditDialog: (item: EventEntity) => this.onOpenEditDialog(item),
      onOpenTimeEditDialog: (item: EventEntity) => this.onOpenTimeEditDialog(item),
      onGapFound: (item: EventEntity) => this.onGapFound(item),
      onResolveConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => {
        this.onResolveConflictAction(item, strategy, gapMinutes);
      },
      onConfirmMoveToBacklog: (item: EventEntity) => this.onConfirmMoveToBacklog(item),
      onConfirmDeleteEvent: (item: EventEntity) => this.onConfirmDeleteEvent(item),
      onOpenGapOptimize: () => this.onOpenGapOptimize(),
      onFilter: () => this.onFilter(),
      onAi: () => this.onAi(),
      onAdd: () => this.onAdd(),
      onUndo: () => this.onUndo(),
      onSave: () => this.onSave()
    };
  }

  buildCompanionOverlayProps(): IndexPageCompanionOverlayProps {
    return {
      vm: this.vm,
      isVisible: this.isCompanionMode,
      overlayZIndex: this.companionOverlayZIndex
    };
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        IndexTopArea(this.buildTopAreaProps())

        IndexScheduleArea(this.buildScheduleAreaProps())
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themePalette.pageBg)

      IndexCompanionOverlay(this.buildCompanionOverlayProps())
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themePalette.pageBg)
  }
}
