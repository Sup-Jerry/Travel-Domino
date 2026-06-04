import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { IndexBacklogView } from './IndexBacklogView';
import { IndexToolbar, IndexToolbarTheme } from './IndexToolbar';
import { IndexWeatherHintBar, IndexWeatherHintTheme } from './IndexWeatherHintBar';

export type IndexTopVoidCallback = () => void;
export type IndexTopVisibleChangeCallback = (visible: boolean) => void;
export type IndexTopMoveToScheduleCallback = (item: TravelPlanItem) => void;

export interface IndexTopAreaToolbarProps {
  planTitle: string;
  strategyMode: number;
  currentStrategyExplanation: string;
  isCompanionMode: boolean;
  isArchived: boolean;
  weatherFeatureEnabled: boolean;
  weatherLoading: boolean;
  theme: IndexToolbarTheme;
  onBack: IndexTopVoidCallback;
  onOpenSettings: IndexTopVoidCallback;
  onEnterCompanion: IndexTopVoidCallback;
  onRefreshWeather: IndexTopVoidCallback;
}

export interface IndexTopAreaWeatherHintBarProps {
  visible: boolean;
  suggestionText: string;
  routeScore: number;
  hintPopupVisible: boolean;
  scorePopupVisible: boolean;
  hintLines: string[];
  scoreLines: string[];
  theme: IndexWeatherHintTheme;
  onToggleHint: IndexTopVoidCallback;
  onToggleScore: IndexTopVoidCallback;
  onHintPopupVisibleChange: IndexTopVisibleChangeCallback;
  onScorePopupVisibleChange: IndexTopVisibleChangeCallback;
}

export interface IndexTopAreaBacklogViewProps {
  events: EventEntity[];
  isExpanded: boolean;
  dividerColor: string;
  onToggleExpand: IndexTopVoidCallback;
  onMoveToSchedule: IndexTopMoveToScheduleCallback;
  onMoveAllToSchedule: IndexTopVoidCallback;
}

export function shouldShowIndexTopAreaWeatherHintBar(weatherHintVisible: boolean): boolean {
  return weatherHintVisible;
}

@Component
export struct IndexTopArea {
  @Prop planTitle: string = '';
  @Prop strategyMode: number = 0;
  @Prop currentStrategyExplanation: string = '';
  @Prop isCompanionMode: boolean = false;
  @Prop isArchived: boolean = false;
  @Prop weatherFeatureEnabled: boolean = false;
  @Prop weatherLoading: boolean = false;
  @Prop weatherHintVisible: boolean = false;
  @Prop weatherSuggestionText: string = '';
  @Prop weatherRouteScore: number = -1;
  @Prop hintPopupVisible: boolean = false;
  @Prop scorePopupVisible: boolean = false;
  @Prop hintLines: string[] = [];
  @Prop scoreLines: string[] = [];
  @Prop events: EventEntity[] = [];
  @Prop backlogExpanded: boolean = false;
  @Prop dividerColor: string = '#E7EDF5';
  @Prop toolbarTheme: IndexToolbarTheme = {
    primary: '#2F7DFF',
    textTertiary: '#8C8C8C',
    cardBgSoft: '#F4F6FA',
    textPrimary: '#1F1F1F'
  };
  @Prop weatherTheme: IndexWeatherHintTheme = {
    primary: '#2F7DFF',
    textPrimary: '#1F2937',
    cardBgSoft: '#F5F7FA'
  };

  onBack: IndexTopVoidCallback = () => {};
  onOpenSettings: IndexTopVoidCallback = () => {};
  onEnterCompanion: IndexTopVoidCallback = () => {};
  onRefreshWeather: IndexTopVoidCallback = () => {};
  onToggleHint: IndexTopVoidCallback = () => {};
  onToggleScore: IndexTopVoidCallback = () => {};
  onHintPopupVisibleChange: IndexTopVisibleChangeCallback = (_visible: boolean) => {};
  onScorePopupVisibleChange: IndexTopVisibleChangeCallback = (_visible: boolean) => {};
  onToggleBacklogExpand: IndexTopVoidCallback = () => {};
  onMoveToSchedule: IndexTopMoveToScheduleCallback = (_item: TravelPlanItem) => {};
  onMoveAllToSchedule: IndexTopVoidCallback = () => {};

  buildToolbarProps(): IndexTopAreaToolbarProps {
    return {
      planTitle: this.planTitle,
      strategyMode: this.strategyMode,
      currentStrategyExplanation: this.currentStrategyExplanation,
      isCompanionMode: this.isCompanionMode,
      isArchived: this.isArchived,
      weatherFeatureEnabled: this.weatherFeatureEnabled,
      weatherLoading: this.weatherLoading,
      theme: this.toolbarTheme,
      onBack: () => this.onBack(),
      onOpenSettings: () => this.onOpenSettings(),
      onEnterCompanion: () => this.onEnterCompanion(),
      onRefreshWeather: () => this.onRefreshWeather()
    };
  }

  buildWeatherHintBarProps(): IndexTopAreaWeatherHintBarProps {
    return {
      visible: shouldShowIndexTopAreaWeatherHintBar(this.weatherHintVisible),
      suggestionText: this.weatherSuggestionText,
      routeScore: this.weatherRouteScore,
      hintPopupVisible: this.hintPopupVisible,
      scorePopupVisible: this.scorePopupVisible,
      hintLines: this.hintLines,
      scoreLines: this.scoreLines,
      theme: this.weatherTheme,
      onToggleHint: () => this.onToggleHint(),
      onToggleScore: () => this.onToggleScore(),
      onHintPopupVisibleChange: (visible: boolean) => this.onHintPopupVisibleChange(visible),
      onScorePopupVisibleChange: (visible: boolean) => this.onScorePopupVisibleChange(visible)
    };
  }

  buildBacklogViewProps(): IndexTopAreaBacklogViewProps {
    return {
      events: this.events,
      isExpanded: this.backlogExpanded,
      dividerColor: this.dividerColor,
      onToggleExpand: () => this.onToggleBacklogExpand(),
      onMoveToSchedule: (item: TravelPlanItem) => this.onMoveToSchedule(item),
      onMoveAllToSchedule: () => this.onMoveAllToSchedule()
    };
  }

  build() {
    Column() {
      IndexToolbar(this.buildToolbarProps())

      IndexWeatherHintBar(this.buildWeatherHintBarProps())

      IndexBacklogView(this.buildBacklogViewProps())
    }
  }
}
