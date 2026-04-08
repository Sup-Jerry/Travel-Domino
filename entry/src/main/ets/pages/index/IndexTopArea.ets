import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { IndexBacklogView } from './IndexBacklogView';
import { IndexToolbar, IndexToolbarTheme } from './IndexToolbar';
import { IndexWeatherHintBar, IndexWeatherHintTheme } from './IndexWeatherHintBar';

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

  private getSafeEvents(): EventEntity[] {
    return this.events ?? [];
  }

  private getSafeToolbarTheme(): IndexToolbarTheme {
    return this.toolbarTheme ?? {
      primary: '#2F7DFF',
      textTertiary: '#8C8C8C',
      cardBgSoft: '#F4F6FA',
      textPrimary: '#1F1F1F'
    };
  }

  private getSafeWeatherTheme(): IndexWeatherHintTheme {
    return this.weatherTheme ?? {
      primary: '#2F7DFF',
      textPrimary: '#1F2937',
      cardBgSoft: '#F5F7FA'
    };
  }

  build() {
    Column() {
      IndexToolbar({
        planTitle: this.planTitle,
        strategyMode: this.strategyMode,
        currentStrategyExplanation: this.currentStrategyExplanation,
        isCompanionMode: this.isCompanionMode,
        isArchived: this.isArchived,
        weatherFeatureEnabled: this.weatherFeatureEnabled,
        weatherLoading: this.weatherLoading,
        theme: this.getSafeToolbarTheme(),
        onBack: () => this.onBack(),
        onOpenSettings: () => {
          hilog.info(0x0000, 'IndexTopArea', '[TOP_NAV][forward] action=open_settings');
          this.onOpenSettings();
        },
        onEnterCompanion: () => {
          hilog.info(0x0000, 'IndexTopArea', '[TOP_NAV][forward] action=enter_companion');
          this.onEnterCompanion();
        },
        onRefreshWeather: () => {
          hilog.info(0x0000, 'IndexTopArea', '[TOP_NAV][forward] action=refresh_weather');
          this.onRefreshWeather();
        }
      })

      IndexWeatherHintBar({
        visible: this.weatherHintVisible,
        suggestionText: this.weatherSuggestionText,
        routeScore: this.weatherRouteScore,
        hintPopupVisible: this.hintPopupVisible,
        scorePopupVisible: this.scorePopupVisible,
        hintLines: this.hintLines,
        scoreLines: this.scoreLines,
        theme: this.getSafeWeatherTheme(),
        onToggleHint: () => this.onToggleHint(),
        onToggleScore: () => this.onToggleScore(),
        onHintPopupVisibleChange: (visible: boolean) => this.onHintPopupVisibleChange(visible),
        onScorePopupVisibleChange: (visible: boolean) => this.onScorePopupVisibleChange(visible)
      })

      IndexBacklogView({
        events: this.getSafeEvents(),
        isExpanded: this.backlogExpanded,
        dividerColor: this.dividerColor,
        onToggleExpand: () => this.onToggleBacklogExpand(),
        onMoveToSchedule: (item: TravelPlanItem) => this.onMoveToSchedule(item),
        onMoveAllToSchedule: () => this.onMoveAllToSchedule()
      })
    }
  }
}
