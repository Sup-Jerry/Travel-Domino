import { common } from '@kit.AbilityKit';
import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { UserProfileEntity } from '../../domain/entity/UserProfileEntity';

export class ProfileCacheManager {
  private static instance: ProfileCacheManager = new ProfileCacheManager();
  private context: common.Context | null = null;
  private readonly memoryCache: Map<string, UserProfileEntity> = new Map<string, UserProfileEntity>();

  public static getInstance(): ProfileCacheManager {
    return ProfileCacheManager.instance;
  }

  public bindContext(context: common.Context): void {
    this.context = context;
  }

  public async readProfile(accountId: string): Promise<UserProfileEntity | null> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      return null;
    }
    const memory = this.memoryCache.get(safeAccountId);
    if (memory) {
      return this.cloneProfile(memory);
    }
    if (!this.context) {
      return null;
    }

    const pref = PreferenceManager.getInstance();
    await pref.init(this.context);
    const raw = await pref.getProfileCacheJson(safeAccountId);
    const parsed = this.parseProfile(raw);
    if (!parsed) {
      return null;
    }
    this.memoryCache.set(safeAccountId, this.cloneProfile(parsed));
    return parsed;
  }

  public async writeProfile(profile: UserProfileEntity): Promise<void> {
    const safeAccountId = this.normalizeAccountId(profile.accountId);
    if (!safeAccountId) {
      return;
    }

    const safeProfile = this.cloneProfile(profile);
    safeProfile.accountId = safeAccountId;
    safeProfile.profileId = safeAccountId;
    this.memoryCache.set(safeAccountId, safeProfile);

    if (!this.context) {
      return;
    }
    const pref = PreferenceManager.getInstance();
    await pref.init(this.context);
    await pref.setProfileCacheJson(safeAccountId, JSON.stringify(safeProfile));
  }

  public async clearProfile(accountId: string): Promise<void> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      return;
    }
    this.memoryCache.delete(safeAccountId);
    if (!this.context) {
      return;
    }
    const pref = PreferenceManager.getInstance();
    await pref.init(this.context);
    await pref.clearProfileCache(safeAccountId);
  }

  public clearAllMemory(): void {
    this.memoryCache.clear();
  }

  private parseProfile(raw: string): UserProfileEntity | null {
    if (!raw) {
      return null;
    }
    try {
      const parsed = JSON.parse(raw) as UserProfileEntity;
      const safeAccountId = this.normalizeAccountId(parsed.accountId);
      if (!safeAccountId) {
        return null;
      }
      const profile = new UserProfileEntity();
      profile.profileId = safeAccountId;
      profile.accountId = safeAccountId;
      profile.username = String(parsed.username || '').trim();
      profile.avatarPath = String(parsed.avatarPath || '').trim();
      profile.avatarVersion = Number.isFinite(Number(parsed.avatarVersion))
        ? Math.max(1, Math.floor(Number(parsed.avatarVersion)))
        : 1;
      profile.isInitialized = parsed.isInitialized === true;
      profile.createdAt = Number.isFinite(Number(parsed.createdAt)) ? Number(parsed.createdAt) : 0;
      profile.updatedAt = Number.isFinite(Number(parsed.updatedAt)) ? Number(parsed.updatedAt) : 0;
      return profile;
    } catch (_error) {
      return null;
    }
  }

  private cloneProfile(profile: UserProfileEntity): UserProfileEntity {
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
}
