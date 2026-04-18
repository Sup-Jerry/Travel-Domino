import { PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { DateUtil } from '../common/utils/DateUtil';
import { PlanAppService } from '../viewmodel/PlanAppService';

const TRASH_AUTO_PURGE_MS = 7 * 24 * 60 * 60 * 1000;

export function resolveTrashAutoPurgeDiffMs(
  deleteTime: number | undefined,
  now: number,
  retentionMs: number = TRASH_AUTO_PURGE_MS
): number {
  if (!deleteTime) {
    return -1;
  }
  return deleteTime + retentionMs - now;
}

export function resolveTrashRemainingTimeText(
  deleteTime: number | undefined,
  now: number,
  retentionMs: number = TRASH_AUTO_PURGE_MS
): string {
  const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, retentionMs);
  if (diff <= 0) {
    return '即将清除';
  }

  const days = Math.floor(diff / (24 * 3600 * 1000));
  const hours = Math.floor((diff % (24 * 3600 * 1000)) / (3600 * 1000));

  if (days > 0) {
    return `${days}天 ${hours}小时 后自动清除`;
  }
  return `${hours}小时 后自动清除`;
}

@Entry
@Component
struct TrashPage {
  @State planList: PlanItem[] = [];
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly planService: PlanAppService = PlanAppService.getInstance();

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  onPageShow() {
    this.loadPlans();
  }

  async loadPlans() {
    this.planList = await this.planService.loadTrashPlans();
  }

  private getRemainingTimeText(deleteTime: number | undefined): string {
    return resolveTrashRemainingTimeText(deleteTime, Date.now());
  }

  handleHardDelete(item: PlanItem) {
    this.getUIContext().showAlertDialog({
      title: '⚠️ 彻底删除',
      message: '此操作将【永久销毁】该计划及其所有数据，无法恢复！\n\n确定要继续吗？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '我再想想',
        action: () => {
        }
      },
      secondaryButton: {
        value: '彻底删除',
        fontColor: '#D32F2F',
        action: async () => {
          await this.planService.hardDeletePlan(item.id);
          this.loadPlans();
        }
      }
    });
  }

  @Builder
  TrashSwipeMenu(item: PlanItem) {
    Row() {
      Button('恢复')
        .type(ButtonType.Normal)
        .backgroundColor('#4CAF50')
        .fontColor(Color.White)
        .width(70)
        .height('100%')
        .onClick(async () => {
          await this.planService.restorePlan(item.id);
          this.loadPlans();
        });

      Button('彻底删除')
        .type(ButtonType.Normal)
        .backgroundColor('#D32F2F')
        .fontColor(Color.White)
        .width(80)
        .height('100%')
        .onClick(() => {
          this.handleHardDelete(item);
        });
    }
    .height('100%');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('回收站')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 12 });
        }
        .width('100%')
        .padding({ left: 16, top: 10, bottom: 10, right: 16 })
        .backgroundColor(this.getThemePalette().cardBg);

        List({ space: 12 }) {
          ForEach(this.planList, (item: PlanItem) => {
            ListItem() {
              Row() {
                Column() {
                  Row() {
                    Text(item.title)
                      .fontSize(18)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.getThemePalette().textPrimary)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1);
                  }
                  .width('100%');

                  Text(`出发日期: ${DateUtil.formatPlanDate(item.startDate)}`)
                    .fontSize(12)
                    .fontColor(this.getThemePalette().primary)
                    .margin({ top: 4 });

                  Text(`将于 ${this.getRemainingTimeText(item.deleteTime)}`)
                    .fontSize(10)
                    .fontColor(this.getThemePalette().danger)
                    .margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.getThemePalette().cardBg)
              .borderRadius(12);
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.TrashSwipeMenu(item);
                },
                actionAreaDistance: 140
              }
            });
          });
          ListItem().height(12);
        }
        .layoutWeight(1)
        .padding({ top: 16, left: 16, right: 16, bottom: 90 });
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getThemePalette().pageBg);

      GlobalBottomNavBar({
        currentTab: 'trash',
        showCenterFab: false
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}

export function createTrashPageForTest(): Object {
  return new TrashPage(undefined, new LocalStorage()) as Object;
}









