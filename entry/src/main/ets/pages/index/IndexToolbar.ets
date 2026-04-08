export interface IndexToolbarTheme {
  primary: string;
  textTertiary: string;
  cardBgSoft: string;
  textPrimary: string;
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

  private getSafePlanTitle(): string {
    return this.planTitle ?? '';
  }

  private getSafeStrategyExplanation(): string {
    return this.currentStrategyExplanation ?? '';
  }

  private getSafeTheme(): IndexToolbarTheme {
    return this.theme ?? {
      primary: '#2F7DFF',
      textTertiary: '#8C8C8C',
      cardBgSoft: '#F4F6FA',
      textPrimary: '#1F1F1F'
    };
  }

  private getModeLabel(): string {
    if (this.strategyMode === 1) {
      return '特种兵模式';
    }
    if (this.strategyMode === 2) {
      return '休闲模式';
    }
    if (this.strategyMode === -1) {
      return '自定义策略';
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
    return this.getSafeTheme().textTertiary;
  }

  build() {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Text('返回')
          .fontSize(16)
          .fontColor(this.getSafeTheme().primary)
      }
      .backgroundColor(Color.Transparent)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(8)
      .onClick(() => this.onBack())

      Column() {
        Text(this.getSafePlanTitle().length > 7 ? `${this.getSafePlanTitle().substring(0, 7)}...` : this.getSafePlanTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        if (this.strategyMode !== 0) {
          Text(this.getModeLabel())
            .fontSize(11)
            .fontColor(this.getModeColor())
            .margin({ top: 2 })
        }

        if (this.strategyMode !== 0 && this.getSafeStrategyExplanation()) {
          Text(this.getSafeStrategyExplanation())
            .fontSize(10)
            .fontColor(this.getModeColor())
            .margin({ top: 1 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Text('点击修改日期')
          .fontSize(10)
          .fontColor(this.getSafeTheme().textTertiary)
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
        Text('伴游').fontSize(14)
      }
      .padding(8)
      .margin({ right: 4 })
      .onClick(() => this.onEnterCompanion())

      if (!this.isCompanionMode && this.weatherFeatureEnabled) {
        Button(this.weatherLoading ? '...' : '天气')
          .height(30)
          .fontSize(16)
          .padding({ left: 10, right: 10 })
          .backgroundColor(this.getSafeTheme().cardBgSoft)
          .fontColor(this.getSafeTheme().textPrimary)
          .enabled(!this.weatherLoading)
          .onClick(() => this.onRefreshWeather())
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.Transparent)
  }
}
