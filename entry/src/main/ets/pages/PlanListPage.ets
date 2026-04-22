import { PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { CreatePlanDialog } from './components/dialogs/CreatePlanDialog';
import { TipDialog } from './components/dialogs/TipDialog';
import { PlanShareDialog } from './components/dialogs/PlanShareDialog';
import { PlanImportDialog } from './components/dialogs/PlanImportDialog';
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
import { AuthFacade } from '../infrastructure/auth/AuthFacade';
import { CompactPlanSerializer, SharePlanMetaInput } from '../domain/serializers/CompactPlanSerializer';
import { PlanSerializer } from '../domain/serializers/PlanSerializer';
import { ShareEventItem } from '../domain/services/PlanShareImageService';
import { TravelPlanItem } from '../model/interface/IStandardEvent';

interface NotificationNavPayload {
  planId: number;
  eventId: number;
  forceCompanionMode: boolean;
}

interface ShareDialogPayload {
  planId: number;
  planTitle: string;
  startDate: number;
  endDate: number;
  totalDays: number;
  totalEvents: number;
  events: ShareEventItem[];
  compressedJson: string;
}

const MAX_SHARE_EVENT_COUNT = 50;

export function canPlanListRepromptPermission(
  now: number,
  lastPromptAt: number,
  hasPromptedBefore: boolean,
  cooldownMs: number
): boolean {
  if (!hasPromptedBefore) {
    return true;
  }
  return now - lastPromptAt >= cooldownMs;
}

export function resolvePlanListShareStartTime(event: TravelPlanItem): string {
  const pureTime = DateUtil.extractPureTime(event.fixedStartTime || event.computedStartTime || '');
  if (DateUtil.isValidTimeString(pureTime)) {
    return pureTime;
  }
  return '--:--';
}

export function resolvePlanListShareEndTime(event: TravelPlanItem, durationMinutes: number): string {
  const startTime = resolvePlanListShareStartTime(event);
  if (startTime === '--:--') {
    return '--:--';
  }
  const calculated = DateUtil.calculateEndTime(startTime, durationMinutes);
  const pure = DateUtil.extractPureTime(calculated);
  return DateUtil.isValidTimeString(pure) ? pure : '--:--';
}

export function resolvePlanListShareIcon(event: TravelPlanItem): string {
  if (event.priority === 1) {
    return '⭐';
  }
  if (event.lockStatus === 1 || event.type === 'ANCHOR') {
    return '⏰';
  }
  return '📍';
}

export function resolvePlanListShareCategory(event: TravelPlanItem): string {
  if (event.lockStatus === 1 || event.type === 'ANCHOR') {
    return '固定行程';
  }
  return '灵活行程';
}

export function sortPlanListShareEvents(events: TravelPlanItem[]): TravelPlanItem[] {
  return events.slice().sort((left: TravelPlanItem, right: TravelPlanItem) => {
    const leftDay = Number(left.dayOffset ?? 0);
    const rightDay = Number(right.dayOffset ?? 0);
    if (leftDay !== rightDay) {
      return leftDay - rightDay;
    }
    return Number(left.sortOrder ?? 0) - Number(right.sortOrder ?? 0);
  });
}

export function buildPlanListShareEventItems(events: TravelPlanItem[]): ShareEventItem[] {
  const sorted = sortPlanListShareEvents(events);
  return sorted.map((event: TravelPlanItem): ShareEventItem => {
    const durationMinutes = Number.isFinite(Number(event.duration)) ? Math.max(0, Math.floor(Number(event.duration))) : 0;
    const durationHoursRaw = durationMinutes / 60;
    const durationHours = Math.round(durationHoursRaw * 10) / 10;
    const dayOffset = Number.isFinite(Number(event.dayOffset)) ? Math.max(0, Math.floor(Number(event.dayOffset))) : 0;
    return {
      name: event.name && event.name.trim().length > 0 ? event.name.trim() : '未命名地点',
      dayOffset: dayOffset,
      startTime: resolvePlanListShareStartTime(event),
      endTime: resolvePlanListShareEndTime(event, durationMinutes),
      duration: durationHours > 0 ? durationHours : 0.5,
      icon: resolvePlanListShareIcon(event),
      location: event.address && event.address.trim().length > 0 ? event.address.trim() : '待补充地点',
      category: resolvePlanListShareCategory(event)
    };
  });
}

@Entry
@Component
struct PlanListPage {
  @State planList: PlanItem[] = [];
  @State isRefreshing: boolean = false;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  @StorageLink('NotificationNavSeq') @Watch('onNotificationNavSignal') notificationNavSeq: number = 0;
  private arrivalReminderUnsubscribe: (() => void) | null = null;
  @State exportJsonText: string = '';
  @State isArrivalDialogOpen: boolean = false;
  private arrivalVm: TimelineViewModel = new TimelineViewModel();
  private readonly planService: PlanAppService = PlanAppService.getInstance();
  private readonly arrivalCoordinator: ArrivalReminderCoordinator = ArrivalReminderCoordinator.getInstance();
  private readonly authFacade: AuthFacade = AuthFacade.getInstance();
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
    const hostContext = this.getUIContext().getHostContext() as common.Context;
    this.authFacade.bindContext(hostContext);
    if (!this.authFacade.getCurrentSession()) {
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
    return canPlanListRepromptPermission(now, lastPromptAt, hasPromptedBefore, this.permissionRepromptCooldownMs);
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

  private openExportDialog(payload: ShareDialogPayload): void {
    this.exportJsonDialogController = new CustomDialogController({
      builder: PlanShareDialog({
        planId: payload.planId,
        planTitle: payload.planTitle,
        startDate: payload.startDate,
        endDate: payload.endDate,
        totalDays: payload.totalDays,
        totalEvents: payload.totalEvents,
        events: payload.events,
        compressedJson: payload.compressedJson
      }),
      alignment: DialogAlignment.Center
    });
    this.exportJsonDialogController.open();
  }

  private convertToShareEvents(events: TravelPlanItem[]): ShareEventItem[] {
    return buildPlanListShareEventItems(events);
  }

  private openImportDialog(): void {
    this.importJsonDialogController = new CustomDialogController({
      builder: PlanImportDialog({
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
      const parsed = PlanSerializer.deserializePlan(json);
      const sortedEvents = this.sortEventsForShare(parsed.events);
      const shareSourceEvents = sortedEvents.length > MAX_SHARE_EVENT_COUNT
        ? sortedEvents.slice(0, MAX_SHARE_EVENT_COUNT)
        : sortedEvents;
      if (sortedEvents.length > MAX_SHARE_EVENT_COUNT) {
        this.safeShowToast(`分享最多携带 ${MAX_SHARE_EVENT_COUNT} 条事件，已自动截断`);
      }

      const shareEvents = this.convertToShareEvents(shareSourceEvents);
      const maxDayOffset = shareEvents.reduce((max: number, current: ShareEventItem) =>
        Math.max(max, current.dayOffset), 0);
      const totalDays = maxDayOffset + 1;
      const startDate = parsed.plan.startDate;
      const endDate = startDate + maxDayOffset * 24 * 60 * 60 * 1000;
      const sharePlanMeta: SharePlanMetaInput = {
        title: parsed.plan.title,
        startDate: parsed.plan.startDate,
        status: parsed.plan.status,
        enableAutoAmapRoute: parsed.plan.enableAutoAmapRoute
      };
      const compressed = CompactPlanSerializer.compressForShare(sharePlanMeta, shareSourceEvents);
      this.exportJsonText = compressed;
      this.openExportDialog({
        planId: item.id,
        planTitle: parsed.plan.title,
        startDate: startDate,
        endDate: endDate,
        totalDays: totalDays,
        totalEvents: shareSourceEvents.length,
        events: shareEvents,
        compressedJson: compressed
      });
    } catch (error) {
      hilog.warn(0x0000, 'PlanListPage', `[PLAN_JSON][export_failed] planId=${item.id}, reason=${JSON.stringify(error)}`);
      this.safeShowToast('导出失败，请稍后重试');
    }
  }

  private sortEventsForShare(events: TravelPlanItem[]): TravelPlanItem[] {
    return sortPlanListShareEvents(events);
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

  private async handlePullRefresh(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    try {
      await this.loadPlans();
      await this.planService.requestArrivalCheckNow('home_manual_refresh');
      this.arrivalCoordinator.consumeOnHome({
        isDialogOpen: this.isArrivalDialogOpen,
        resolvePlanTitle: (planId: number): string => {
          const plan = this.planList.find((item: PlanItem) => item.id === planId);
          return plan ? plan.title : '行程详情';
        },
        onShow: (payload: ArrivalReminderPayload, title: string): void => {
          this.showArrivalReminderOnHome(payload, title);
        }
      });
    } finally {
      this.isRefreshing = false;
    }
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
      Button('分享')
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
            Button('导入计划')
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

        Refresh({ refreshing: this.isRefreshing }) {
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
        }
        .onRefreshing(() => {
          void this.handlePullRefresh();
        })
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

export function createPlanListPageForTest(): Object {
  return new PlanListPage(undefined, {} as LocalStorage);
}















