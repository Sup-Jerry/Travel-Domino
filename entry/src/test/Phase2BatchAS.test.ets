import { describe, expect, it } from '@ohos/hypium';
import { preferences, relationalStore } from '@kit.ArkData';
import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanEntity } from '../main/ets/model/entity/PlanEntity';
import { AvatarProfile } from '../main/ets/domain/auth/AvatarModels';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';
import { DEFAULT_WEATHER_USER_PREFERENCE } from '../main/ets/domain/services/WeatherModels';

class PreferenceStoreMockAS {
  private readonly values: Map<string, Object> = new Map<string, Object>();
  putCount: number = 0;
  getCount: number = 0;
  flushCount: number = 0;
  putErrorMessage: string = '';
  getErrorMessage: string = '';
  flushErrorMessage: string = '';

  setRaw(key: string, value: Object): void {
    this.values.set(key, value);
  }

  getRaw(key: string): Object | undefined {
    return this.values.get(key);
  }

  async put(key: string, value: Object): Promise<void> {
    this.putCount++;
    if (this.putErrorMessage.length > 0) {
      throw new Error(this.putErrorMessage);
    }
    this.values.set(key, value);
  }

  async get(key: string, defaultValue: Object): Promise<Object> {
    this.getCount++;
    if (this.getErrorMessage.length > 0) {
      throw new Error(this.getErrorMessage);
    }
    const value = this.values.get(key);
    return value === undefined ? defaultValue : value;
  }

  async flush(): Promise<void> {
    this.flushCount++;
    if (this.flushErrorMessage.length > 0) {
      throw new Error(this.flushErrorMessage);
    }
  }
}

class PreferencesHooksAS {
  private readonly originGetPreferences: Object;

  constructor() {
    this.originGetPreferences = preferences.getPreferences as Object;
  }

  setGetPreferences(fn: (context: Object, storeName: string) => Promise<Object>): void {
    preferences.getPreferences = fn as never;
  }

  restore(): void {
    preferences.getPreferences = this.originGetPreferences as never;
  }
}

class ApplicationContextMockAS {
  readonly setColorModeCalls: number[] = [];
  private readonly failingModes: number[] = [];

  constructor(failingModes: number[] = []) {
    this.failingModes.push(...failingModes);
  }

  setColorMode(mode: number): void {
    this.setColorModeCalls.push(mode);
    if (this.failingModes.indexOf(mode) >= 0) {
      throw new Error(`set_color_mode_failed_${mode}`);
    }
  }
}

interface ThemeConfigMockAS {
  colorMode: number;
}

class ThemeContextMockAS {
  config?: ThemeConfigMockAS;
  private readonly applicationContext: ApplicationContextMockAS;

  constructor(colorMode: number | undefined, applicationContext?: ApplicationContextMockAS) {
    if (typeof colorMode === 'number') {
      const config: ThemeConfigMockAS = { colorMode: colorMode };
      this.config = config;
    }
    this.applicationContext = applicationContext || new ApplicationContextMockAS();
  }

  getApplicationContext(): ApplicationContextMockAS {
    return this.applicationContext;
  }
}

class RdbStoreMockAS {
  version: number = 1;
  readonly executeSqlCalls: string[] = [];
  failTokens: string[] = [];

  async executeSql(sql: string): Promise<void> {
    this.executeSqlCalls.push(sql);
    for (const token of this.failTokens) {
      if (sql.indexOf(token) >= 0) {
        throw new Error(`sql_failed_${token}`);
      }
    }
  }
}

class RdbErrorMockAS extends Error {
  code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

class RdbHooksAS {
  private readonly originGetRdbStore: Object;

  constructor() {
    this.originGetRdbStore = relationalStore.getRdbStore as Object;
  }

  setGetRdbStore(
    fn: (context: Object, config: Object, callback: (err: Object | null, store: Object | null) => void) => void
  ): void {
    relationalStore.getRdbStore = fn as never;
  }

  restore(): void {
    relationalStore.getRdbStore = this.originGetRdbStore as never;
  }
}

class AppConfigHooksAS {
  private readonly aiApiUrl: Object;
  private readonly amapWebApiKey: Object;
  private readonly amapSdkApiKey: Object;
  private readonly authApiBaseUrl: Object;

  constructor() {
    this.aiApiUrl = Reflect.get(AppConfig as Object, 'AI_API_URL') as Object;
    this.amapWebApiKey = Reflect.get(AppConfig as Object, 'AMAP_WEB_API_KEY') as Object;
    this.amapSdkApiKey = Reflect.get(AppConfig as Object, 'AMAP_SDK_API_KEY') as Object;
    this.authApiBaseUrl = Reflect.get(AppConfig as Object, 'AUTH_API_BASE_URL') as Object;
  }

  setAiApiUrl(value: Object): void {
    Reflect.set(AppConfig as Object, 'AI_API_URL', value);
  }

  setAmapWebApiKey(value: Object): void {
    Reflect.set(AppConfig as Object, 'AMAP_WEB_API_KEY', value);
  }

  setAmapSdkApiKey(value: Object): void {
    Reflect.set(AppConfig as Object, 'AMAP_SDK_API_KEY', value);
  }

  setAuthApiBaseUrl(value: Object): void {
    Reflect.set(AppConfig as Object, 'AUTH_API_BASE_URL', value);
  }

  restore(): void {
    Reflect.set(AppConfig as Object, 'AI_API_URL', this.aiApiUrl);
    Reflect.set(AppConfig as Object, 'AMAP_WEB_API_KEY', this.amapWebApiKey);
    Reflect.set(AppConfig as Object, 'AMAP_SDK_API_KEY', this.amapSdkApiKey);
    Reflect.set(AppConfig as Object, 'AUTH_API_BASE_URL', this.authApiBaseUrl);
  }
}

function attachPreferenceStoreAS(store: PreferenceStoreMockAS | null): PreferenceManager {
  const manager = PreferenceManager.getInstance();
  Reflect.set(manager as Object, 'pref', store);
  return manager;
}

function cloneDefaultUserProfileAS(): UserStrategyProfile {
  return {
    avgDensity: DEFAULT_USER_PROFILE.avgDensity,
    avgPace: DEFAULT_USER_PROFILE.avgPace,
    avgPreference: DEFAULT_USER_PROFILE.avgPreference,
    avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
    modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
    sampleCount: DEFAULT_USER_PROFILE.sampleCount,
    updatedAt: DEFAULT_USER_PROFILE.updatedAt,
    manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled === true,
    consistencyMatchCount: Number(DEFAULT_USER_PROFILE.consistencyMatchCount) > 0
      ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMatchCount))
      : 0,
    consistencyMismatchCount: Number(DEFAULT_USER_PROFILE.consistencyMismatchCount) > 0
      ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMismatchCount))
      : 0,
    lastConsistencyCheckAt: Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt) > 0
      ? Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt)
      : 0
  };
}

function resetThemeStorageAS(): void {
  AppStorage.setOrCreate(ThemeCenter.STORAGE_THEME_MODE, 'system');
  AppStorage.setOrCreate(ThemeCenter.STORAGE_EFFECTIVE_THEME, 'light');
}

function getThemeStorageValueAS(key: string): string {
  return String(AppStorage.get(key) || '');
}

function captureSyncErrorAS(action: () => void): string {
  let message = '';
  try {
    action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  return message;
}

async function captureAsyncErrorAS(action: () => Promise<void>): Promise<string> {
  let message = '';
  try {
    await action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  return message;
}

function resetRdbHelperStoreAS(): RdbHelper {
  const helper = RdbHelper.getInstance();
  Reflect.set(helper as Object, 'rdbStore', null);
  return helper;
}

export default function phase2BatchASTest() {
  describe('phase2BatchASTest', () => {
    it('normal: preference_manager_should_expose_singleton_and_roundtrip_values_after_init', 0, async () => {
      // Arrange
      const store = new PreferenceStoreMockAS();
      const managerA = attachPreferenceStoreAS(store);
      const managerB = PreferenceManager.getInstance();
      // Act
      await managerA.setValue('phase2_batch_as_key', 'phase2_batch_as_value');
      const loaded = await managerB.getValue('phase2_batch_as_key', '');
      // Assert
      expect(managerA === managerB).assertTrue();
      expect(String(loaded)).assertEqual('phase2_batch_as_value');
      expect(store.putCount).assertEqual(1);
      expect(store.flushCount).assertEqual(1);
      expect(store.getCount).assertEqual(1);
    });

    it('boundary: preference_manager_static_normalizers_should_clip_values_and_generate_safe_keys', 0, () => {
      // Arrange
      const blankAccountId = '   ';
      // Act
      const amapDisabled = PreferenceManager.normalizeAmapRouteApiEnabled(false);
      const minDurationLow = PreferenceManager.normalizeMinEventDuration(-10);
      const minDurationHigh = PreferenceManager.normalizeMinEventDuration(9999);
      const themeFallback = PreferenceManager.normalizeThemeMode('unexpected');
      const idleMinutes = PreferenceManager.normalizeIdleGapTriggerMinutes(999);
      const aiPoiLow = PreferenceManager.normalizeAiPoiCount(0, 4);
      const aiPoiHigh = PreferenceManager.normalizeAiPoiCount(20, 4);
      const aiPoiFallback = PreferenceManager.normalizeAiPoiCount('bad', 0);
      const weatherLow = PreferenceManager.normalizeWeatherPreferenceLevel(-5);
      const weatherHigh = PreferenceManager.normalizeWeatherPreferenceLevel(99);
      const avatarKey = PreferenceManager.buildAvatarProfileKey('');
      const profileKey = PreferenceManager.buildProfileCacheKey(blankAccountId);
      const cacheKey = PreferenceManager.buildAvatarCacheKey(blankAccountId);
      // Assert
      expect(amapDisabled).assertFalse();
      expect(minDurationLow).assertEqual(1);
      expect(minDurationHigh).assertEqual(720);
      expect(themeFallback).assertEqual('system');
      expect(idleMinutes).assertEqual(720);
      expect(aiPoiLow).assertEqual(1);
      expect(aiPoiHigh).assertEqual(12);
      expect(aiPoiFallback).assertEqual(1);
      expect(weatherLow).assertEqual(0);
      expect(weatherHigh).assertEqual(2);
      expect(avatarKey).assertEqual('avatarProfile:guest_local');
      expect(profileKey).assertEqual('profile_cache_guest_local');
      expect(cacheKey).assertEqual('avatar_cache_guest_local');
    });

    it('invalid: preference_manager_should_reject_value_access_before_pref_init', 0, async () => {
      // Arrange
      const manager = attachPreferenceStoreAS(null);
      // Act
      const writeMessage = await captureAsyncErrorAS(async () => {
        await manager.setValue('phase2_batch_as_invalid', 'x');
      });
      const readMessage = await captureAsyncErrorAS(async () => {
        await manager.getValue('phase2_batch_as_invalid', '');
      });
      // Assert
      expect(writeMessage).assertEqual('Preferences 未初始化，无法写入 key=phase2_batch_as_invalid');
      expect(readMessage).assertEqual('Preferences 未初始化，无法读取 key=phase2_batch_as_invalid');
    });

    it('normal: preference_manager_init_should_attach_store_from_preferences_module', 0, async () => {
      // Arrange
      const hooks = new PreferencesHooksAS();
      const store = new PreferenceStoreMockAS();
      const manager = attachPreferenceStoreAS(null);
      hooks.setGetPreferences(async (_context: Object, storeName: string): Promise<Object> => {
        expect(storeName).assertEqual('TravelDominoPrefs');
        return store as Object;
      });
      // Act
      await manager.init({} as common.Context);
      const attached = Reflect.get(manager as Object, 'pref') as Object;
      hooks.restore();
      // Assert
      expect(attached === (store as Object)).assertTrue();
    });

    it('conflict: preference_manager_should_wrap_pref_io_errors_and_keep_init_failure_non_throwing', 0, async () => {
      // Arrange
      const hooks = new PreferencesHooksAS();
      const store = new PreferenceStoreMockAS();
      store.putErrorMessage = 'put_failed_as';
      store.getErrorMessage = 'get_failed_as';
      const manager = attachPreferenceStoreAS(store);
      hooks.setGetPreferences(async (): Promise<Object> => {
        throw new Error('init_failed_as');
      });
      // Act
      await manager.init({} as common.Context);
      const writeMessage = await captureAsyncErrorAS(async () => {
        await manager.setValue('phase2_batch_as_conflict', 'x');
      });
      const readMessage = await captureAsyncErrorAS(async () => {
        await manager.getValue('phase2_batch_as_conflict', '');
      });
      hooks.restore();
      // Assert
      expect(writeMessage).assertEqual('Preference save failed: put_failed_as');
      expect(readMessage).assertEqual('Preference load failed: get_failed_as');
      expect(store.flushCount).assertEqual(0);
    });

    it('boundary: preference_manager_basic_accessors_should_normalize_switches_modes_and_minutes', 0, async () => {
      // Arrange
      const store = new PreferenceStoreMockAS();
      const manager = attachPreferenceStoreAS(store);
      // Act
      await manager.setAmapRouteApiEnabled(false);
      await manager.setMinEventDuration(9999);
      await manager.setThemeMode('unexpected');
      await manager.setIdleGapDetectionEnabled(true);
      await manager.setIdleGapTriggerMinutes(0);
      const storedAmap = store.getRaw(PreferenceManager.KEY_ENABLE_AMAP_ROUTE_API) === false;
      const storedMinDuration = Number(store.getRaw(PreferenceManager.KEY_MIN_EVENT_DURATION));
      const storedThemeMode = String(store.getRaw(PreferenceManager.KEY_THEME_MODE));
      const storedIdleGapEnabled = store.getRaw(PreferenceManager.KEY_IDLE_GAP_DETECTION_ENABLED) === true;
      const storedIdleGapMinutes = Number(store.getRaw(PreferenceManager.KEY_IDLE_GAP_TRIGGER_MINUTES));
      store.setRaw(PreferenceManager.KEY_ENABLE_AMAP_ROUTE_API, true as Object);
      store.setRaw(PreferenceManager.KEY_MIN_EVENT_DURATION, 'bad' as Object);
      store.setRaw(PreferenceManager.KEY_THEME_MODE, 'dark' as Object);
      store.setRaw(PreferenceManager.KEY_IDLE_GAP_DETECTION_ENABLED, 'not_bool' as Object);
      store.setRaw(PreferenceManager.KEY_IDLE_GAP_TRIGGER_MINUTES, 999 as Object);
      const amapEnabled = await manager.isAmapRouteApiEnabled();
      const minDuration = await manager.getMinEventDuration();
      const themeMode = await manager.getThemeMode();
      const idleGapEnabled = await manager.getIdleGapDetectionEnabled();
      const idleGapMinutes = await manager.getIdleGapTriggerMinutes();
      // Assert
      expect(storedAmap).assertTrue();
      expect(storedMinDuration).assertEqual(720);
      expect(storedThemeMode).assertEqual('system');
      expect(storedIdleGapEnabled).assertTrue();
      expect(storedIdleGapMinutes).assertEqual(1);
      expect(amapEnabled).assertTrue();
      expect(minDuration).assertEqual(30);
      expect(themeMode).assertEqual('dark');
      expect(idleGapEnabled).assertFalse();
      expect(idleGapMinutes).assertEqual(720);
    });

    it('normal: preference_manager_ai_poi_and_weather_preferences_should_roundtrip_with_clamp_and_swap', 0, async () => {
      // Arrange
      const store = new PreferenceStoreMockAS();
      const manager = attachPreferenceStoreAS(store);
      // Act
      await manager.setAiDailyPoiRangeConfig({
        defaultMin: 10,
        defaultMax: 4,
        soldierMin: 0,
        soldierMax: 20,
        leisureMin: 5,
        leisureMax: 3
      });
      await manager.setWeatherUserPreference({
        heatSensitivity: 2,
        rainSensitivity: 0,
        weatherRiskTolerance: 1
      });
      const storedDefaultMin = Number(store.getRaw(PreferenceManager.KEY_AI_POI_MIN_DEFAULT));
      const storedDefaultMax = Number(store.getRaw(PreferenceManager.KEY_AI_POI_MAX_DEFAULT));
      const storedSoldierMin = Number(store.getRaw(PreferenceManager.KEY_AI_POI_MIN_SOLDIER));
      const storedSoldierMax = Number(store.getRaw(PreferenceManager.KEY_AI_POI_MAX_SOLDIER));
      const storedLeisureMin = Number(store.getRaw(PreferenceManager.KEY_AI_POI_MIN_LEISURE));
      const storedLeisureMax = Number(store.getRaw(PreferenceManager.KEY_AI_POI_MAX_LEISURE));
      const storedHeat = Number(store.getRaw(PreferenceManager.KEY_WEATHER_HEAT_SENSITIVITY));
      const storedRain = Number(store.getRaw(PreferenceManager.KEY_WEATHER_RAIN_SENSITIVITY));
      const storedTolerance = Number(store.getRaw(PreferenceManager.KEY_WEATHER_RISK_TOLERANCE));
      store.setRaw(PreferenceManager.KEY_AI_POI_MIN_DEFAULT, 20 as Object);
      store.setRaw(PreferenceManager.KEY_AI_POI_MAX_DEFAULT, 0 as Object);
      store.setRaw(PreferenceManager.KEY_AI_POI_MIN_SOLDIER, 'bad' as Object);
      store.setRaw(PreferenceManager.KEY_AI_POI_MAX_SOLDIER, 'bad' as Object);
      store.setRaw(PreferenceManager.KEY_AI_POI_MIN_LEISURE, 7 as Object);
      store.setRaw(PreferenceManager.KEY_AI_POI_MAX_LEISURE, 5 as Object);
      store.setRaw(PreferenceManager.KEY_WEATHER_HEAT_SENSITIVITY, 'bad' as Object);
      store.setRaw(PreferenceManager.KEY_WEATHER_RAIN_SENSITIVITY, -1 as Object);
      store.setRaw(PreferenceManager.KEY_WEATHER_RISK_TOLERANCE, 99 as Object);
      const config = await manager.getAiDailyPoiRangeConfig();
      const weather = await manager.getWeatherUserPreference();
      // Assert
      expect(storedDefaultMin).assertEqual(4);
      expect(storedDefaultMax).assertEqual(10);
      expect(storedSoldierMin).assertEqual(1);
      expect(storedSoldierMax).assertEqual(12);
      expect(storedLeisureMin).assertEqual(3);
      expect(storedLeisureMax).assertEqual(5);
      expect(storedHeat).assertEqual(2);
      expect(storedRain).assertEqual(0);
      expect(storedTolerance).assertEqual(1);
      expect(config.defaultMin).assertEqual(1);
      expect(config.defaultMax).assertEqual(12);
      expect(config.soldierMin).assertEqual(5);
      expect(config.soldierMax).assertEqual(8);
      expect(config.leisureMin).assertEqual(5);
      expect(config.leisureMax).assertEqual(7);
      expect(weather.heatSensitivity).assertEqual(DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity);
      expect(weather.rainSensitivity).assertEqual(0);
      expect(weather.weatherRiskTolerance).assertEqual(2);
    });

    it('boundary: preference_manager_feature_flags_should_roundtrip_and_treat_non_true_values_as_false', 0, async () => {
      // Arrange
      const store = new PreferenceStoreMockAS();
      const manager = attachPreferenceStoreAS(store);
      // Act
      await manager.setWeatherFeatureEnabled(true);
      await manager.setGuestChosen(true);
      await manager.setSilentLoginBlockedAfterLogout(true);
      const storedWeatherEnabled = store.getRaw(PreferenceManager.KEY_WEATHER_FEATURE_ENABLED) === true;
      const storedGuestChosen = store.getRaw(PreferenceManager.KEY_AUTH_GUEST_CHOSEN) === true;
      const storedSilentBlocked = store.getRaw(PreferenceManager.KEY_AUTH_BLOCK_SILENT_AFTER_LOGOUT) === true;
      store.setRaw(PreferenceManager.KEY_WEATHER_FEATURE_ENABLED, 'true' as Object);
      store.setRaw(PreferenceManager.KEY_AUTH_GUEST_CHOSEN, 1 as Object);
      store.setRaw(PreferenceManager.KEY_AUTH_BLOCK_SILENT_AFTER_LOGOUT, '1' as Object);
      const weatherEnabled = await manager.isWeatherFeatureEnabled();
      const guestChosen = await manager.isGuestChosen();
      const silentBlocked = await manager.isSilentLoginBlockedAfterLogout();
      // Assert
      expect(storedWeatherEnabled).assertTrue();
      expect(storedGuestChosen).assertTrue();
      expect(storedSilentBlocked).assertTrue();
      expect(weatherEnabled).assertFalse();
      expect(guestChosen).assertFalse();
      expect(silentBlocked).assertFalse();
    });

    it('regression: preference_manager_avatar_and_strategy_profile_getters_should_fallback_on_invalid_json', 0, async () => {
      // Arrange
      const store = new PreferenceStoreMockAS();
      const manager = attachPreferenceStoreAS(store);
      store.setRaw(PreferenceManager.buildAvatarProfileKey('user_invalid_as'), '{bad_avatar_json' as Object);
      store.setRaw(PreferenceManager.KEY_USER_STRATEGY_PROFILE, '{bad_profile_json' as Object);
      // Act
      const avatarProfile = await manager.getAvatarProfile('user_invalid_as');
      const strategyProfile = await manager.getUserStrategyProfile();
      // Assert
      expect(avatarProfile.userId).assertEqual('user_invalid_as');
      expect(avatarProfile.localUri).assertEqual('');
      expect(strategyProfile.avgDensity).assertEqual(DEFAULT_USER_PROFILE.avgDensity);
      expect(strategyProfile.modeFrequency).assertEqual(DEFAULT_USER_PROFILE.modeFrequency);
    });

    it('combined: preference_manager_cache_avatar_and_strategy_setters_should_roundtrip_sanitized_payloads', 0, async () => {
      // Arrange
      const store = new PreferenceStoreMockAS();
      const manager = attachPreferenceStoreAS(store);
      const avatar = new AvatarProfile();
      avatar.userId = '';
      avatar.localUri = 'local://avatar';
      avatar.compressedUri = 'local://avatar_small';
      avatar.cloudUrl = 'https://cdn/avatar';
      avatar.uploadState = 'SYNCED';
      avatar.updatedAt = 0;
      const profile = cloneDefaultUserProfileAS();
      profile.sampleCount = -7;
      profile.modeFrequency = '{"0":2}';
      profile.manualOverrideEnabled = true;
      profile.consistencyMatchCount = 4.8;
      profile.consistencyMismatchCount = -3;
      profile.lastConsistencyCheckAt = -10;
      // Act
      await manager.setSessionCacheJson('{"session":"ok"}');
      await manager.setProfileCacheJson('acc_as', '{"profile":"ok"}');
      await manager.setAvatarProfile(avatar);
      await manager.setUserStrategyProfile(profile);
      const sessionJson = await manager.getSessionCacheJson();
      const profileJson = await manager.getProfileCacheJson('acc_as');
      const loadedAvatar = await manager.getAvatarProfile('');
      const loadedProfile = await manager.getUserStrategyProfile();
      await manager.clearProfileCache('acc_as');
      store.setRaw(PreferenceManager.KEY_SESSION_CACHE, 1 as Object);
      store.setRaw(PreferenceManager.buildProfileCacheKey('acc_bad_as'), 2 as Object);
      const invalidSessionJson = await manager.getSessionCacheJson();
      const invalidProfileJson = await manager.getProfileCacheJson('acc_bad_as');
      const clearedProfileJson = await manager.getProfileCacheJson('acc_as');
      // Assert
      expect(sessionJson).assertEqual('{"session":"ok"}');
      expect(profileJson).assertEqual('{"profile":"ok"}');
      expect(loadedAvatar.userId).assertEqual('guest_local');
      expect(loadedAvatar.localUri).assertEqual('local://avatar');
      expect(loadedAvatar.uploadState).assertEqual('SYNCED');
      expect(loadedAvatar.updatedAt > 0).assertTrue();
      expect(loadedProfile.modeFrequency).assertEqual('{"0":2}');
      expect(loadedProfile.sampleCount).assertEqual(0);
      expect(loadedProfile.manualOverrideEnabled).assertTrue();
      expect(loadedProfile.consistencyMatchCount).assertEqual(4);
      expect(loadedProfile.consistencyMismatchCount).assertEqual(0);
      expect(loadedProfile.lastConsistencyCheckAt).assertEqual(0);
      expect(invalidSessionJson).assertEqual('');
      expect(invalidProfileJson).assertEqual('');
      expect(clearedProfileJson).assertEqual('');
    });

    it('normal: date_util_should_extract_shift_and_minutes_from_supported_inputs', 0, () => {
      // Arrange
      const sameDay = '12-21 09:05';
      const nextDay = '次日 10:30';
      // Act
      const pureTime = DateUtil.extractPureTime(sameDay);
      const sameDayShift = DateUtil.getDayShift(sameDay);
      const nextDayShift = DateUtil.getDayShift(nextDay);
      const minutes = DateUtil.timeToMinutes(nextDay);
      // Assert
      expect(pureTime).assertEqual('09:05');
      expect(sameDayShift).assertEqual(0);
      expect(nextDayShift).assertEqual(1);
      expect(minutes).assertEqual(630);
    });

    it('boundary: date_util_should_support_edge_clock_values_cross_day_rollover_and_headers', 0, () => {
      // Arrange
      const baseDate = new Date(2026, 3, 1, 8, 0, 0, 0);
      // Act
      const valid = DateUtil.isValidTimeString('23:59');
      const timeAtDayEnd = DateUtil.minutesToTime(24 * 60);
      const addedMinutes = DateUtil.addMinutes('23:50', 15);
      const monthDay = DateUtil.formatMonthDay(baseDate);
      const header = DateUtil.getDateHeader(baseDate, 24 * 60);
      // Assert
      expect(valid).assertTrue();
      expect(timeAtDayEnd).assertEqual('次日 00:00');
      expect(addedMinutes).assertEqual(1445);
      expect(monthDay).assertEqual('4月1日');
      expect(header).assertEqual('4月2日 周四');
    });

    it('invalid: date_util_should_reject_unsupported_time_strings_and_return_safe_fallbacks', 0, () => {
      // Arrange
      const invalidTime = '99:99';
      // Act
      const pureTime = DateUtil.extractPureTime('not_a_time');
      const valid = DateUtil.isValidTimeString(invalidTime);
      const minutes = DateUtil.timeToMinutes('oops');
      const addedMinutes = DateUtil.addMinutes('oops', 20);
      const endTime = DateUtil.calculateEndTime('次日 99:99', 30);
      // Assert
      expect(pureTime).assertEqual('');
      expect(valid).assertFalse();
      expect(minutes).assertEqual(0);
      expect(addedMinutes).assertEqual(20);
      expect(endTime).assertEqual('--:--');
    });

    it('normal: date_util_should_format_same_day_values_and_supported_date_patterns', 0, () => {
      // Arrange
      const baseDate = new Date(2026, 0, 15, 9, 5, 0, 0);
      // Act
      const realTime = DateUtil.formatRealTime(baseDate, 10);
      const hhmm = DateUtil.formatDate(baseDate, 'HH:mm');
      const monthDay = DateUtil.formatDate(baseDate, 'MM月dd日');
      const monthDayTime = DateUtil.formatDate(baseDate, 'MM-dd HH:mm');
      const planDate = DateUtil.formatPlanDate(baseDate.getTime());
      const localDate = DateUtil.formatLocalDate(baseDate.getTime());
      const endTime = DateUtil.calculateEndTime('12-21 09:00', 90);
      // Assert
      expect(realTime).assertEqual('09:15');
      expect(hhmm).assertEqual('09:05');
      expect(monthDay).assertEqual('01月15日');
      expect(monthDayTime).assertEqual('01-15 09:05');
      expect(planDate).assertEqual('1月15日');
      expect(localDate).assertEqual('2026-01-15');
      expect(endTime).assertEqual('10:30');
    });

    it('boundary: date_util_should_keep_cross_month_and_cross_year_prefix_after_boundary_fix', 0, () => {
      // Arrange
      const crossMonthBase = new Date(2026, 0, 31, 23, 50, 0, 0);
      const crossYearBase = new Date(2026, 11, 31, 23, 50, 0, 0);
      // Act
      const crossMonth = DateUtil.formatRealTime(crossMonthBase, 20);
      const crossYear = DateUtil.formatRealTime(crossYearBase, 20);
      const sameTimeWithNegativeDuration = DateUtil.calculateEndTime('09:00', -30);
      // Assert
      expect(crossMonth).assertEqual('02-01 00:10');
      expect(crossYear).assertEqual('01-01 00:10');
      expect(sameTimeWithNegativeDuration).assertEqual('09:00');
    });

    it('regression: date_util_log_boundary_self_check_should_not_throw_and_unknown_formats_should_fallback', 0, () => {
      // Arrange
      const date = new Date(2026, 5, 8, 7, 4, 0, 0);
      // Act
      const message = captureSyncErrorAS(() => {
        DateUtil.logBoundarySelfCheck();
      });
      const fallback = DateUtil.formatDate(date, 'unexpected');
      // Assert
      expect(message).assertEqual('');
      expect(fallback).assertEqual('07:04');
    });

    it('normal: theme_center_should_normalize_modes_and_return_matching_palettes', 0, () => {
      // Arrange
      // Act
      const themeMode = ThemeCenter.normalizeThemeMode('dark');
      const themeModeFallback = ThemeCenter.normalizeThemeMode('invalid');
      const effectiveTheme = ThemeCenter.normalizeEffectiveTheme('dark');
      const effectiveFallback = ThemeCenter.normalizeEffectiveTheme('invalid');
      const lightPalette = ThemeCenter.getPalette('light');
      const darkPalette = ThemeCenter.getPalette('dark');
      // Assert
      expect(themeMode).assertEqual('dark');
      expect(themeModeFallback).assertEqual('system');
      expect(effectiveTheme).assertEqual('dark');
      expect(effectiveFallback).assertEqual('light');
      expect(lightPalette.pageBg).assertEqual('#F6F8FC');
      expect(darkPalette.pageBg).assertEqual('#0F1621');
    });

    it('boundary: theme_center_should_resolve_system_theme_from_context_color_mode', 0, () => {
      // Arrange
      const withConfig = new ThemeContextMockAS(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      const withoutConfig = new ThemeContextMockAS(undefined);
      // Act
      const resolvedDark = ThemeCenter.resolveEffectiveTheme('system', ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      const resolvedLight = ThemeCenter.resolveEffectiveTheme('system', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      const colorModeFromContext = ThemeCenter.readColorModeFromContext(withConfig as never);
      const colorModeFallback = ThemeCenter.readColorModeFromContext(withoutConfig as never);
      // Assert
      expect(resolvedDark).assertEqual('dark');
      expect(resolvedLight).assertEqual('light');
      expect(colorModeFromContext).assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      expect(colorModeFallback).assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    });

    it('invalid: theme_center_apply_theme_mode_should_fallback_to_system_when_primary_set_color_mode_fails', 0, () => {
      // Arrange
      resetThemeStorageAS();
      const appContext = new ApplicationContextMockAS([ConfigurationConstant.ColorMode.COLOR_MODE_DARK]);
      const context = new ThemeContextMockAS(ConfigurationConstant.ColorMode.COLOR_MODE_DARK, appContext);
      // Act
      const effectiveTheme = ThemeCenter.applyThemeMode(context as never, 'dark');
      const storedMode = getThemeStorageValueAS(ThemeCenter.STORAGE_THEME_MODE);
      const storedEffective = getThemeStorageValueAS(ThemeCenter.STORAGE_EFFECTIVE_THEME);
      // Assert
      expect(effectiveTheme).assertEqual('dark');
      expect(appContext.setColorModeCalls.length).assertEqual(2);
      expect(appContext.setColorModeCalls[0]).assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      expect(appContext.setColorModeCalls[1]).assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      expect(storedMode).assertEqual('dark');
      expect(storedEffective).assertEqual('dark');
    });

    it('combined: theme_center_apply_and_sync_should_store_light_and_system_modes', 0, () => {
      // Arrange
      resetThemeStorageAS();
      const lightContext = new ThemeContextMockAS(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      const systemDarkContext = new ThemeContextMockAS(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      // Act
      const lightTheme = ThemeCenter.applyThemeMode(lightContext as never, 'light');
      const storedLightMode = getThemeStorageValueAS(ThemeCenter.STORAGE_THEME_MODE);
      const storedLightEffective = getThemeStorageValueAS(ThemeCenter.STORAGE_EFFECTIVE_THEME);
      const systemTheme = ThemeCenter.applyThemeMode(systemDarkContext as never, 'system');
      ThemeCenter.syncThemeToStorage('system', 'dark');
      const storedSystemMode = getThemeStorageValueAS(ThemeCenter.STORAGE_THEME_MODE);
      const storedSystemEffective = getThemeStorageValueAS(ThemeCenter.STORAGE_EFFECTIVE_THEME);
      // Assert
      expect(lightTheme).assertEqual('light');
      expect(storedLightMode).assertEqual('light');
      expect(storedLightEffective).assertEqual('light');
      expect(systemTheme).assertEqual('dark');
      expect(storedSystemMode).assertEqual('system');
      expect(storedSystemEffective).assertEqual('dark');
    });

    it('normal: app_config_validate_methods_should_accept_current_non_blank_values', 0, () => {
      // Arrange
      // Act
      const aiMessage = captureSyncErrorAS(() => {
        AppConfig.validateAiConfig();
      });
      const amapWebMessage = captureSyncErrorAS(() => {
        AppConfig.validateAmapWebConfig();
      });
      const amapSdkMessage = captureSyncErrorAS(() => {
        AppConfig.validateAmapSdkConfig();
      });
      const authMessage = captureSyncErrorAS(() => {
        AppConfig.validateAuthConfig();
      });
      // Assert
      expect(aiMessage).assertEqual('');
      expect(amapWebMessage).assertEqual('');
      expect(amapSdkMessage).assertEqual('');
      expect(authMessage).assertEqual('');
    });

    it('boundary: app_config_validate_methods_should_reject_blank_whitespace_values', 0, () => {
      // Arrange
      const hooks = new AppConfigHooksAS();
      hooks.setAiApiUrl('   ' as Object);
      hooks.setAmapWebApiKey('   ' as Object);
      hooks.setAmapSdkApiKey('   ' as Object);
      hooks.setAuthApiBaseUrl('   ' as Object);
      // Act
      const aiMessage = captureSyncErrorAS(() => {
        AppConfig.validateAiConfig();
      });
      const amapWebMessage = captureSyncErrorAS(() => {
        AppConfig.validateAmapWebConfig();
      });
      const amapSdkMessage = captureSyncErrorAS(() => {
        AppConfig.validateAmapSdkConfig();
      });
      const authMessage = captureSyncErrorAS(() => {
        AppConfig.validateAuthConfig();
      });
      hooks.restore();
      // Assert
      expect(aiMessage).assertEqual('AI_API_URL 未配置，请检查 AppConfig.ets');
      expect(amapWebMessage).assertEqual('AMAP_WEB_API_KEY 未配置，请检查 AppConfig.ets');
      expect(amapSdkMessage).assertEqual('AMAP_SDK_API_KEY 未配置，请检查 AppConfig.ets');
      expect(authMessage).assertEqual('AUTH_API_BASE_URL 未配置，请检查 AppConfig.ets');
    });

    it('invalid: app_config_validate_methods_should_reject_empty_strings', 0, () => {
      // Arrange
      const hooks = new AppConfigHooksAS();
      hooks.setAiApiUrl('' as Object);
      hooks.setAmapWebApiKey('' as Object);
      hooks.setAmapSdkApiKey('' as Object);
      hooks.setAuthApiBaseUrl('' as Object);
      // Act
      const aiMessage = captureSyncErrorAS(() => {
        AppConfig.validateAiConfig();
      });
      const amapWebMessage = captureSyncErrorAS(() => {
        AppConfig.validateAmapWebConfig();
      });
      const amapSdkMessage = captureSyncErrorAS(() => {
        AppConfig.validateAmapSdkConfig();
      });
      const authMessage = captureSyncErrorAS(() => {
        AppConfig.validateAuthConfig();
      });
      hooks.restore();
      // Assert
      expect(aiMessage).assertEqual('AI_API_URL 未配置，请检查 AppConfig.ets');
      expect(amapWebMessage).assertEqual('AMAP_WEB_API_KEY 未配置，请检查 AppConfig.ets');
      expect(amapSdkMessage).assertEqual('AMAP_SDK_API_KEY 未配置，请检查 AppConfig.ets');
      expect(authMessage).assertEqual('AUTH_API_BASE_URL 未配置，请检查 AppConfig.ets');
    });

    it('normal: rdb_helper_should_keep_singleton_and_upgrade_store_to_latest_version', 0, async () => {
      // Arrange
      const hooks = new RdbHooksAS();
      const store = new RdbStoreMockAS();
      const helperA = resetRdbHelperStoreAS();
      const helperB = RdbHelper.getInstance();
      const beforeInit = helperA.getRdbStore();
      hooks.setGetRdbStore((_context: Object, _config: Object, callback: (err: Object | null, store: Object | null) => void) => {
        callback(null, store as Object);
      });
      // Act
      await helperA.init({} as common.Context);
      const afterInit = helperB.getRdbStore();
      hooks.restore();
      // Assert
      expect(helperA === helperB).assertTrue();
      expect(beforeInit === null).assertTrue();
      expect(afterInit === (store as Object)).assertTrue();
      expect(store.version).assertEqual(6);
      expect(store.executeSqlCalls.length).assertEqual(17);
      expect(store.executeSqlCalls[0]).assertEqual(PlanEntity.SQL_CREATE_TABLE);
      expect(store.executeSqlCalls[1]).assertEqual(EventEntity.SQL_CREATE_TABLE);
    });

    it('boundary: rdb_helper_init_should_skip_upgrade_branches_when_store_version_is_latest', 0, async () => {
      // Arrange
      const hooks = new RdbHooksAS();
      const store = new RdbStoreMockAS();
      store.version = 6;
      const helper = resetRdbHelperStoreAS();
      hooks.setGetRdbStore((_context: Object, _config: Object, callback: (err: Object | null, store: Object | null) => void) => {
        callback(null, store as Object);
      });
      // Act
      await helper.init({} as common.Context);
      hooks.restore();
      // Assert
      expect(store.version).assertEqual(6);
      expect(store.executeSqlCalls.length).assertEqual(2);
    });

    it('invalid: rdb_helper_init_should_reject_when_relational_store_creation_fails', 0, async () => {
      // Arrange
      const hooks = new RdbHooksAS();
      const helper = resetRdbHelperStoreAS();
      hooks.setGetRdbStore((_context: Object, _config: Object, callback: (err: Object | null, store: Object | null) => void) => {
        callback(new RdbErrorMockAS(301, 'get_store_failed_as') as Object, null);
      });
      // Act
      const message = await captureAsyncErrorAS(async () => {
        await helper.init({} as common.Context);
      });
      hooks.restore();
      // Assert
      expect(message).assertEqual('get_store_failed_as');
      expect(helper.getRdbStore() === null).assertTrue();
    });

    it('conflict: rdb_helper_init_should_reject_when_non_recoverable_sql_fails', 0, async () => {
      // Arrange
      const hooks = new RdbHooksAS();
      const store = new RdbStoreMockAS();
      store.version = 2;
      store.failTokens = ['CREATE INDEX'];
      const helper = resetRdbHelperStoreAS();
      hooks.setGetRdbStore((_context: Object, _config: Object, callback: (err: Object | null, store: Object | null) => void) => {
        callback(null, store as Object);
      });
      // Act
      const message = await captureAsyncErrorAS(async () => {
        await helper.init({} as common.Context);
      });
      hooks.restore();
      // Assert
      expect(message).assertEqual('sql_failed_CREATE INDEX');
      expect(store.version).assertEqual(2);
    });

    it('regression: rdb_helper_init_should_continue_when_duplicate_alter_column_errors_are_caught', 0, async () => {
      // Arrange
      const hooks = new RdbHooksAS();
      const store = new RdbStoreMockAS();
      store.version = 1;
      store.failTokens = [EventEntity.ACTUAL_START_TIME];
      const helper = resetRdbHelperStoreAS();
      hooks.setGetRdbStore((_context: Object, _config: Object, callback: (err: Object | null, store: Object | null) => void) => {
        callback(null, store as Object);
      });
      // Act
      const message = await captureAsyncErrorAS(async () => {
        await helper.init({} as common.Context);
      });
      hooks.restore();
      // Assert
      expect(message).assertEqual('');
      expect(store.version).assertEqual(6);
      expect(store.executeSqlCalls.length).assertEqual(17);
    });
  });
}
