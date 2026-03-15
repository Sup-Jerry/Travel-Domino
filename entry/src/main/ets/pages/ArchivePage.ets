import { PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { router } from '@kit.ArkUI';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { TipDialog } from './components/dialogs/TipDialog';
import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { DateUtil } from '../common/utils/DateUtil';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { AppTexts } from '../common/constants/AppTexts';

@Entry
@Component
struct ArchivePage {
  @State planList: PlanItem[] = [];
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly planService: PlanAppService = PlanAppService.getInstance();

  tipDialogController: CustomDialogController | null = null;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  onPageShow() {
    this.loadPlans();
  }

  async loadPlans() {
    this.planList = await this.planService.loadArchivedPlans();
  }

  async handleSoftDelete(item: PlanItem) {
    const isSkip = await PreferenceManager.getInstance().getValue(
      PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP,
      false
    );
    if (isSkip) {
      this.executeSoftDelete(item.id);
    } else {
      this.tipDialogController = new CustomDialogController({
        builder: TipDialog({
          title: '移入回收站',
          message: AppTexts.SOFT_DELETE_RECYCLE_TIP,
          storageKey: PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP,
          onConfirm: (): Promise<void> => this.executeSoftDelete(item.id)
        }),
        alignment: DialogAlignment.Center
      });
      this.tipDialogController.open();
    }
  }

  async executeSoftDelete(planId: number) {
    await this.planService.softDeletePlan(planId);
    this.loadPlans();
  }

  async handleActivate(item: PlanItem) {
    await this.planService.activatePlan(item.id);
    this.loadPlans();
  }

  @Builder
  ArchiveSwipeMenu(item: PlanItem) {
    Row() {
      Button('激活')
        .type(ButtonType.Normal)
        .backgroundColor('#2196F3')
        .fontColor(Color.White)
        .width(70)
        .height('100%')
        .onClick(async () => {
          await this.handleActivate(item);
        });

      Button('删除')
        .type(ButtonType.Normal)
        .backgroundColor('#F44336')
        .fontColor(Color.White)
        .width(70)
        .height('100%')
        .onClick(() => {
          this.handleSoftDelete(item);
        });
    }
    .height('100%');
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('归档箱')
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

                    Text(' 已归档 ')
                      .fontSize(10)
                      .fontColor('#FFF')
                      .backgroundColor('#B0B0B0')
                      .borderRadius(4)
                      .padding(2)
                      .margin({ left: 8 })
                      .flexShrink(0);
                  }
                  .width('100%');

                  Text(`出发日期: ${DateUtil.formatPlanDate(item.startDate)}`)
                    .fontSize(12)
                    .fontColor(this.getThemePalette().primary)
                    .margin({ top: 4 });

                  Text(`创建于: ${DateUtil.formatLocalDate(item.createdAt)}`)
                    .fontSize(10)
                    .fontColor(this.getThemePalette().textTertiary)
                    .margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1);

                Blank();

                Text('进入 >')
                  .fontSize(14)
                  .fontColor(this.getThemePalette().textSecondary)
                  .margin({ left: 8 });
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.getThemePalette().cardBg)
              .borderRadius(12)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/Index',
                  params: { planId: item.id, title: item.title }
                });
              });
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.ArchiveSwipeMenu(item);
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
        currentTab: 'archive',
        showCenterFab: false
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}







