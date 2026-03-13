import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RdbHelper } from '../common/utils/RdbHelper';
import { notificationManager } from '@kit.NotificationKit';
import notification from '@ohos.notification';
import wantAgent, { WantAgent } from '@ohos.app.ability.wantAgent';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { TrafficEngine } from '../model/logic/TrafficEngine';
import { bundleManager } from '@kit.AbilityKit';
import { AMap, MapsInitializer, MapView, MapViewManager } from '@amap/amap_lbs_map3d';
import {
  AMapPrivacyShowStatus,
  AMapPrivacyAgreeStatus,
  AMapPrivacyInfoStatus
} from '@amap/amap_lbs_common';
import { AppConfig } from '../common/utils/AppConfig';
import { DateUtil } from '../common/utils/DateUtil';
import { ThemeCenter, ThemeMode } from '../common/utils/ThemeCenter';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';

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

export default class EntryAbility extends UIAbility {
  private currentThemeMode: ThemeMode = 'system';
  private static lastNotificationFingerprint: string = '';
  private static lastNotificationTs: number = 0;

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

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void this.initThemeMode();
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
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');

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
    console.info('appId:' + appId);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');

    try {
      AppConfig.validateAmapSdkConfig();
      MapsInitializer.setApiKey(AppConfig.AMAP_SDK_API_KEY);
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

    MapViewManager.getInstance().registerMapViewCreatedCallback((mapview?: MapView, _mapViewName?: string) => {
      if (!mapview) {
        return;
      }
      const mapView = mapview;
      mapView.onCreate();
      mapView.getMapAsync((map) => {
        const aMap: AMap = map;
      });
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    RdbHelper.getInstance().init(this.context).then(() => {
      hilog.info(DOMAIN, TAG, '✅ Database initialized.');

      windowStage.loadContent('pages/PlanListPage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      });
    }).catch((err: object) => {
      hilog.error(DOMAIN, TAG, `Database init failed: ${JSON.stringify(err)}`);
      windowStage.loadContent('pages/PlanListPage');
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

  public static async updateScheduleNotification(title: string, content: string): Promise<void> {
    const fingerprint = `${title}__${content}`;
    if (EntryAbility.lastNotificationFingerprint === fingerprint) {
      EntryAbility.lastNotificationTs = Date.now();
      hilog.info(DOMAIN, TAG, '[NOTIFY][dedupe_skip] same content, skip publish');
      return;
    }
    try {
      const launchWantAgent = await EntryAbility.buildLaunchWantAgent();
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

  private static async buildLaunchWantAgent(): Promise<WantAgent | null> {
    try {
      const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(flag);
      const launchWant: Want = {
        bundleName: bundleInfo.name,
        abilityName: 'EntryAbility'
      };
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
}
