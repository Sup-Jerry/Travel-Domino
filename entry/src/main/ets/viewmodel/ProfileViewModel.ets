import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { UserProfileEntity } from '../domain/entity/UserProfileEntity';
import { IUserProfileRepository } from '../domain/ports/IUserProfileRepository';
import { ProfileCacheManager } from '../infrastructure/cache/ProfileCacheManager';
import { UserProfileRepositoryImpl } from '../infrastructure/persistence/UserProfileRepositoryImpl';

export type ProfileViewState = 'loading' | 'ready' | 'offline' | 'error';

export interface IProfileCacheStore {
  readProfile(accountId: string): Promise<UserProfileEntity | null>;
  writeProfile(profile: UserProfileEntity): Promise<void>;
  clearProfile(accountId: string): Promise<void>;
  clearAllMemory(): void;
}

export class ProfileViewModel {
  private static readonly LOG_DOMAIN: number = 0x0000;
  private static readonly LOG_TAG: string = 'ProfileViewModel';
  public static readonly DEFAULT_AVATAR_PATH: string = UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH;
  private static instance: ProfileViewModel = new ProfileViewModel();

  private readonly repositoryImpl: UserProfileRepositoryImpl;
  private readonly repository: IUserProfileRepository;
  private readonly cacheManager: IProfileCacheStore;
  private state: ProfileViewState = 'loading';
  private profile: UserProfileEntity | null = null;
  private currentAccountId: string = '';

  public constructor(
    repositoryImpl?: UserProfileRepositoryImpl,
    repository?: IUserProfileRepository,
    cacheManager?: IProfileCacheStore
  ) {
    this.repositoryImpl = repositoryImpl || UserProfileRepositoryImpl.getInstance();
    this.repository = repository || this.repositoryImpl;
    this.cacheManager = cacheManager || ProfileCacheManager.getInstance();
  }

  public static getInstance(): ProfileViewModel {
    return ProfileViewModel.instance;
  }

  public bindContext(context: common.Context): void {
    this.repositoryImpl.bindContext(context);
    const cache = this.cacheManager as ProfileCacheManager;
    if (typeof cache.bindContext === 'function') {
      cache.bindContext(context);
    }
  }

  public getState(): ProfileViewState {
    return this.state;
  }

  public getProfile(): UserProfileEntity | null {
    return this.profile ? this.cloneProfile(this.profile) : null;
  }

  public reset(): void {
    this.state = 'loading';
    this.profile = null;
    this.currentAccountId = '';
    this.cacheManager.clearAllMemory();
  }

  public async bootstrap(accountId: string): Promise<UserProfileEntity | null> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      this.reset();
      return null;
    }

    this.currentAccountId = safeAccountId;
    this.state = 'loading';
    let cachedProfile: UserProfileEntity | null = null;
    try {
      cachedProfile = await this.cacheManager.readProfile(safeAccountId);
      if (cachedProfile) {
        this.profile = this.cloneProfile(cachedProfile);
        this.state = 'ready';
      }
    } catch (_error) {
      cachedProfile = null;
    }

    try {
      let cloudProfile = await this.repository.getByAccountId(safeAccountId);
      if (!cloudProfile) {
        cloudProfile = await this.repository.createDefaultProfile(safeAccountId);
      }
      await this.cacheManager.writeProfile(cloudProfile);
      this.profile = this.cloneProfile(cloudProfile);
      this.state = 'ready';
      return this.cloneProfile(cloudProfile);
    } catch (error) {
      if (cachedProfile) {
        this.profile = this.cloneProfile(cachedProfile);
        this.state = 'offline';
        hilog.warn(ProfileViewModel.LOG_DOMAIN, ProfileViewModel.LOG_TAG, `[PROFILE_TRACE][vm] bootstrap offline accountId=${safeAccountId}`);
        return this.cloneProfile(cachedProfile);
      }
      this.profile = null;
      this.state = 'error';
      hilog.error(
        ProfileViewModel.LOG_DOMAIN,
        ProfileViewModel.LOG_TAG,
        `[PROFILE_TRACE][vm] bootstrap failed accountId=${safeAccountId}, reason=${this.normalizeError(error)}`
      );
      return null;
    }
  }

  public async ensureProfile(accountId: string): Promise<UserProfileEntity | null> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      return null;
    }
    this.currentAccountId = safeAccountId;
    this.state = 'loading';
    hilog.info(ProfileViewModel.LOG_DOMAIN, ProfileViewModel.LOG_TAG, `[PROFILE_TRACE][vm] ensure start accountId=${safeAccountId}`);
    try {
      const profile = await this.repository.createDefaultProfile(safeAccountId);
      await this.cacheManager.writeProfile(profile);
      this.profile = this.cloneProfile(profile);
      this.state = 'ready';
      hilog.info(ProfileViewModel.LOG_DOMAIN, ProfileViewModel.LOG_TAG, `[PROFILE_TRACE][vm] ensure ready accountId=${safeAccountId}`);
      return this.cloneProfile(profile);
    } catch (error) {
      let cachedProfile: UserProfileEntity | null = null;
      try {
        cachedProfile = await this.cacheManager.readProfile(safeAccountId);
      } catch (_cacheError) {
        cachedProfile = null;
      }
      if (cachedProfile) {
        this.profile = this.cloneProfile(cachedProfile);
        this.state = 'offline';
        hilog.warn(ProfileViewModel.LOG_DOMAIN, ProfileViewModel.LOG_TAG, `[PROFILE_TRACE][vm] ensure offline accountId=${safeAccountId}`);
        return this.cloneProfile(cachedProfile);
      }
      this.profile = null;
      this.state = 'error';
      hilog.error(
        ProfileViewModel.LOG_DOMAIN,
        ProfileViewModel.LOG_TAG,
        `[PROFILE_TRACE][vm] ensure failed accountId=${safeAccountId}, reason=${this.normalizeError(error)}`
      );
      return null;
    }
  }

  public async updateUsername(accountId: string, username: string): Promise<UserProfileEntity | null> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      return null;
    }
    try {
      const profile = await this.repository.updateUsername(safeAccountId, username);
      await this.cacheManager.writeProfile(profile);
      this.profile = this.cloneProfile(profile);
      this.state = 'ready';
      return this.cloneProfile(profile);
    } catch (_error) {
      return this.bootstrap(safeAccountId);
    }
  }

  public async updateAvatar(accountId: string, avatarPath: string, avatarVersion: number): Promise<UserProfileEntity | null> {
    const safeAccountId = this.normalizeAccountId(accountId);
    if (!safeAccountId) {
      return null;
    }
    try {
      const profile = await this.repository.updateAvatar(safeAccountId, avatarPath, avatarVersion);
      await this.cacheManager.writeProfile(profile);
      this.profile = this.cloneProfile(profile);
      this.state = 'ready';
      return this.cloneProfile(profile);
    } catch (_error) {
      return this.bootstrap(safeAccountId);
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

  private normalizeError(error: Object): string {
    if (error instanceof Error) {
      return error.message || 'profile_error';
    }
    const message = (error as Record<string, Object>)?.message;
    if (typeof message === 'string' && message.trim().length > 0) {
      return message;
    }
    try {
      return JSON.stringify(error);
    } catch (_jsonError) {
      return 'profile_error';
    }
  }
}
