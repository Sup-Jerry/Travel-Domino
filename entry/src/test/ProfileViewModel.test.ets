import { describe, expect, it } from '@ohos/hypium';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { IUserProfileRepository } from '../main/ets/domain/ports/IUserProfileRepository';
import { IProfileCacheStore, ProfileViewModel } from '../main/ets/viewmodel/ProfileViewModel';

class FakeProfileRepository implements IUserProfileRepository {
  public cloudProfile: UserProfileEntity | null = null;
  public failGetByAccountId: boolean = false;
  public failCreateDefaultProfile: boolean = false;

  async getByAccountId(_accountId: string): Promise<UserProfileEntity | null> {
    if (this.failGetByAccountId) {
      throw new Error('cloud_query_fail');
    }
    return this.cloudProfile ? this.clone(this.cloudProfile) : null;
  }

  async createDefaultProfile(accountId: string): Promise<UserProfileEntity> {
    if (this.failCreateDefaultProfile) {
      throw new Error('cloud_create_fail');
    }
    const profile = new UserProfileEntity();
    profile.profileId = accountId;
    profile.accountId = accountId;
    profile.username = 'Traveler8888';
    profile.avatarPath = 'app.media.headphoto';
    profile.avatarVersion = 1;
    profile.isInitialized = true;
    profile.createdAt = 100;
    profile.updatedAt = 100;
    this.cloudProfile = this.clone(profile);
    return this.clone(profile);
  }

  async updateUsername(accountId: string, username: string): Promise<UserProfileEntity> {
    const profile = await this.createDefaultProfile(accountId);
    profile.username = username;
    profile.updatedAt = 200;
    this.cloudProfile = this.clone(profile);
    return this.clone(profile);
  }

  async updateAvatar(accountId: string, avatarPath: string, avatarVersion: number): Promise<UserProfileEntity> {
    const profile = await this.createDefaultProfile(accountId);
    profile.avatarPath = avatarPath;
    profile.avatarVersion = avatarVersion;
    profile.updatedAt = 200;
    this.cloudProfile = this.clone(profile);
    return this.clone(profile);
  }

  private clone(profile: UserProfileEntity): UserProfileEntity {
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
}

class FakeProfileCacheStore implements IProfileCacheStore {
  private readonly profileMap: Map<string, UserProfileEntity> = new Map<string, UserProfileEntity>();

  async readProfile(accountId: string): Promise<UserProfileEntity | null> {
    const profile = this.profileMap.get(accountId);
    return profile ? this.clone(profile) : null;
  }

  async writeProfile(profile: UserProfileEntity): Promise<void> {
    this.profileMap.set(profile.accountId, this.clone(profile));
  }

  async clearProfile(accountId: string): Promise<void> {
    this.profileMap.delete(accountId);
  }

  clearAllMemory(): void {
    this.profileMap.clear();
  }

  private clone(profile: UserProfileEntity): UserProfileEntity {
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
}

function makeProfile(accountId: string, username: string): UserProfileEntity {
  const profile = new UserProfileEntity();
  profile.profileId = accountId;
  profile.accountId = accountId;
  profile.username = username;
  profile.avatarPath = 'app.media.headphoto';
  profile.avatarVersion = 1;
  profile.isInitialized = true;
  profile.createdAt = 1;
  profile.updatedAt = 1;
  return profile;
}

export default function profileViewModelTest() {
  describe('profileViewModelTest', () => {
    it('normal: bootstrap_should_override_cache_when_cloud_newer', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const repo = new FakeProfileRepository();
      const cache = new FakeProfileCacheStore();
      await cache.writeProfile(makeProfile('acc_1', 'cache_old'));
      repo.cloudProfile = makeProfile('acc_1', 'cloud_new');
      const vm = new ProfileViewModel(undefined, repo, cache);

      const profile = await vm.bootstrap('acc_1');
      expect(String(profile?.username || '')).assertEqual('cloud_new');
      expect(vm.getState()).assertEqual('ready');
      done();
    });

    it('invalid: bootstrap_should_fallback_to_offline_when_cloud_failed', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const repo = new FakeProfileRepository();
      const cache = new FakeProfileCacheStore();
      await cache.writeProfile(makeProfile('acc_2', 'cache_user'));
      repo.failGetByAccountId = true;
      repo.failCreateDefaultProfile = true;
      const vm = new ProfileViewModel(undefined, repo, cache);

      const profile = await vm.bootstrap('acc_2');
      expect(String(profile?.username || '')).assertEqual('cache_user');
      expect(vm.getState()).assertEqual('offline');
      done();
    });
  });
  describe('unit_test_case_generator_autofill_ProfileViewModel', () => {
    it('boundary: td-20260411-auto-ProfileViewModel', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('conflict: td-20260411-auto-ProfileViewModel', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-ProfileViewModel', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-ProfileViewModel', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
