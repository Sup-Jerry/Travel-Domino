import { ThemePalette } from '../../common/utils/ThemeCenter';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexPageLayoutCallbacks } from './IndexLayoutCallbacksHelper';
import { ThemeCenter } from '../../common/utils/ThemeCenter';

export interface IndexLayoutProps {
  vm: TimelineViewModel;
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
  themePalette: ThemePalette;
  companionOverlayZIndex: number;
  companionBackRequestToken: number;
  callbacks: IndexPageLayoutCallbacks;
  onTopBack: () => void;
  onTopOpenSettings: () => void;
  onTopEnterCompanion: () => void;
  onTopRefreshWeather: () => void;
}

export class IndexLayoutPropsBuilder {
  static create(params: IndexLayoutProps): IndexLayoutProps {
    return {
      vm: params.vm ?? new TimelineViewModel(),
      planTitle: params.planTitle,
      strategyMode: params.strategyMode,
      currentStrategyExplanation: params.currentStrategyExplanation,
      isCompanionMode: params.isCompanionMode,
      hasManualPlanningWeatherRefresh: params.hasManualPlanningWeatherRefresh,
      showPlanningWeatherHintPopup: params.showPlanningWeatherHintPopup,
      showPlanningWeatherScorePopup: params.showPlanningWeatherScorePopup,
      backlogExpanded: params.backlogExpanded,
      isPageRefreshing: params.isPageRefreshing,
      hasUnsavedChanges: params.hasUnsavedChanges,
      themePalette: params.themePalette ?? ThemeCenter.getPalette('light'),
      companionOverlayZIndex: params.companionOverlayZIndex,
      companionBackRequestToken: params.companionBackRequestToken,
      callbacks: params.callbacks,
      onTopBack: params.onTopBack,
      onTopOpenSettings: params.onTopOpenSettings,
      onTopEnterCompanion: params.onTopEnterCompanion,
      onTopRefreshWeather: params.onTopRefreshWeather
    };
  }
}
