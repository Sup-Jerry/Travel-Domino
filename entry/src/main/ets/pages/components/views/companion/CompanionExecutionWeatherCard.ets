import { WeatherSuggestion } from '../../../../domain/services/WeatherModels';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';
import {
  CompanionWeatherHintPopupBuilder,
  CompanionWeatherScorePopupBuilder,
  CompanionWeatherSuggestionPopupBuilder
} from './CompanionWeatherPopups';

export function getExecutionWeatherRefreshText(isLoading: boolean): string {
  return isLoading ? '刷新中...' : '刷新';
}

export function getExecutionWeatherExpandToggleText(expanded: boolean): string {
  return expanded ? '收起' : '展开';
}

export function getExecutionWeatherCollapsedHintText(hint: string): string {
  return hint.trim().length > 0 ? hint : '天气建议已收起，请用上方“展开”查看';
}

export function getExecutionWeatherCurrentNodeText(currentText: string): string {
  const value = currentText.trim().length > 0 ? currentText : '天气未知';
  return `当前位置：${value}`;
}

export function getExecutionWeatherNextNodeText(nextText: string): string {
  const value = nextText.trim().length > 0 ? nextText : '天气未知';
  return `下一节点：${value}`;
}

export function shouldShowExecutionWeatherScore(score: number): boolean {
  return score >= 0;
}

export function shouldShowExecutionWeatherHint(hint: string): boolean {
  return hint.trim().length > 0;
}

export function shouldShowExecutionWeatherCollabSummary(summary: string): boolean {
  return summary.trim().length > 0;
}

export function shouldShowExecutionWeatherAppliedSummary(summary: string): boolean {
  return summary.trim().length > 0;
}

export function splitExecutionWeatherSuggestionPopupText(text: string): string[] {
  return text.split('\n');
}

@Component
export struct CompanionExecutionWeatherCard {
  @Prop weatherExpanded: boolean = false;
  @Prop showWeatherScorePopup: boolean = false;
  @Prop showWeatherHintPopup: boolean = false;
  @Prop showWeatherSuggestionPopup: boolean = false;
  @Prop weatherSuggestionPopupText: string = '';

  @Prop weatherScoreSummary: string = '暂无评分';
  @Prop weatherScoreLines: string[] = [];
  @Prop weatherHintLines: string[] = [];

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
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

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

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('执行天气')
          .fontSize(14)
          .fontColor(this.getThemePalette().textSecondary);
        if (this.executionWeatherCollabBadge.trim().length > 0) {
          Text(this.executionWeatherCollabBadge)
            .fontSize(11)
            .fontColor(this.getThemePalette().primary)
            .backgroundColor(this.getThemePalette().cardBgSoft)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
            .margin({ left: 6 });
        }
        Blank();
        Text(getExecutionWeatherRefreshText(this.executionWeatherLoading))
          .fontSize(12)
          .fontColor(this.getThemePalette().primary)
          .onClick(() => {
            this.onRefreshWeather();
          });
        Text(getExecutionWeatherExpandToggleText(this.weatherExpanded))
          .fontSize(12)
          .fontColor(this.getThemePalette().primary)
          .margin({ left: 10 })
          .onClick(() => {
            this.onToggleExpanded();
          });
      }
      .width('100%');

      if (!this.weatherExpanded) {
        Row() {
          Text(this.weatherScoreSummary)
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary)
            .layoutWeight(1);
          Text(getExecutionWeatherCollapsedHintText(this.executionWeatherHint))
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(2);
        }
        .width('100%');
      } else {
        Row() {
          Text(getExecutionWeatherCurrentNodeText(this.executionWeatherCurrentText))
            .fontSize(13)
            .fontColor(this.getThemePalette().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
        }
        .width('100%');

        Row() {
          Text(getExecutionWeatherNextNodeText(this.executionWeatherNextText))
            .fontSize(13)
            .fontColor(this.getThemePalette().textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1);
          if (shouldShowExecutionWeatherScore(this.executionWeatherScore)) {
            Text(`评分 ${this.executionWeatherScore} ⓘ`)
              .fontSize(12)
              .fontColor(this.getThemePalette().primary)
              .onClick(() => {
                this.onToggleScorePopup();
              })
              .bindPopup(this.showWeatherScorePopup, {
                builder: () => {
                  CompanionWeatherScorePopupBuilder(this.weatherScoreLines);
                },
                placement: Placement.BottomLeft,
                mask: false,
                popupColor: this.getThemePalette().cardBgSoft,
                onStateChange: (e) => {
                  this.onScorePopupStateChange(e.isVisible);
                }
              });
          }
        }
        .width('100%');

        if (shouldShowExecutionWeatherHint(this.executionWeatherHint)) {
          Text(`${this.executionWeatherHint}  ⓘ`)
            .fontSize(13)
            .fontColor(
              this.executionWeatherLevel === 'WARNING'
                ? this.getThemePalette().danger
                : (this.executionWeatherLevel === 'NOTICE'
                  ? this.getThemePalette().warning
                  : this.getThemePalette().textSecondary)
            )
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .onClick(() => {
              this.onToggleHintPopup();
            })
            .bindPopup(this.showWeatherHintPopup, {
              builder: () => {
                CompanionWeatherHintPopupBuilder(this.weatherHintLines);
              },
              placement: Placement.BottomLeft,
              mask: false,
              popupColor: this.getThemePalette().cardBgSoft,
              onStateChange: (e) => {
                this.onHintPopupStateChange(e.isVisible);
              }
            });
        }

        if (shouldShowExecutionWeatherCollabSummary(this.executionWeatherCollabSummary)) {
          Text(`多日/多城：${this.executionWeatherCollabSummary}`)
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }

        if (shouldShowExecutionWeatherAppliedSummary(this.executionWeatherAppliedSummary)) {
          Text(`调整结果：${this.executionWeatherAppliedSummary}`)
            .fontSize(12)
            .fontColor(this.getThemePalette().primary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%');
        }

        if (this.executionWeatherSuggestions.length > 0) {
          Column({ space: 8 }) {
            Text('调整建议（可选）')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemePalette().primary)
              .width('100%')
              .onClick(() => {
                this.onOpenSuggestionGuide();
              })
              .bindPopup(this.showWeatherSuggestionPopup, {
                builder: () => {
                  CompanionWeatherSuggestionPopupBuilder(splitExecutionWeatherSuggestionPopupText(this.weatherSuggestionPopupText));
                },
                placement: Placement.BottomLeft,
                mask: false,
                popupColor: this.getThemePalette().cardBgSoft,
                onStateChange: (e) => {
                  this.onSuggestionPopupStateChange(e.isVisible);
                }
              });

            ForEach(this.executionWeatherSuggestions, (item: WeatherSuggestion) => {
              Column({ space: 6 }) {
                Text(`${item.title}  ⓘ`)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getThemePalette().primary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .onClick(() => {
                    this.onOpenSuggestionDetail(item);
                  });

                Text(item.message)
                  .fontSize(12)
                  .fontColor(this.getThemePalette().textSecondary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%');

                Row({ space: 8 }) {
                  Text('可选应用')
                    .fontSize(12)
                    .fontColor(this.getThemePalette().primary)
                    .onClick(() => {
                      this.onApplySuggestion(item);
                    });
                  Text('稍后')
                    .fontSize(12)
                    .fontColor(this.getThemePalette().warning)
                    .onClick(() => {
                      this.onLaterSuggestion(item.suggestionId);
                    });
                  Text('忽略')
                    .fontSize(12)
                    .fontColor(this.getThemePalette().textTertiary)
                    .onClick(() => {
                      this.onIgnoreSuggestion(item.suggestionId);
                    });
                }
                .width('100%');
              }
              .width('100%')
              .padding(8)
              .backgroundColor(this.getThemePalette().cardBgSoft)
              .borderRadius(8);
            }, (item: WeatherSuggestion) => item.suggestionId);
          }
          .width('100%');
        }
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.getThemePalette().companionCardBg)
    .borderRadius(12)
    .border({ width: 1, color: this.getThemePalette().border, radius: 12 });
  }
}
