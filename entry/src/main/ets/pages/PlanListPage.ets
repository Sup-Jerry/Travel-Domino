import { PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { CreatePlanDialog } from './components/dialogs/CreatePlanDialog';
import { TipDialog } from './components/dialogs/TipDialog';
import { PlanJsonExportDialog } from './components/dialogs/PlanJsonExportDialog';
import { PlanJsonImportDialog } from './components/dialogs/PlanJsonImportDialog';
import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlanJsonImportCancelToken, PlanImportExportService } from '../infrastructure/services/PlanImportExportService';
import { ArrivalReminderPayload } from '../infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../infrastructure/services/ArrivalReminderCoordinator';
import { TimelineViewModel } from '../viewmodel/TimelineViewModel';
import { PlanAppService } from '../viewmodel/PlanAppService';
import { DateUtil } from '../common/utils/DateUtil';
import { AppTexts } from '../common/constants/AppTexts';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { AuthSessionStore } from '../infrastructure/auth/AuthSessionStore';

interface NotificationNavPayload {
  planId: number;
  eventId: number;
  forceCompanionMode: boolean;
}

@Entry
@Component
struct PlanListPage {
  @State planList: PlanItem[] = [];
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  @StorageLink('NotificationNavSeq') @Watch('onNotificationNavSignal') notificationNavSeq: number = 0;
  private arrivalReminderUnsubscribe: (() => void) | null = null;
  @State exportJsonText: string = '';
  @State isArrivalDialogOpen: boolean = false;
  private arrivalVm: TimelineViewModel = new TimelineViewModel();
  private readonly planService: PlanAppService = PlanAppService.getInstance();
  private readonly arrivalCoordinator: ArrivalReminderCoordinator = ArrivalReminderCoordinator.getInstance();
  private lastNotifyPermissionPromptAt: number = 0;
  private lastLocationPermissionPromptAt: number = 0;
  private readonly permissionRepromptCooldownMs: number = 10 * 60 * 1000;

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[TOAST_FAIL] reason=${JSON.stringify(error)}`);
    }
  }

  createDialogController: CustomDialogController = new CustomDialogController({
    builder: CreatePlanDialog({
      onCreatePlan: async (title: string, startDate: number): Promise<number> => {
        return this.planService.createPlan(title, startDate);
      },
      onPlanCreated: (planId: number, title: string) => {
        void this.loadPlans();
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/Index',
          params: {
            planId: planId,
            title: title,
            isNewPlan: true
          }
        });
      }
    }),
    alignment: DialogAlignment.Bottom,
    offset: { dx: 0, dy: -20 }
  });

  tipDialogController: CustomDialogController | null = null;
  exportJsonDialogController: CustomDialogController | null = null;
  importJsonDialogController: CustomDialogController | null = null;

  onPageShow() {
    if (!AuthSessionStore.getAccessToken()) {
      void this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    void this.loadPlans();
    this.startGlobalArrivalEngine();
    this.bindArrivalReminderSubscription();
    this.consumeNotificationNavRoute();
    void this.ensureArrivalPermissionPromptOnFirstEntry();
  }

  onNotificationNavSignal(): void {
    this.consumeNotificationNavRoute();
  }

  aboutToDisappear() {
    if (this.arrivalReminderUnsubscribe) {
      this.arrivalReminderUnsubscribe();
      this.arrivalReminderUnsubscribe = null;
    }
    this.planService.stopArrivalEngine();
  }

  private startGlobalArrivalEngine(): void {
    try {
      const hostContext = this.getUIContext().getHostContext() as Context;
      this.planService.startArrivalEngine(0, this.arrivalVm, hostContext);
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[ARRIVAL][home_engine_start_failed] reason=${JSON.stringify(error)}`);
    }
  }

  private bindArrivalReminderSubscription(): void {
    if (this.arrivalReminderUnsubscribe) {
      this.arrivalReminderUnsubscribe();
      this.arrivalReminderUnsubscribe = null;
    }
    this.arrivalReminderUnsubscribe = this.arrivalCoordinator.subscribePlan('*', {
      isDialogOpen: (): boolean => this.isArrivalDialogOpen,
      resolvePlanTitle: (planId: number): string => {
        const plan = this.planList.find((item: PlanItem) => item.id === planId);
        return plan ? plan.title : '行程详情';
      },
      onShowHome: (payload: ArrivalReminderPayload, title: string): void => {
        this.showArrivalReminderOnHome(payload, title);
      }
    });
  }

  private showArrivalReminderOnHome(payload: ArrivalReminderPayload, title: string): void {
    this.isArrivalDialogOpen = true;
    this.getUIContext().showAlertDialog({
      title: '到达提醒',
      message: `你已到达【${payload.placeName}】附近（约${Math.max(1, payload.distanceMeters)}米）\n来自计划：${title}`,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '稍后',
        action: () => {
          this.isArrivalDialogOpen = false;
          this.arrivalCoordinator.acknowledge(payload.eventId, 'dismiss');
        }
      },
      secondaryButton: {
        value: '开始打卡',
        action: () => {
          this.isArrivalDialogOpen = false;
          this.arrivalCoordinator.acknowledge(payload.eventId, 'open_page');
          this.getUIContext().getRouter().pushUrl({
            url: 'pages/Index',
            params: {
              planId: payload.planId,
              title: title,
              isNewPlan: false,
              autoStartFromReminder: true,
              reminderEventId: payload.eventId
            }
          });
        }
      }
    });
  }

  private consumeNotificationNavRoute(): void {
    const raw = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? '';
    if (!raw || raw.length <= 0) {
      return;
    }
    let payload: NotificationNavPayload | null = null;
    try {
      payload = JSON.parse(raw) as NotificationNavPayload;
    } catch (_error) {
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
      return;
    }
    if (!payload || !Number.isFinite(payload.planId) || payload.planId <= 0) {
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
      return;
    }
    const navPayload = payload;
    const plan = this.planList.find((item: PlanItem) => item.id === navPayload.planId);
    const title = plan ? plan.title : '行程详情';
    AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/Index',
        params: {
          planId: navPayload.planId,
          title: title,
          isNewPlan: false,
          reminderEventId: navPayload.eventId > 0 ? navPayload.eventId : -1,
          forceCompanionMode: navPayload.forceCompanionMode === true
        }
      });
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[NOTIFY][tap_route_failed] reason=${JSON.stringify(error)}`);
    }
  }

  private async ensureArrivalPermissionPromptOnFirstEntry(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const promptState = await this.planService.getArrivalPromptState(hostContext);
      const now = Date.now();

      const notifyEnabled = await this.planService.isNotificationEnabled();
      if (!notifyEnabled && this.canRepromptPermission(now, this.lastNotifyPermissionPromptAt, promptState.notifyPrompted)) {
        if (!promptState.notifyPrompted) {
          await this.planService.markNotifyPrompted(hostContext);
        }
        this.lastNotifyPermissionPromptAt = now;
        await this.ensureNotificationPermissionPrompt(hostContext);
      }

      const locationGranted = await this.planService.isLocationPermissionGranted();
      if (!locationGranted && this.canRepromptPermission(now, this.lastLocationPermissionPromptAt, promptState.locationPrompted)) {
        if (!promptState.locationPrompted) {
          await this.planService.markLocationPrompted(hostContext);
        }
        this.lastLocationPermissionPromptAt = now;
        await this.ensureLocationPermissionPrompt(hostContext);
      }
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[ARRIVAL][first_entry_prompt_failed] reason=${JSON.stringify(error)}`);
    }
  }

  private canRepromptPermission(now: number, lastPromptAt: number, hasPromptedBefore: boolean): boolean {
    if (!hasPromptedBefore) {
      return true;
    }
    return now - lastPromptAt >= this.permissionRepromptCooldownMs;
  }

  private async ensureNotificationPermissionPrompt(hostContext: common.UIAbilityContext): Promise<void> {
    try {
      const enabled = await this.planService.isNotificationEnabled();
      if (enabled) {
        return;
      }
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[ARRIVAL][notify_enabled_check_failed] reason=${JSON.stringify(error)}`);
      return;
    }

    this.getUIContext().showAlertDialog({
      title: '开启系统通知',
      message: '到达提醒依赖系统通知。检测到当前通知未开启，是否现在去开启？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '稍后',
        action: () => {}
      },
      secondaryButton: {
        value: '去开启',
        action: () => {
          this.planService.requestEnableNotification(hostContext).then(() => {
            this.safeShowToast('已发起通知授权请求');
          }).catch((error: Error) => {
            const reason = error.message || JSON.stringify(error);
            hilog.warn(0x0000, 'PlanListPage', `[ARRIVAL][notify_request_failed] reason=${reason}`);
            this.safeShowToast('拉起通知授权失败，请在系统设置中手动开启');
          });
        }
      }
    });
  }

  private async ensureLocationPermissionPrompt(hostContext: common.UIAbilityContext): Promise<void> {
    try {
      const granted = await this.planService.isLocationPermissionGranted();
      if (granted) {
        return;
      }
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[ARRIVAL][location_check_failed] reason=${JSON.stringify(error)}`);
      return;
    }

    this.getUIContext().showAlertDialog({
      title: '开启定位权限',
      message: '到达提醒依赖实时定位。检测到当前定位权限未开启，是否现在去授权？',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '稍后',
        action: () => {}
      },
      secondaryButton: {
        value: '去授权',
        action: async () => {
          try {
            const granted = await this.planService.requestLocationPermissions(hostContext);
            if (granted) {
              this.safeShowToast('定位权限已授权');
            } else {
              this.safeShowToast('未获得定位权限，到达提醒可能无法触发');
            }
          } catch (error) {
            const reason = JSON.stringify(error);
            hilog.warn(0x0000, 'PlanListPage', `[ARRIVAL][location_request_failed] reason=${reason}`);
            this.safeShowToast('定位授权失败，请到系统设置手动开启');
          }
        }
      }
    });
  }

  private openExportDialog(): void {
    this.exportJsonDialogController = new CustomDialogController({
      builder: PlanJsonExportDialog({
        jsonText: this.exportJsonText
      }),
      alignment: DialogAlignment.Center
    });
    this.exportJsonDialogController.open();
  }

  private openImportDialog(): void {
    this.importJsonDialogController = new CustomDialogController({
      builder: PlanJsonImportDialog({
        onImport: async (jsonText: string, cancelToken: PlanJsonImportCancelToken): Promise<void> => {
          await this.importPlanFromJson(jsonText, cancelToken);
        }
      }),
      alignment: DialogAlignment.Center
    });
    this.importJsonDialogController.open();
  }

  private async exportPlanAsJson(item: PlanItem): Promise<void> {
    try {
      const json = await PlanImportExportService.exportPlanToJson(item.id);
      this.exportJsonText = json;
      this.openExportDialog();
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[PLAN_JSON][export_failed] planId=${item.id}, reason=${JSON.stringify(error)}`);
      this.safeShowToast('导出失败，请稍后重试');
    }
  }

  private async importPlanFromJson(jsonText: string, cancelToken: PlanJsonImportCancelToken): Promise<void> {
    try {
      const newPlanId = await PlanImportExportService.importPlanFromJson(jsonText, cancelToken);
      await this.loadPlans();
      this.safeShowToast(`导入成功（新计划ID: ${newPlanId}）`);
    } catch (error) {
      const reason = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.warn(0x0000, 'PlanListPage', `[PLAN_JSON][import_failed] reason=${reason}`);
      if (reason.includes('import_cancelled')) {
        this.safeShowToast('已取消导入');
        return;
      }
      this.safeShowToast('导入失败：数据格式不合法或内容超限');
    }
  }

  async loadPlans() {
    this.planList = await this.planService.loadVisiblePlans();
  }

  async handleArchive(item: PlanItem) {
    const isSkip = await PreferenceManager.getInstance().getValue(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, false);
    if (isSkip) {
      this.executeArchive(item.id);
    } else {
      this.tipDialogController = new CustomDialogController({
        builder: TipDialog({
          title: '归档说明',
          message: '归档后的计划将变为“只读模式”，不可再修改，但可以随时查看。\n\n您可以在归档箱中将其重新激活。',
          storageKey: PreferenceManager.KEY_HIDE_ARCHIVE_TIP,
          onConfirm: (): Promise<void> => this.executeArchive(item.id)
        }),
        alignment: DialogAlignment.Center
      });
      this.tipDialogController.open();
    }
  }

  async executeArchive(planId: number) {
    await this.planService.archivePlan(planId);
    void this.loadPlans();
  }

  async handleSoftDelete(item: PlanItem) {
    const isSkip = await PreferenceManager.getInstance().getValue(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, false);
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
    void this.loadPlans();
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
          void this.loadPlans();
        }
      }
    });
  }

  @Builder
  PlanSwipeMenu(item: PlanItem) {
    Row() {
      Button('导出')
        .type(ButtonType.Normal)
        .backgroundColor('#2196F3')
        .width(70)
        .height('100%')
        .onClick(() => {
          void this.exportPlanAsJson(item);
        });

      Button('归档')
        .type(ButtonType.Normal)
        .backgroundColor('#FF9800')
        .width(70)
        .height('100%')
        .onClick(() => {
          this.handleArchive(item);
        });

      Button('删除')
        .type(ButtonType.Normal)
        .backgroundColor('#F44336')
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
          Text('所有计划')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary)
            .margin({ top: 12 });

                    Blank();

          Row({ space: 8 }) {
            Button('导入JSON')
              .fontSize(12)
              .height(30)
              .backgroundColor('#007DFF')
              .fontColor(Color.White)
              .onClick(() => {
                this.openImportDialog();
              });
          }
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
                  }.width('100%');

                  Text(`出发日期: ${DateUtil.formatPlanDate(item.startDate)}`)
                    .fontSize(12).fontColor(this.getThemePalette().primary).margin({ top: 4 });

                  Text(`创建于: ${DateUtil.formatLocalDate(item.createdAt)}`)
                    .fontSize(10)
                    .fontColor(this.getThemePalette().textTertiary)
                    .margin({ top: 2 });
                }
                .alignItems(HorizontalAlign.Start).layoutWeight(1);

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
                  params: {
                    planId: item.id,
                    title: item.title,
                    isNewPlan: false
                  }
                });
              });
            }
            .swipeAction({
              end: {
                builder: () => {
                  this.PlanSwipeMenu(item);
                },
                actionAreaDistance: 210
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
        currentTab: 'home',
        showCenterFab: true,
        onCenterFabTap: () => {
          this.createDialogController.open();
        }
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}















