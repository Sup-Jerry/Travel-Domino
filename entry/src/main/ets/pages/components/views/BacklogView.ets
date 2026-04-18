import { TravelPlanItem } from '../../../model/interface/IStandardEvent';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';


export function getBacklogExpandSymbol(isExpanded: boolean): string {
  return isExpanded ? '\u25BC' : '\u25B6';
}

export function shouldShowBacklogMoveAllButton(itemCount: number): boolean {
  return itemCount > 0;
}

export function shouldShowBacklogEmptyState(isExpanded: boolean, itemCount: number): boolean {
  return isExpanded && itemCount === 0;
}

export function getBacklogBadgeText(itemCount: number): string {
  return `${itemCount}`;
}

export interface BacklogViewState {
  expandSymbol: string;
  badgeText: string;
  showMoveAllButton: boolean;
  showEmptyState: boolean;
}

export function resolveBacklogViewState(isExpanded: boolean, itemCount: number): BacklogViewState {
  return {
    expandSymbol: getBacklogExpandSymbol(isExpanded),
    badgeText: getBacklogBadgeText(itemCount),
    showMoveAllButton: shouldShowBacklogMoveAllButton(itemCount),
    showEmptyState: shouldShowBacklogEmptyState(isExpanded, itemCount)
  };
}

@Component
export struct BacklogView {
  @Prop items: TravelPlanItem[];
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  // 由父级控制展开状态
  @Prop isExpanded: boolean;

  // 由父级处理展开/收起切换
  onToggleExpand: () => void = () => {};

  onMoveToSchedule: (item: TravelPlanItem) => void = () => {};
  onMoveAllToSchedule: () => void = () => {};

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private getViewState(): BacklogViewState {
    return resolveBacklogViewState(this.isExpanded, this.items.length);
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Row() {
          Text(this.getViewState().expandSymbol)
            .fontSize(12)
            .fontColor(this.getPalette().textTertiary)
            .margin({ right: 8 })

          Text('💡 暂存池 / 想去的地方')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPalette().textPrimary)

          Blank()

          Text(this.getViewState().badgeText)
            .fontSize(12)
            .fontColor(this.getPalette().textSecondary)
            .backgroundColor(this.getPalette().cardBgSoft)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(12)
        }
        .layoutWeight(1)
        .onClick(() => {
          this.getUIContext().animateTo({ duration: 300, curve: Curve.FastOutSlowIn }, () => {
            this.onToggleExpand();
          });
        })

        if (this.getViewState().showMoveAllButton) {
          Button('一键加入日程')
            .height(30)
            .fontSize(11)
            .backgroundColor(this.getPalette().primary)
            .fontColor(Color.White)
            .borderRadius(15)
            .padding({ left: 10, right: 10 })
            .margin({ left: 8 })
            .onClick(() => {
              this.onMoveAllToSchedule();
            })
        }
      }
      .width('100%')
      .padding({ bottom: this.isExpanded ? 12 : 0 })

      if (this.isExpanded) {
        if (this.getViewState().showEmptyState) {
          Column() {
            Text('空空如也')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getPalette().textSecondary)

            Text('点右下角 + 号添加想去的地点')
              .fontSize(11)
              .fontColor(this.getPalette().textTertiary)
              .margin({ top: 4 })
          }
          .width('100%')
          .padding({ top: 14, bottom: 14 })
          .alignItems(HorizontalAlign.Center)
        } else {
          Column() {
            Scroll() {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(this.items, (item: TravelPlanItem, index: number) => {
                  Text(item.name)
                    .fontSize(13)
                    .fontColor(this.getPalette().textPrimary)
                    .backgroundColor(this.getPalette().cardBgSoft)
                    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .borderRadius(18)
                    .border({ width: 1, color: this.getPalette().divider })
                    .margin({ right: 8, bottom: 8 })
                    .constraintSize({ maxWidth: '78%' })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .onClick(() => {
                      this.onMoveToSchedule(item);
                    })
                }, (item: TravelPlanItem, index: number) => `${item.id ?? item.name}_${index}`)
              }
              .width('100%')
              .padding({ right: 4 })
            }
            .width('100%')
            .constraintSize({ maxHeight: '100%' })
            .scrollable(ScrollDirection.Vertical)
            .scrollBar(BarState.Auto)
            .nestedScroll({
              scrollForward: NestedScrollMode.SELF_FIRST,
              scrollBackward: NestedScrollMode.SELF_FIRST
            })
          }
          .width('100%')
          .constraintSize({ maxHeight: '100%' })
          .clip(true)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.getPalette().pageBg)
    .borderRadius({ bottomLeft: 0, bottomRight: 0 })
    .clip(true)
  }
}

