import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/core-ohos';
import '@hw-agconnect/auth-ohos';
import '@hw-agconnect/database-ohos';
import { AGCRoutePolicy } from '@hw-agconnect/core-ohos';
import {
  AGConnectCloudDB,
  CloudDBZone,
  CloudDBZoneConfig,
  CloudDBZoneQuery
} from '@hw-agconnect/database-ohos';
import { UserProfileEntity } from '../../domain/entity/UserProfileEntity';
import { IUserProfileRepository } from '../../domain/ports/IUserProfileRepository';
import { UserProfile } from './clouddb/UserProfile';

interface CloudPermissionRule {
  role: string;
  rights: string[];
}

interface CloudPermissionSchema {
  objectTypeName: string;
  permissions: CloudPermissionRule[];
}

interface CloudFieldSchema {
  fieldName: string;
  fieldType: string;
  belongPrimaryKey: boolean;
  notNull: boolean;
  isNeedEncrypt: boolean;
  defaultValue?: string;
}

interface CloudObjectSchema {
  objectTypeName: string;
  fields: CloudFieldSchema[];
}

interface CloudObjectTypeInfo {
  schemaVersion: number;
  permissions: CloudPermissionSchema[];
  objectTypes: CloudObjectSchema[];
}

interface TimestampLike {
  toNumber?: () => number;
  toString?: () => string;
}

export class UserProfileRepositoryImpl implements IUserProfileRepository {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'UserProfileRepo';
  private static readonly CLOUD_DB_ZONE_NAMES: string[] = ['TravelDomino', 'CloudDBZone'];
  public static readonly DEFAULT_AVATAR_PATH: string = 'app.media.headphoto';
  private static readonly CLOUD_DB_OBJECT_TYPE_INFO: CloudObjectTypeInfo = {
    schemaVersion: 1,
    permissions: [{
      objectTypeName: 'UserProfile',
      permissions: [
        { role: 'Creator', rights: ['Read', 'Upsert', 'Delete'] },
        { role: 'Administrator', rights: ['Read', 'Upsert', 'Delete'] }
      ]
    }],
    objectTypes: [{
      objectTypeName: 'UserProfile',
      fields: [
        { fieldName: 'accountId', fieldType: 'String', belongPrimaryKey: true, notNull: true, isNeedEncrypt: false },
        { fieldName: 'username', fieldType: 'String', belongPrimaryKey: false, notNull: true, isNeedEncrypt: false, defaultValue: '' },
        { fieldName: 'avatarPath', fieldType: 'String', belongPrimaryKey: false, notNull: false, isNeedEncrypt: false },
        { fieldName: 'avatarVersion', fieldType: 'Integer', belongPrimaryKey: false, notNull: true, isNeedEncrypt: false, defaultValue: '1' },
        { fieldName: 'isInitialized', fieldType: 'Boolean', belongPrimaryKey: false, notNull: true, isNeedEncrypt: false, defaultValue: 'false' },
        { fieldName: 'createdAt', fieldType: 'Long', belongPrimaryKey: false, notNull: false, isNeedEncrypt: false },
        { fieldName: 'updatedAt', fieldType: 'Long', belongPrimaryKey: false, notNull: false, isNeedEncrypt: false }
      ]
    }]
  };

  private static instance: UserProfileRepositoryImpl = new UserProfileRepositoryImpl();
  private context: common.Context | null = null;
  private cloudDb: AGConnectCloudDB | null = null;
  private cloudDbZone: CloudDBZone | null = null;
  private openZoneInFlight: Promise<CloudDBZone> | null = null;

  public static getInstance(): UserProfileRepositoryImpl {
    return UserProfileRepositoryImpl.instance;
  }

  public static buildDefaultUsername(): string {
    const suffix = Math.floor(Math.random() * 9000) + 1000;
    return `\u65C5\u884C\u8005${suffix}`;
  }

  public bindContext(context: common.Context): void {
    this.context = context;
  }

  public async getByAccountId(accountId: string): Promise<UserProfileEntity | null> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      return null;
    }
    const zone = await this.ensureCloudDbZone();
    const query = CloudDBZoneQuery.where(UserProfile)
      .equalTo('accountId', safeAccountId)
      .limit(1);
    let rows: UserProfile[] = [];
    try {
      const snapshot = await zone.executeQuery(query);
      rows = snapshot.getSnapshotObjects();
    } catch (error) {
      const reason = this.normalizeError(error);
      hilog.error(
        UserProfileRepositoryImpl.LOG_DOMAIN,
        UserProfileRepositoryImpl.LOG_TAG,
        `[PROFILE_TRACE][repo] query fail accountId=${safeAccountId}, reason=${reason}`
      );
      throw new Error(reason);
    }
    hilog.info(
      UserProfileRepositoryImpl.LOG_DOMAIN,
      UserProfileRepositoryImpl.LOG_TAG,
      `[PROFILE_TRACE][repo] query accountId=${safeAccountId}, rowCount=${rows ? rows.length : 0}`
    );
    if (!rows || rows.length === 0) {
      return null;
    }
    return this.toEntity(rows[0]);
  }

  public async createDefaultProfile(accountId: string): Promise<UserProfileEntity> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      throw new Error('account_id_required');
    }
    const existing = await this.getByAccountId(safeAccountId);
    if (existing) {
      return existing;
    }

    const now = Date.now();
    const profile = new UserProfileEntity();
    profile.profileId = safeAccountId;
    profile.accountId = safeAccountId;
    profile.username = UserProfileRepositoryImpl.buildDefaultUsername();
    profile.avatarPath = UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH;
    profile.avatarVersion = 1;
    profile.isInitialized = true;
    profile.createdAt = now;
    profile.updatedAt = now;

    const zone = await this.ensureCloudDbZone();
    try {
      await zone.executeUpsert(this.toCloudRecord(profile));
      hilog.info(
        UserProfileRepositoryImpl.LOG_DOMAIN,
        UserProfileRepositoryImpl.LOG_TAG,
        `[PROFILE_TRACE][repo] upsert default success accountId=${safeAccountId}`
      );
    } catch (error) {
      const reason = this.normalizeError(error);
      hilog.error(
        UserProfileRepositoryImpl.LOG_DOMAIN,
        UserProfileRepositoryImpl.LOG_TAG,
        `[PROFILE_TRACE][repo] upsert default fail accountId=${safeAccountId}, reason=${reason}`
      );
      throw new Error(reason);
    }
    try {
      const latest = await this.getByAccountId(safeAccountId);
      return latest || profile;
    } catch (_error) {
      return profile;
    }
  }

  public async updateUsername(accountId: string, username: string): Promise<UserProfileEntity> {
    const safeAccountId = this.normalizeAccountId(accountId);
    const normalizedUsername = String(username || '').trim();
    if (!safeAccountId) {
      throw new Error('account_id_required');
    }
    if (!normalizedUsername) {
      throw new Error('username_required');
    }

    const baseProfile = await this.createDefaultProfile(safeAccountId);
    const nextProfile = this.cloneEntity(baseProfile);
    nextProfile.username = normalizedUsername;
    nextProfile.updatedAt = Date.now();

    const zone = await this.ensureCloudDbZone();
    await zone.executeUpsert(this.toCloudRecord(nextProfile));
    hilog.info(
      UserProfileRepositoryImpl.LOG_DOMAIN,
      UserProfileRepositoryImpl.LOG_TAG,
      `[PROFILE_TRACE][repo] upsert username success accountId=${safeAccountId}`
    );
    return nextProfile;
  }

  public async updateAvatar(accountId: string, avatarPath: string, avatarVersion: number): Promise<UserProfileEntity> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      throw new Error('account_id_required');
    }

    const baseProfile = await this.createDefaultProfile(safeAccountId);
    const nextProfile = this.cloneEntity(baseProfile);
    nextProfile.avatarPath = String(avatarPath || '').trim();
    nextProfile.avatarVersion = Number.isFinite(avatarVersion) && avatarVersion > 0
      ? Math.floor(avatarVersion)
      : Math.max(1, Math.floor(baseProfile.avatarVersion + 1));
    nextProfile.updatedAt = Date.now();

    const zone = await this.ensureCloudDbZone();
    await zone.executeUpsert(this.toCloudRecord(nextProfile));
    hilog.info(
      UserProfileRepositoryImpl.LOG_DOMAIN,
      UserProfileRepositoryImpl.LOG_TAG,
      `[PROFILE_TRACE][repo] upsert avatar success accountId=${safeAccountId}`
    );
    return nextProfile;
  }

  private async ensureCloudDbZone(): Promise<CloudDBZone> {
    if (this.cloudDbZone) {
      return this.cloudDbZone;
    }
    if (this.openZoneInFlight) {
      return this.openZoneInFlight;
    }
    this.openZoneInFlight = this.openCloudDbZoneInternal()
      .then((zone: CloudDBZone) => {
        this.cloudDbZone = zone;
        return zone;
      })
      .finally(() => {
        this.openZoneInFlight = null;
      });
    return this.openZoneInFlight;
  }

  private async openCloudDbZoneInternal(): Promise<CloudDBZone> {
    if (!this.context) {
      throw new Error('cloud_db_context_required');
    }
    const appContext = this.context.getApplicationContext();
    agconnect.instance().init(appContext);
    if (!this.cloudDb) {
      this.cloudDb = await AGConnectCloudDB.getInstance({
        context: appContext,
        agcRoutePolicy: AGCRoutePolicy.CHINA,
        objectTypeInfo: UserProfileRepositoryImpl.CLOUD_DB_OBJECT_TYPE_INFO
      });
    }
    let lastError: Object | undefined = undefined;
    for (let index = 0; index < UserProfileRepositoryImpl.CLOUD_DB_ZONE_NAMES.length; index += 1) {
      const zoneName = UserProfileRepositoryImpl.CLOUD_DB_ZONE_NAMES[index];
      try {
        const zoneConfig = new CloudDBZoneConfig(zoneName);
        const zone = await this.cloudDb.openCloudDBZone(zoneConfig);
        hilog.info(
          UserProfileRepositoryImpl.LOG_DOMAIN,
          UserProfileRepositoryImpl.LOG_TAG,
          `[PROFILE_TRACE][repo] open zone success name=${zoneName}`
        );
        return zone;
      } catch (error) {
        lastError = error;
        hilog.warn(
          UserProfileRepositoryImpl.LOG_DOMAIN,
          UserProfileRepositoryImpl.LOG_TAG,
          `[PROFILE_TRACE][repo] open zone fail name=${zoneName}, reason=${this.normalizeError(error)}`
        );
      }
    }
    throw new Error(`cloud_db_zone_open_failed:${this.normalizeError(lastError)}`);
  }

  private toEntity(record: UserProfile): UserProfileEntity {
    const entity = new UserProfileEntity();
    entity.accountId = String(record.accountId || '').trim();
    entity.profileId = entity.accountId;
    entity.username = String(record.username || '').trim();
    entity.avatarPath = String(record.avatarPath || '').trim();
    entity.avatarVersion = Number.isFinite(Number(record.avatarVersion)) ? Math.max(1, Math.floor(Number(record.avatarVersion))) : 1;
    entity.isInitialized = Boolean(record.isInitialized);
    entity.createdAt = this.toTimestamp(record.createdAt);
    entity.updatedAt = this.toTimestamp(record.updatedAt);
    return entity;
  }

  private toCloudRecord(entity: UserProfileEntity): UserProfile {
    const record = new UserProfile();
    record.accountId = entity.accountId;
    record.username = entity.username;
    record.avatarPath = entity.avatarPath;
    record.avatarVersion = entity.avatarVersion;
    record.isInitialized = entity.isInitialized;
    // Cloud DB Long 字段在当前 SDK 下直接写 number 可能触发类型不匹配，
    // 先交由云端默认值/空值处理，读取时再做容错转换。
    record.createdAt = undefined;
    record.updatedAt = undefined;
    return record;
  }

  private toTimestamp(rawValue: Object | number | undefined): number {
    if (!rawValue) {
      return 0;
    }
    if (typeof rawValue === 'number') {
      return Number(rawValue);
    }
    const maybeWithToNumber = rawValue as TimestampLike;
    if (typeof maybeWithToNumber.toNumber === 'function') {
      const value = Number(maybeWithToNumber.toNumber());
      return Number.isFinite(value) ? value : 0;
    }
    if (typeof maybeWithToNumber.toString === 'function') {
      const parsed = Number(maybeWithToNumber.toString());
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private cloneEntity(profile: UserProfileEntity): UserProfileEntity {
    const clone = new UserProfileEntity();
    clone.profileId = profile.profileId;
    clone.accountId = profile.accountId;
    clone.username = profile.username;
    clone.avatarPath = profile.avatarPath;
    clone.avatarVersion = profile.avatarVersion;
    clone.isInitialized = profile.isInitialized;
    clone.createdAt = profile.createdAt;
    clone.updatedAt = profile.updatedAt;
    return clone;
  }

  private normalizeAccountId(accountId: string): string {
    return String(accountId || '').trim();
  }

  private normalizeError(error: Object | undefined): string {
    if (error instanceof Error) {
      return error.message || 'cloud_db_error';
    }
    const message = (error as Record<string, Object> | undefined)?.message;
    if (typeof message === 'string' && message.trim().length > 0) {
      return message;
    }
    try {
      return JSON.stringify(error);
    } catch (_jsonError) {
      return 'cloud_db_error';
    }
  }
}
