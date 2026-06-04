export interface IndexWeatherHintTheme {
  primary: string;
  textPrimary: string;
  cardBgSoft: string;
}

type IndexWeatherHintVoidAction = () => void;
type IndexWeatherHintVisibleAction = (visible: boolean) => void;

export function resolveIndexWeatherHintLine(lines: string[], index: number): string {
  return lines[index] ?? '';
}

export function resolveIndexWeatherScoreLine(lines: string[], index: number): string {
  return lines[index] ?? '';
}

export function shouldShowIndexWeatherHintBar(visible: boolean): boolean {
  return visible;
}

export function shouldShowIndexWeatherRouteScore(routeScore: number): boolean {
  return routeScore >= 0;
}

@Component
export struct IndexWeatherHintBar {
  @Prop visible: boolean = false;
  @Prop suggestionText: string = '';
  @Prop routeScore: number = -1;
  @Prop hintPopupVisible: boolean = false;
  @Prop scorePopupVisible: boolean = false;
  @Prop hintLines: string[] = [];
  @Prop scoreLines: string[] = [];
  @Prop theme: IndexWeatherHintTheme = {
    primary: '#2F7DFF',
    textPrimary: '#1F2937',
    cardBgSoft: '#F5F7FA'
  };

  onToggleHint: IndexWeatherHintVoidAction = () => {};
  onToggleScore: IndexWeatherHintVoidAction = () => {};
  onHintPopupVisibleChange: IndexWeatherHintVisibleAction = (_visible: boolean) => {};
  onScorePopupVisibleChange: IndexWeatherHintVisibleAction = (_visible: boolean) => {};

  private resolveHintLine(index: number): string {
    return resolveIndexWeatherHintLine(this.hintLines, index);
  }

  private resolveScoreLine(index: number): string {
    return resolveIndexWeatherScoreLine(this.scoreLines, index);
  }

  @Builder
  private hintPopupBuilder() {
    Scroll() {
      Column({ space: 2 }) {
        Text(this.resolveHintLine(0))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#1565C0')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveHintLine(1))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#2E7D32')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveHintLine(2))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#6A1B9A')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveHintLine(3))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#455A64')
          .fontWeight(FontWeight.Medium)
        Text('仅作为建议，不会自动改行程。')
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#D32F2F')
          .fontWeight(FontWeight.Bold)
      }
      .padding(10)
      .width('100%');
    }
    .height(230)
    .width(280);
  }

  @Builder
  private scorePopupBuilder() {
    Scroll() {
      Column({ space: 2 }) {
        Text(this.resolveScoreLine(0))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#1565C0')
          .fontWeight(FontWeight.Bold)
        Text(this.resolveScoreLine(1))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#2E7D32')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveScoreLine(2))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#6A1B9A')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveScoreLine(3))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#455A64')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveScoreLine(4))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#EF6C00')
          .fontWeight(FontWeight.Medium)
        Text(this.resolveScoreLine(5))
          .fontSize(12)
          .lineHeight(20)
          .fontColor('#1B5E20')
          .fontWeight(FontWeight.Medium)
      }
      .padding(10)
      .width('100%');
    }
    .height(230)
    .width(280);
  }

  build() {
    if (shouldShowIndexWeatherHintBar(this.visible)) {
      Row() {
        Text(this.suggestionText)
          .fontSize(13)
          .fontColor(this.theme.primary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => {
            this.onToggleHint();
          })
          .bindPopup(this.hintPopupVisible, {
            builder: this.hintPopupBuilder,
            placement: Placement.BottomLeft,
            mask: false,
            popupColor: this.theme.cardBgSoft,
            onStateChange: (e) => {
              this.onHintPopupVisibleChange(e.isVisible);
            }
          });

        Column()
          .width(1)
          .height(36)
          .margin({ left: 10, right: 10 })
          .backgroundColor('#2E7D32')
          .borderRadius(1);

        if (shouldShowIndexWeatherRouteScore(this.routeScore)) {
          Column() {
            Text('评分 ⓘ')
              .fontSize(12)
              .fontColor(this.theme.primary);
            Text(`${this.routeScore}`)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary);
          }
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.onToggleScore();
          })
          .bindPopup(this.scorePopupVisible, {
            builder: this.scorePopupBuilder,
            placement: Placement.BottomLeft,
            mask: false,
            popupColor: this.theme.cardBgSoft,
            onStateChange: (e) => {
              this.onScorePopupVisibleChange(e.isVisible);
            }
          });
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .margin({ bottom: 4 })
      .backgroundColor(this.theme.cardBgSoft)
      .borderRadius(12);
    }
  }
}
