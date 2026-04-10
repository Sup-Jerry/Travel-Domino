// 路径: ets/common/utils/PreferenceManager.ets
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DEFAULT_WEATHER_USER_PREFERENCE, WeatherPreferenceLevel, WeatherUserPreference } from '../../domain/services/WeatherModels';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from '../../domain/strategy/UserStrategyProfile';
import { AvatarProfile } from '../../domain/auth/AvatarModels';
import { StorageKeys } from '../constants/StorageKeys';

const TAG = 'PreferenceManager';

interface UserStrategyProfileSnapshot {
  avgDensity?: number;
  avgPace?: number;
  avgPreference?: number;
  avgEnergy?: number;
  modeFrequency?: string;
  sampleCount?: number;
  updatedAt?: number;
  manualOverrideEnabled?: boolean;
  consistencyMatchCount?: number;
  consistencyMismatchCount?: number;
  lastConsistencyCheckAt?: number;
}

interface AvatarProfileSnapshot {
  userId?: string;
  localUri?: string;
  compressedUri?: string;
  cloudUrl?: string;
  uploadState?: string;
  updatedAt?: number;
}

export class PreferenceManager {
  private static instance: PreferenceManager;
  private pref: preferences.Preferences | null = null;
  private readonly STORE_NAME = 'TravelDominoPrefs';

  static readonly KEY_SKIP_PLAN_DELETE_CONFIRM = 'skip_plan_delete_confirm';
  static readonly KEY_HIDE_SOFT_DELETE_TIP = 'hideSoftDeleteTip';
  static readonly KEY_HIDE_ARCHIVE_TIP = 'hideArchiveTip';
  static readonly KEY_MIN_EVENT_DURATION = 'minEventDuration';
  static readonly KEY_THEME_MODE = 'themeMode';
  static readonly KEY_IDLE_GAP_DETECTION_ENABLED = 'idleGapDetectionEnabled';
  static readonly KEY_IDLE_GAP_TRIGGER_MINUTES = 'idleGapTriggerMinutes';
  static readonly KEY_ARRIVAL_NOTIFY_PROMPTED = 'arrivalNotifyPrompted';
  static readonly KEY_ARRIVAL_LOCATION_PROMPTED = 'arrivalLocationPrompted';
  static readonly KEY_WEATHER_HEAT_SENSITIVITY = 'weatherHeatSensitivity';
  static readonly KEY_WEATHER_RAIN_SENSITIVITY = 'weatherRainSensitivity';
  static readonly KEY_WEATHER_RISK_TOLERANCE = 'weatherRiskTolerance';
  static readonly KEY_WEATHER_FEATURE_ENABLED = 'weatherFeatureEnabled';
  static readonly KEY_USER_STRATEGY_PROFILE = 'userStrategyProfile';
  static readonly KEY_AUTH_GUEST_CHOSEN = 'authGuestChosen';
  static readonly KEY_AUTH_BLOCK_SILENT_AFTER_LOGOUT = 'authBlockSilentAfterLogout';
  static readonly KEY_AVATAR_PROFILE_PREFIX = 'avatarProfile:';
  static readonly KEY_SESSION_CACHE = StorageKeys.SESSION_CACHE;
  static readonly KEY_PROFILE_CACHE_PREFIX = StorageKeys.PROFILE_CACHE_PREFIX;
  static readonly KEY_AVATAR_CACHE_PREFIX = StorageKeys.AVATAR_CACHE_PREFIX;

  // 新增：是否允许调用高德路线 API
  static readonly KEY_ENABLE_AMAP_ROUTE_API = 'enableAmapRouteApi';

  private constructor() {}

  public static normalizeAmapRouteApiEnabled(raw: preferences.ValueType): boolean {
    return raw === true;
  }

  public static normalizeMinEventDuration(raw: preferences.ValueType): number {
    let duration = Number(raw);
    if (!Number.isFinite(duration)) {
      duration = 30;
    }
    duration = Math.floor(duration);
    if (duration < 1) {
      duration = 1;
    } else if (duration > 720) {
      duration = 720;
    }
    return duration;
  }

  public static normalizeThemeMode(raw: preferences.ValueType): string {
    const text = typeof raw === 'string' ? raw : 'system';
    if (text === 'light' || text === 'dark' || text === 'system') {
      return text;
    }
    return 'system';
  }

  public static normalizeIdleGapTriggerMinutes(raw: preferences.ValueType): number {
    let safe = Number(raw);
    if (!Number.isFinite(safe)) {
      safe = 45;
    }
    safe = Math.floor(safe);
    if (safe < 1) {
      safe = 1;
    } else if (safe > 720) {
      safe = 720;
    }
    return safe;
  }

  public static normalizeWeatherPreferenceLevel(raw: preferences.ValueType): WeatherPreferenceLevel {
    let safe = Number(raw);
    if (!Number.isFinite(safe)) {
      safe = 1;
    }
    safe = Math.floor(safe);
    if (safe < 0) {
      return 0;
    }
    if (safe > 2) {
      return 2;
    }
    return safe as WeatherPreferenceLevel;
  }

  private sanitizeError(error: Object): string {
    if (error instanceof Error && typeof error.message === 'string' && error.message.length > 0) {
      return error.message;
    }
    return 'unknown_error';
  }

  public static getInstance(): PreferenceManager {
    if (!PreferenceManager.instance) {
      PreferenceManager.instance = new PreferenceManager();
    }
    return PreferenceManager.instance;
  }

  public async init(context: common.Context): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, this.STORE_NAME);
      hilog.info(0x0000, TAG, 'Preferences initialized.');
    } catch (err) {
      hilog.error(0x0000, TAG, `Failed to get preferences: ${this.sanitizeError(err)}`);
    }
  }

  public async setValue(key: string, value: preferences.ValueType): Promise<void> {
    if (!this.pref) {
      const msg = `Preferences 未初始化，无法写入 key=${key}`;
      hilog.error(0x0000, TAG, msg);
      throw new Error(msg);
    }

    try {
      await this.pref.put(key, value);
      await this.pref.flush();
      hilog.info(0x0000, TAG, `Preference saved, key_len=${key.length}, value_type=${typeof value}`);
    } catch (error) {
      const reason = this.sanitizeError(error);
      hilog.error(0x0000, TAG, `Preference save failed, key_len=${key.length}, reason=${reason}`);
      throw new Error(`Preference save failed: ${reason}`);
    }
  }

  public async getValue(key: string, defaultValue: preferences.ValueType): Promise<preferences.ValueType> {
    if (!this.pref) {
      const msg = `Preferences 未初始化，无法读取 key=${key}`;
      hilog.error(0x0000, TAG, msg);
      throw new Error(msg);
    }

    try {
      const value = await this.pref.get(key, defaultValue);
      hilog.info(0x0000, TAG, `Preference loaded, key_len=${key.length}, value_type=${typeof value}`);
      return value;
    } catch (error) {
      const reason = this.sanitizeError(error);
      hilog.error(0x0000, TAG, `Preference load failed, key_len=${key.length}, reason=${reason}`);
      throw new Error(`Preference load failed: ${reason}`);
    }
  }

  // 新增：读取高德路线 API 开关
  public async isAmapRouteApiEnabled(): Promise<boolean> {
    const value = await this.getValue(PreferenceManager.KEY_ENABLE_AMAP_ROUTE_API, true);
    const enabled = PreferenceManager.normalizeAmapRouteApiEnabled(value);
    hilog.info(0x0000, TAG, `Amap route api enabled = ${JSON.stringify(enabled)}`);
    return enabled;
  }

  // 新增：设置高德路线 API 开关
  public async setAmapRouteApiEnabled(enabled: boolean): Promise<void> {
    hilog.info(0x0000, TAG, `Try save amap route api enabled = ${JSON.stringify(enabled)}`);
    await this.setValue(PreferenceManager.KEY_ENABLE_AMAP_ROUTE_API, enabled);
  }
  public async getMinEventDuration(): Promise<number> {
    const value = await this.getValue(PreferenceManager.KEY_MIN_EVENT_DURATION, 30);
    return PreferenceManager.normalizeMinEventDuration(value);
  }

  public async setMinEventDuration(duration: number): Promise<void> {
    const safe = PreferenceManager.normalizeMinEventDuration(duration);
    await this.setValue(PreferenceManager.KEY_MIN_EVENT_DURATION, safe);
  }

  public async getThemeMode(): Promise<string> {
    const value = await this.getValue(PreferenceManager.KEY_THEME_MODE, 'system');
    return PreferenceManager.normalizeThemeMode(value);
  }

  public async setThemeMode(mode: string): Promise<void> {
    const normalized = mode === 'light' || mode === 'dark' || mode === 'system' ? mode : 'system';
    await this.setValue(PreferenceManager.KEY_THEME_MODE, normalized);
  }

  private sanitizeIdleGapTriggerMinutes(raw: number): number {
    return PreferenceManager.normalizeIdleGapTriggerMinutes(raw);
  }

  public async getIdleGapDetectionEnabled(): Promise<boolean> {
    const value = await this.getValue(PreferenceManager.KEY_IDLE_GAP_DETECTION_ENABLED, true);
    return value === true;
  }

  public async setIdleGapDetectionEnabled(enabled: boolean): Promise<void> {
    await this.setValue(PreferenceManager.KEY_IDLE_GAP_DETECTION_ENABLED, enabled);
  }

  public async getIdleGapTriggerMinutes(): Promise<number> {
    const value = await this.getValue(PreferenceManager.KEY_IDLE_GAP_TRIGGER_MINUTES, 45);
    return this.sanitizeIdleGapTriggerMinutes(Number(value));
  }

  public async setIdleGapTriggerMinutes(minutes: number): Promise<void> {
    const safe = this.sanitizeIdleGapTriggerMinutes(minutes);
    await this.setValue(PreferenceManager.KEY_IDLE_GAP_TRIGGER_MINUTES, safe);
  }

  public async getWeatherUserPreference(): Promise<WeatherUserPreference> {
    const heatRaw = await this.getValue(
      PreferenceManager.KEY_WEATHER_HEAT_SENSITIVITY,
      DEFAULT_WEATHER_USER_PREFERENCE.heatSensitivity
    );
    const rainRaw = await this.getValue(
      PreferenceManager.KEY_WEATHER_RAIN_SENSITIVITY,
      DEFAULT_WEATHER_USER_PREFERENCE.rainSensitivity
    );
    const toleranceRaw = await this.getValue(
      PreferenceManager.KEY_WEATHER_RISK_TOLERANCE,
      DEFAULT_WEATHER_USER_PREFERENCE.weatherRiskTolerance
    );
    return {
      heatSensitivity: PreferenceManager.normalizeWeatherPreferenceLevel(heatRaw),
      rainSensitivity: PreferenceManager.normalizeWeatherPreferenceLevel(rainRaw),
      weatherRiskTolerance: PreferenceManager.normalizeWeatherPreferenceLevel(toleranceRaw)
    };
  }

  public async setWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    const safe: WeatherUserPreference = {
      heatSensitivity: PreferenceManager.normalizeWeatherPreferenceLevel(preference.heatSensitivity),
      rainSensitivity: PreferenceManager.normalizeWeatherPreferenceLevel(preference.rainSensitivity),
      weatherRiskTolerance: PreferenceManager.normalizeWeatherPreferenceLevel(preference.weatherRiskTolerance)
    };
    await this.setValue(PreferenceManager.KEY_WEATHER_HEAT_SENSITIVITY, safe.heatSensitivity);
    await this.setValue(PreferenceManager.KEY_WEATHER_RAIN_SENSITIVITY, safe.rainSensitivity);
    await this.setValue(PreferenceManager.KEY_WEATHER_RISK_TOLERANCE, safe.weatherRiskTolerance);
  }

  public async isWeatherFeatureEnabled(): Promise<boolean> {
    const value = await this.getValue(PreferenceManager.KEY_WEATHER_FEATURE_ENABLED, true);
    return value === true;
  }

  public async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    await this.setValue(PreferenceManager.KEY_WEATHER_FEATURE_ENABLED, enabled);
  }

  public async isGuestChosen(): Promise<boolean> {
    const value = await this.getValue(PreferenceManager.KEY_AUTH_GUEST_CHOSEN, false);
    return value === true;
  }

  public async setGuestChosen(chosen: boolean): Promise<void> {
    await this.setValue(PreferenceManager.KEY_AUTH_GUEST_CHOSEN, chosen);
  }

  public async isSilentLoginBlockedAfterLogout(): Promise<boolean> {
    const value = await this.getValue(PreferenceManager.KEY_AUTH_BLOCK_SILENT_AFTER_LOGOUT, false);
    return value === true;
  }

  public async setSilentLoginBlockedAfterLogout(blocked: boolean): Promise<void> {
    await this.setValue(PreferenceManager.KEY_AUTH_BLOCK_SILENT_AFTER_LOGOUT, blocked);
  }

  public static buildAvatarProfileKey(userId: string): string {
    const safeUserId = (userId || '').trim().length > 0 ? userId.trim() : 'guest_local';
    return `${PreferenceManager.KEY_AVATAR_PROFILE_PREFIX}${safeUserId}`;
  }

  public static buildProfileCacheKey(accountId: string): string {
    return StorageKeys.buildProfileCacheKey(accountId);
  }

  public static buildAvatarCacheKey(accountId: string): string {
    return StorageKeys.buildAvatarCacheKey(accountId);
  }

  public async getSessionCacheJson(): Promise<string> {
    const raw = await this.getValue(PreferenceManager.KEY_SESSION_CACHE, '');
    return typeof raw === 'string' ? raw : '';
  }

  public async setSessionCacheJson(raw: string): Promise<void> {
    await this.setValue(PreferenceManager.KEY_SESSION_CACHE, String(raw || ''));
  }

  public async getProfileCacheJson(accountId: string): Promise<string> {
    const key = PreferenceManager.buildProfileCacheKey(accountId);
    const raw = await this.getValue(key, '');
    return typeof raw === 'string' ? raw : '';
  }

  public async setProfileCacheJson(accountId: string, raw: string): Promise<void> {
    const key = PreferenceManager.buildProfileCacheKey(accountId);
    await this.setValue(key, String(raw || ''));
  }

  public async clearProfileCache(accountId: string): Promise<void> {
    const key = PreferenceManager.buildProfileCacheKey(accountId);
    await this.setValue(key, '');
  }

  public async getAvatarProfile(userId: string): Promise<AvatarProfile> {
    const safeUserId = (userId || '').trim().length > 0 ? userId.trim() : 'guest_local';
    const raw = await this.getValue(PreferenceManager.buildAvatarProfileKey(safeUserId), '');
    const fallback = new AvatarProfile();
    fallback.userId = safeUserId;
    if (typeof raw !== 'string' || raw.length === 0) {
      return fallback;
    }
    try {
      const parsed = JSON.parse(raw) as AvatarProfileSnapshot;
      const profile = new AvatarProfile();
      profile.userId = typeof parsed.userId === 'string' && parsed.userId.length > 0 ? parsed.userId : safeUserId;
      profile.localUri = typeof parsed.localUri === 'string' ? parsed.localUri : '';
      profile.compressedUri = typeof parsed.compressedUri === 'string' ? parsed.compressedUri : '';
      profile.cloudUrl = typeof parsed.cloudUrl === 'string' ? parsed.cloudUrl : '';
      const state = typeof parsed.uploadState === 'string' ? parsed.uploadState : 'EMPTY';
      profile.uploadState = state === 'LOCAL_ONLY' || state === 'SYNCED' ? state : 'EMPTY';
      profile.updatedAt = Number.isFinite(Number(parsed.updatedAt)) ? Number(parsed.updatedAt) : 0;
      return profile;
    } catch (_error) {
      return fallback;
    }
  }

  public async setAvatarProfile(profile: AvatarProfile): Promise<void> {
    const safeUserId = (profile.userId || '').trim().length > 0 ? profile.userId.trim() : 'guest_local';
    const safe = new AvatarProfile();
    safe.userId = safeUserId;
    safe.localUri = profile.localUri || '';
    safe.compressedUri = profile.compressedUri || '';
    safe.cloudUrl = profile.cloudUrl || '';
    safe.uploadState = profile.uploadState || 'EMPTY';
    safe.updatedAt = Number(profile.updatedAt) > 0 ? Number(profile.updatedAt) : Date.now();
    await this.setValue(PreferenceManager.buildAvatarProfileKey(safeUserId), JSON.stringify(safe));
  }

  private cloneDefaultUserProfile(): UserStrategyProfile {
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

  public async getUserStrategyProfile(): Promise<UserStrategyProfile> {
    const raw = await this.getValue(PreferenceManager.KEY_USER_STRATEGY_PROFILE, '');
    if (typeof raw !== 'string' || raw.length === 0) {
      return this.cloneDefaultUserProfile();
    }

    try {
      const parsed = JSON.parse(raw) as UserStrategyProfileSnapshot;
      return {
        avgDensity: Number.isFinite(Number(parsed.avgDensity))
          ? Number(parsed.avgDensity)
          : DEFAULT_USER_PROFILE.avgDensity,
        avgPace: Number.isFinite(Number(parsed.avgPace))
          ? Number(parsed.avgPace)
          : DEFAULT_USER_PROFILE.avgPace,
        avgPreference: Number.isFinite(Number(parsed.avgPreference))
          ? Number(parsed.avgPreference)
          : DEFAULT_USER_PROFILE.avgPreference,
        avgEnergy: Number.isFinite(Number(parsed.avgEnergy))
          ? Number(parsed.avgEnergy)
          : DEFAULT_USER_PROFILE.avgEnergy,
        modeFrequency: typeof parsed.modeFrequency === 'string'
          ? parsed.modeFrequency
          : DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: Number.isFinite(Number(parsed.sampleCount))
          ? Math.max(0, Math.floor(Number(parsed.sampleCount)))
          : DEFAULT_USER_PROFILE.sampleCount,
        updatedAt: Number.isFinite(Number(parsed.updatedAt))
          ? Number(parsed.updatedAt)
          : DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: parsed.manualOverrideEnabled === true,
        consistencyMatchCount: Number.isFinite(Number(parsed.consistencyMatchCount))
          ? Math.max(0, Math.floor(Number(parsed.consistencyMatchCount)))
          : (Number(DEFAULT_USER_PROFILE.consistencyMatchCount) > 0
            ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMatchCount))
            : 0),
        consistencyMismatchCount: Number.isFinite(Number(parsed.consistencyMismatchCount))
          ? Math.max(0, Math.floor(Number(parsed.consistencyMismatchCount)))
          : (Number(DEFAULT_USER_PROFILE.consistencyMismatchCount) > 0
            ? Math.floor(Number(DEFAULT_USER_PROFILE.consistencyMismatchCount))
            : 0),
        lastConsistencyCheckAt: Number.isFinite(Number(parsed.lastConsistencyCheckAt))
          ? Number(parsed.lastConsistencyCheckAt)
          : (Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt) > 0
            ? Number(DEFAULT_USER_PROFILE.lastConsistencyCheckAt)
            : 0)
      };
    } catch (_error) {
      return this.cloneDefaultUserProfile();
    }
  }

  public async setUserStrategyProfile(profile: UserStrategyProfile): Promise<void> {
    const safe: UserStrategyProfile = {
      avgDensity: profile.avgDensity,
      avgPace: profile.avgPace,
      avgPreference: profile.avgPreference,
      avgEnergy: profile.avgEnergy,
      modeFrequency: profile.modeFrequency,
      sampleCount: profile.sampleCount,
      updatedAt: profile.updatedAt,
      manualOverrideEnabled: profile.manualOverrideEnabled === true,
      consistencyMatchCount: Number.isFinite(Number(profile.consistencyMatchCount))
        ? Math.max(0, Math.floor(Number(profile.consistencyMatchCount)))
        : 0,
      consistencyMismatchCount: Number.isFinite(Number(profile.consistencyMismatchCount))
        ? Math.max(0, Math.floor(Number(profile.consistencyMismatchCount)))
        : 0,
      lastConsistencyCheckAt: Number.isFinite(Number(profile.lastConsistencyCheckAt))
        ? Math.max(0, Number(profile.lastConsistencyCheckAt))
        : 0
    };
    await this.setValue(PreferenceManager.KEY_USER_STRATEGY_PROFILE, JSON.stringify(safe));
  }
}

