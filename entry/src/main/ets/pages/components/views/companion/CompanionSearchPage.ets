import { EventEntity } from '../../../../model/entity/EventEntity';
import { ThemeCenter } from '../../../../common/utils/ThemeCenter';

function noopCompanionSearchVoid(): void {}

function noopCompanionSearchKeyword(_keyword: string): void {}

function noopCompanionSearchEvent(_item: EventEntity): void {}

function defaultCompanionSearchText(_item: EventEntity): string {
  return '--';
}

export function shouldShowCompanionSearchPage(showSearchPage: boolean): boolean {
  return showSearchPage;
}

export function shouldShowCompanionSearchEmptyState(resultCount: number): boolean {
  return resultCount === 0;
}

export function getCompanionSearchResultMetaText(stateLabel: string, plannedRange: string): string {
  return `${stateLabel} | ${plannedRange}`;
}

@Component
export struct CompanionSearchPage {
  @Prop showSearchPage: boolean = false;
  @Prop searchKeyword: string = '';
  @Prop searchResults: EventEntity[] = [];
  @Prop safeTopInset: number = 0;
  @Prop safeBottomInset: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  onClose = noopCompanionSearchVoid;
  onSearch = noopCompanionSearchKeyword;
  onResultClick = noopCompanionSearchEvent;
  getEventStateLabel = defaultCompanionSearchText;
  getPlannedRange = defaultCompanionSearchText;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  build() {
    if (shouldShowCompanionSearchPage(this.showSearchPage)) {
      Column({ space: 10 }) {
        Row() {
          Text('搜索日程')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary);
          Blank();
          Text('关闭')
            .fontSize(14)
            .fontColor(this.getThemePalette().textSecondary)
            .onClick(() => {
              this.onClose();
            });
        }
        .width('100%')
        .padding({ top: this.safeTopInset + 8, bottom: 8 });

        TextInput({ text: this.searchKeyword, placeholder: '输入地点名或地址' })
          .width('100%')
          .height(42)
          .borderRadius(10)
          .backgroundColor(this.getThemePalette().companionCardBg)
          .fontColor(this.getThemePalette().textPrimary)
          .placeholderColor(this.getThemePalette().textTertiary)
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            this.onSearch(value);
          });

        if (shouldShowCompanionSearchEmptyState(this.searchResults.length)) {
          Column({ space: 8 }) {
            Text('没有匹配结果')
              .fontSize(15)
              .fontColor(this.getThemePalette().textSecondary);
            Text('可尝试更短关键词')
              .fontSize(12)
              .fontColor(this.getThemePalette().textTertiary);
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center);
        } else {
          List({ space: 8 }) {
            ForEach(this.searchResults, (item: EventEntity) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Text(item.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getThemePalette().textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                    Text(getCompanionSearchResultMetaText(this.getEventStateLabel(item), this.getPlannedRange(item)))
                      .fontSize(12)
                      .fontColor(this.getThemePalette().textSecondary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis });
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start);

                  Text('聚焦')
                    .fontSize(12)
                    .fontColor(this.getThemePalette().primary);
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                .backgroundColor(this.getThemePalette().companionCardBg)
                .borderRadius(10)
                .onClick(() => {
                  this.onResultClick(item);
                });
              };
            }, (item: EventEntity) => item.id.toString());
          }
          .width('100%')
          .layoutWeight(1);
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, bottom: this.safeBottomInset + 14 })
      .backgroundColor(this.getThemePalette().companionBg)
      .zIndex(10)
      .transition({
        type: TransitionType.All,
        opacity: 0,
        translate: { y: 18 },
        scale: { x: 0.985, y: 0.985 }
      });
    }
  }
}

