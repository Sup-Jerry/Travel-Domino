export interface IndexToolbarTheme {
  primary: string;
  textTertiary: string;
  cardBgSoft: string;
  textPrimary: string;
}

export function resolveIndexToolbarDisplayTitle(planTitle: string, maxLength: number = 7): string {
  return planTitle.length > maxLength ? `${planTitle.substring(0, maxLength)}...` : planTitle;
}

export function shouldShowIndexToolbarModeTag(strategyMode: number): boolean {
  return strategyMode !== 0;
}

export function shouldShowIndexToolbarModeExplanation(strategyMode: number, currentStrategyExplanation: string): boolean {
  return strategyMode !== 0 && !!currentStrategyExplanation;
}

export function shouldShowIndexToolbarWeatherAction(isCompanionMode: boolean, weatherFeatureEnabled: boolean): boolean {
  return !isCompanionMode && weatherFeatureEnabled;
}

@Component
export struct IndexToolbar {
  @Prop planTitle: string = '行程详情';
  @Prop strategyMode: number = 0;
  @Prop currentStrategyExplanation: string = '';
  @Prop isCompanionMode: boolean = false;
  @Prop isArchived: boolean = false;
  @Prop weatherFeatureEnabled: boolean = false;
  @Prop weatherLoading: boolean = false;
  @Prop theme: IndexToolbarTheme = {
    primary: '#2F7DFF',
    textTertiary: '#8C8C8C',
    cardBgSoft: '#F4F6FA',
    textPrimary: '#1F1F1F'
  };

  onBack: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onEnterCompanion: () => void = () => {};
  onRefreshWeather: () => void = () => {};

  private getModeLabel(): string {
    if (this.strategyMode === 1) {
      return '🚀 特种兵模式';
    }
    if (this.strategyMode === 2) {
      return '🌴 休闲模式';
    }
    if (this.strategyMode === -1) {
      return '🎛 自定义策略';
    }
    return '';
  }

  private getModeColor(): string {
    if (this.strategyMode === 1) {
      return '#FF6B35';
    }
    if (this.strategyMode === 2) {
      return '#4CAF50';
    }
    if (this.strategyMode === -1) {
      return '#2196F3';
    }
    return this.theme.textTertiary;
  }

  build() {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text('返回')
          .fontSize(16)
          .fontColor(this.theme.primary)
      }
      .backgroundColor(Color.Transparent)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(8)
      .onClick(() => this.onBack())

      Column() {
        Text(resolveIndexToolbarDisplayTitle(this.planTitle))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        if (shouldShowIndexToolbarModeTag(this.strategyMode)) {
          Text(this.getModeLabel())
            .fontSize(11)
            .fontColor(this.getModeColor())
            .margin({ top: 2 })
        }

        if (shouldShowIndexToolbarModeExplanation(this.strategyMode, this.currentStrategyExplanation)) {
          Text(this.currentStrategyExplanation)
            .fontSize(10)
            .fontColor(this.getModeColor())
            .margin({ top: 1 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Text('点击修改日期')
          .fontSize(10)
          .fontColor(this.theme.textTertiary)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.isArchived) {
          return;
        }
        this.onOpenSettings();
      })

      Row() {
        Text('🚀').fontSize(18)
      }
      .padding(8)
      .margin({ right: 4 })
      .onClick(() => this.onEnterCompanion())

      if (shouldShowIndexToolbarWeatherAction(this.isCompanionMode, this.weatherFeatureEnabled)) {
        Button(this.weatherLoading ? '⏳' : '🌤️')
          .height(30)
          .fontSize(16)
          .padding({ left: 10, right: 10 })
          .backgroundColor(this.theme.cardBgSoft)
          .fontColor(this.theme.textPrimary)
          .enabled(!this.weatherLoading)
          .onClick(() => this.onRefreshWeather())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.Transparent)
  }
}
