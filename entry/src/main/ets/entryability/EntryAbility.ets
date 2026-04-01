import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RdbHelper } from '../common/utils/RdbHelper';
import { notificationManager } from '@kit.NotificationKit';
import notification from '@ohos.notification';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { TrafficEngine } from '../infrastructure/services/TrafficEngine';
import { bundleManager } from '@kit.AbilityKit';
import { MapsInitializer, MapView, MapViewManager } from '@amap/amap_lbs_map3d';
import {
  AMapPrivacyShowStatus,
  AMapPrivacyAgreeStatus,
  AMapPrivacyInfoStatus
} from '@amap/amap_lbs_common';
import { AppConfig } from '../common/utils/AppConfig';
import { DateUtil } from '../common/utils/DateUtil';
import { ThemeCenter, ThemeMode } from '../common/utils/ThemeCenter';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { AppStartupCoordinator } from '../infrastructure/auth/AppStartupCoordinator';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

interface AbilityConfiguration {
  colorMode: number;
}

interface LaunchWantAgentInfo {
  wants: Want[];
  operationType: wantAgent.OperationType;
  requestCode: number;
  wantAgentFlags: wantAgent.WantAgentFlags[];
}

interface NotificationNavPayload {
  planId: number;
  eventId: number;
  forceCompanionMode: boolean;
}

export default class EntryAbility extends UIAbility {
  private currentThemeMode: ThemeMode = 'system';
  private static lastNotificationFingerprint: string = '';
  private static lastNotificationTs: number = 0;
  private readonly startupCoordinator: AppStartupCoordinator = AppStartupCoordinator.getInstance();

  private async initThemeMode(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();
      await pref.init(this.context);
      const saved = ThemeCenter.normalizeThemeMode(await pref.getThemeMode());
      this.currentThemeMode = saved;
      ThemeCenter.applyThemeMode(this.context, saved);
      hilog.info(DOMAIN, TAG, `Theme initialized: ${saved}`);
    } catch (err) {
      this.currentThemeMode = 'system';
      ThemeCenter.applyThemeMode(this.context, 'system');
      hilog.error(DOMAIN, TAG, `Theme init failed, fallback system: ${JSON.stringify(err)}`);
    }
  }

  private async bootstrapUserContext(): Promise<void> {
    const startup = await this.startupCoordinator.checkStartupAuth();
    if (startup.success && startup.data) {
      const accountId = startup.data.accountId || '';
      hilog.info(DOMAIN, TAG, `[LOGIN_TRACE][bootstrap] authenticated accountId=${accountId}`);
      return;
    }
    hilog.info(DOMAIN, TAG, `[LOGIN_TRACE][bootstrap] unauthenticated code=${startup.code}`);
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void this.initThemeMode();
    void this.bootstrapUserContext();
    AppStorage.setOrCreate(AppStorageKeys.THEME_MODE, 'system');
    AppStorage.setOrCreate(AppStorageKeys.EFFECTIVE_THEME, 'light');
    AppStorage.setOrCreate(AppStorageKeys.GLOBAL_TIME_DISPLAY_MODE, 0);
    AppStorage.setOrCreate(AppStorageKeys.PLANNING_TIME_DISPLAY_MODE, 0);
    AppStorage.setOrCreate(AppStorageKeys.COMPANION_TIME_DISPLAY_MODE, 0);
    AppStorage.setOrCreate('lastAddItemMode', 0);
    AppStorage.setOrCreate(AppStorageKeys.ARRIVAL_REMINDER_SEQ, 0);
    AppStorage.setOrCreate(AppStorageKeys.ARRIVAL_REMINDER_PAYLOAD, '');
    AppStorage.setOrCreate(AppStorageKeys.ARRIVAL_LIVE_ACTIVITY_SEQ, 0);
    AppStorage.setOrCreate(AppStorageKeys.ARRIVAL_LIVE_ACTIVITY_PAYLOAD, '');
    AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_SEQ, 0);
    AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
    this.handleNotificationLaunchWant(want);

    try {
      const appContext = this.context.getApplicationContext();
      TrafficEngine.getInstance().initialize(appContext);
      hilog.info(DOMAIN, TAG, '[LIFECYCLE_GUARD] TrafficEngine initialized with ApplicationContext.');
    } catch (err) {
      hilog.error(DOMAIN, TAG, '[LIFECYCLE_GUARD] TrafficEngine init failed: %{public}s', JSON.stringify(err));
    }

    // 验收辅助日志：用于确认 DateUtil 跨月/跨年判断修复已生效。
    DateUtil.logBoundarySelfCheck();

    const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO;
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(flag);
    const appId = bundleInfo.signatureInfo.appId;
    hilog.info(DOMAIN, TAG, `[LOGIN_TRACE][runtime] bundle=${bundleInfo.name}, appId=${appId}`);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    try {
      const sdkKeyLength = AppConfig.AMAP_SDK_API_KEY.trim().length;
      hilog.info(DOMAIN, TAG, `[MAP_INIT][config] sdkKeyConfigured=${sdkKeyLength > 0}, sdkKeyLen=${sdkKeyLength}`);
      AppConfig.validateAmapSdkConfig();
      MapsInitializer.setApiKey(AppConfig.AMAP_SDK_API_KEY);
      hilog.info(DOMAIN, TAG, '[MAP_INIT][set_api_key] success');
    } catch (error) {
      hilog.error(DOMAIN, TAG, `地图 SDK Key 配置无效: ${JSON.stringify(error)}`);
    }

    MapsInitializer.updatePrivacyShow(
      AMapPrivacyShowStatus.DidShow,
      AMapPrivacyInfoStatus.DidContain,
      this.context
    );

    MapsInitializer.updatePrivacyAgree(
      AMapPrivacyAgreeStatus.DidAgree,
      this.context
    );

    MapViewManager.getInstance().registerMapViewCreatedCallback((mapview?: MapView, mapViewName?: string) => {
      if (!mapview) {
        return;
      }
      // MapView 生命周期由 MapViewComponent/页面自身管理，避免在 Ability 层重复初始化导致渲染异常。
      hilog.info(DOMAIN, TAG, `[MAP_INIT][map_created_callback] name=${mapViewName ?? ''}`);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleNotificationLaunchWant(want);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    RdbHelper.getInstance().init(this.context).then(() => {
      hilog.info(DOMAIN, TAG, '✅ Database initialized.');

      windowStage.loadContent('pages/AuthGatePage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      });
    }).catch((err: object) => {
      hilog.error(DOMAIN, TAG, `Database init failed: ${JSON.stringify(err)}`);
      windowStage.loadContent('pages/AuthGatePage');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
    if (this.currentThemeMode === 'system') {
      const colorMode = ThemeCenter.readColorModeFromContext(this.context);
      const effective = ThemeCenter.resolveEffectiveTheme('system', colorMode);
      ThemeCenter.syncThemeToStorage('system', effective);
    }
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }

  onConfigurationUpdate(config: AbilityConfiguration): void {
    PreferenceManager.getInstance().getThemeMode().then((modeText: string) => {
      const mode = ThemeCenter.normalizeThemeMode(modeText);
      this.currentThemeMode = mode;
      const effective = ThemeCenter.resolveEffectiveTheme(mode, config.colorMode);
      ThemeCenter.syncThemeToStorage(mode, effective);
      hilog.info(DOMAIN, TAG, `Theme sync on configuration update: mode=${mode}, effective=${effective}`);
    }).catch((err: object) => {
      const effective = ThemeCenter.resolveEffectiveTheme(this.currentThemeMode, config.colorMode);
      ThemeCenter.syncThemeToStorage(this.currentThemeMode, effective);
      hilog.error(DOMAIN, TAG, `Theme sync fallback on configuration update: ${JSON.stringify(err)}`);
    });
  }

  public static async updateScheduleNotification(
    title: string,
    content: string,
    targetPlanId?: number,
    targetEventId?: number,
    forceCompanionMode?: boolean
  ): Promise<void> {
    const routeFingerprint = (targetPlanId ?? 0) > 0
      ? `${targetPlanId}:${targetEventId ?? -1}:${forceCompanionMode === true ? 1 : 0}`
      : 'none';
    const fingerprint = `${title}__${content}__${routeFingerprint}`;
    if (EntryAbility.lastNotificationFingerprint === fingerprint) {
      EntryAbility.lastNotificationTs = Date.now();
      hilog.info(DOMAIN, TAG, '[NOTIFY][dedupe_skip] same content, skip publish');
      return;
    }
    try {
      const launchWantAgent = await EntryAbility.buildLaunchWantAgent(targetPlanId, targetEventId, forceCompanionMode);
      const request: notificationManager.NotificationRequest = {
        id: 1001,
        isOngoing: true,
        isUnremovable: true,
        tapDismissed: false,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: { title: title, text: content }
        },
        slotType: notificationManager.SlotType.OTHER_TYPES as number as notification.SlotType
      };
      if (launchWantAgent) {
        request.wantAgent = launchWantAgent;
      }
      await notificationManager.publish(request);
      EntryAbility.lastNotificationFingerprint = fingerprint;
      EntryAbility.lastNotificationTs = Date.now();
    } catch (error) {
      hilog.error(DOMAIN, TAG, `updateScheduleNotification failed: ${JSON.stringify(error)}`);
      throw new Error(`publish notification failed: ${JSON.stringify(error)}`);
    }
  }

  private static async buildLaunchWantAgent(
    targetPlanId?: number,
    targetEventId?: number,
    forceCompanionMode?: boolean
  ): Promise<WantAgent | null> {
    try {
      const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(flag);
      const launchWant: Want = {
        bundleName: bundleInfo.name,
        abilityName: 'EntryAbility'
      };
      if ((targetPlanId ?? 0) > 0) {
        const parameters: Record<string, Object> = {};
        parameters['fromNotification'] = true;
        parameters['targetPlanId'] = targetPlanId as number;
        parameters['targetEventId'] = (targetEventId ?? -1) > 0 ? (targetEventId as number) : -1;
        parameters['forceCompanionMode'] = forceCompanionMode === true;
        launchWant.parameters = parameters;
      }
      const op: LaunchWantAgentInfo = {
        wants: [launchWant],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 1001,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      return await wantAgent.getWantAgent(op);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `buildLaunchWantAgent failed: ${JSON.stringify(error)}`);
      return null;
    }
  }

  private handleNotificationLaunchWant(want: Want): void {
    try {
      const parameters = want.parameters as Record<string, Object> | undefined;
      if (!parameters) {
        return;
      }
      const fromNotification = parameters['fromNotification'] === true;
      if (!fromNotification) {
        return;
      }
      const planId = Number(parameters['targetPlanId']);
      if (!Number.isFinite(planId) || planId <= 0) {
        return;
      }
      const eventId = Number(parameters['targetEventId']);
      const forceCompanionMode = parameters['forceCompanionMode'] === true;
      const payload: NotificationNavPayload = {
        planId: planId,
        eventId: Number.isFinite(eventId) && eventId > 0 ? eventId : -1,
        forceCompanionMode: forceCompanionMode
      };
      const nextSeq = (AppStorage.get<number>(AppStorageKeys.NOTIFICATION_NAV_SEQ) ?? 0) + 1;
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, JSON.stringify(payload));
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_SEQ, nextSeq);
      hilog.info(DOMAIN, TAG, `[NOTIFY][tap_route] planId=${payload.planId}, eventId=${payload.eventId}, companion=${payload.forceCompanionMode}`);
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `[NOTIFY][tap_route_failed] reason=${JSON.stringify(error)}`);
    }
  }
}


