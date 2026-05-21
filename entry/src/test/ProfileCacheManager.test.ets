import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { ProfileCacheManager } from '../main/ets/infrastructure/cache/ProfileCacheManager';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';

function createProfile(accountId: string, username: string): UserProfileEntity {
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

class PreferenceManagerMockForProfileCache {
  rawProfile: string = '';

  async init(_context: common.Context): Promise<void> {
  }

  async getProfileCacheJson(_accountId: string): Promise<string> {
    return this.rawProfile;
  }
}

async function readProfileFromRaw(accountId: string, rawProfile: string): Promise<UserProfileEntity | null> {
  const cache = ProfileCacheManager.getInstance();
  const pref = new PreferenceManagerMockForProfileCache();
  const prefOrigin = Reflect.get(PreferenceManager as Object, 'getInstance') as Object;
  pref.rawProfile = rawProfile;
  cache.clearAllMemory();
  cache.bindContext({} as common.Context);
  Reflect.set(PreferenceManager as Object, 'getInstance', (): PreferenceManagerMockForProfileCache => pref);
  try {
    return await cache.readProfile(accountId);
  } finally {
    Reflect.set(PreferenceManager as Object, 'getInstance', prefOrigin);
    cache.clearAllMemory();
  }
}

export default function profileCacheManagerTest() {
  describe('profileCacheManagerTest', () => {
    it('normal: profile_cache_key_should_include_account_id', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(PreferenceManager.buildProfileCacheKey('acc_a')).assertEqual('profile_cache_acc_a');
      expect(PreferenceManager.buildProfileCacheKey('')).assertEqual('profile_cache_guest_local');
    });

    it('normal: profile_cache_should_be_isolated_between_accounts', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const cache = ProfileCacheManager.getInstance();
      cache.clearAllMemory();

      await cache.writeProfile(createProfile('acc_a', 'A'));
      await cache.writeProfile(createProfile('acc_b', 'B'));

      const profileA = await cache.readProfile('acc_a');
      const profileB = await cache.readProfile('acc_b');
      const profileC = await cache.readProfile('acc_c');

      expect(String(profileA?.username || '')).assertEqual('A');
      expect(String(profileB?.username || '')).assertEqual('B');
      expect(profileC === null).assertTrue();
      done();
    });
  });
  describe('unit_test_case_generator_autofill_ProfileCacheManager', () => {
    it('boundary: profile_cache_should_trim_account_id_when_writing_and_reading', 0, async (done: () => void) => {
      // Arrange
      const cache = ProfileCacheManager.getInstance();
      cache.clearAllMemory();
      const profile = createProfile('  acc_trim  ', 'Trimmed');

      // Act
      await cache.writeProfile(profile);
      const loaded = await cache.readProfile('acc_trim');

      // Assert
      expect(loaded !== null).assertTrue();
      expect(String(loaded?.accountId || '')).assertEqual('acc_trim');
      expect(String(loaded?.profileId || '')).assertEqual('acc_trim');
      cache.clearAllMemory();
      done();
    });

    it('invalid: profile_cache_should_ignore_blank_account_id', 0, async (done: () => void) => {
      // Arrange
      const cache = ProfileCacheManager.getInstance();
      cache.clearAllMemory();
      const profile = createProfile('   ', 'Nobody');

      // Act
      await cache.writeProfile(profile);
      const loaded = await cache.readProfile('   ');

      // Assert
      expect(loaded === null).assertTrue();
      cache.clearAllMemory();
      done();
    });

    it('conflict: profile_cache_should_keep_latest_profile_for_same_account', 0, async (done: () => void) => {
      // Arrange
      const cache = ProfileCacheManager.getInstance();
      cache.clearAllMemory();
      const first = createProfile('dup_acc', 'First');
      const second = createProfile('dup_acc', 'Second');
      second.avatarVersion = 3;

      // Act
      await cache.writeProfile(first);
      await cache.writeProfile(second);
      const loaded = await cache.readProfile('dup_acc');

      // Assert
      expect(loaded !== null).assertTrue();
      expect(String(loaded?.username || '')).assertEqual('Second');
      expect(Number(loaded?.avatarVersion || 0)).assertEqual(3);
      cache.clearAllMemory();
      done();
    });

    it('regression: profile_cache_should_return_clone_without_mutating_memory_snapshot', 0, async (done: () => void) => {
      // Arrange
      const cache = ProfileCacheManager.getInstance();
      cache.clearAllMemory();
      await cache.writeProfile(createProfile('clone_acc', 'Origin'));
      const loaded = await cache.readProfile('clone_acc');
      if (loaded) {
        loaded.username = 'Mutated';
      }

      // Act
      const reloaded = await cache.readProfile('clone_acc');

      // Assert
      expect(String(reloaded?.username || '')).assertEqual('Origin');
      cache.clearAllMemory();
      done();
    });

    it('combined: profile_cache_should_mix_write_read_and_clear_across_multiple_accounts', 0, async (done: () => void) => {
      // Arrange
      const cache = ProfileCacheManager.getInstance();
      cache.clearAllMemory();
      await cache.writeProfile(createProfile('mix_a', 'Alpha'));
      await cache.writeProfile(createProfile('mix_b', 'Beta'));

      // Act
      await cache.clearProfile('mix_a');
      const profileA = await cache.readProfile('mix_a');
      const profileB = await cache.readProfile('mix_b');

      // Assert
      expect(profileA === null).assertTrue();
      expect(String(profileB?.username || '')).assertEqual('Beta');
      cache.clearAllMemory();
      done();
    });

    it('boundary: profile_cache_read_profile_should_return_null_for_empty_raw', 0, async (done: () => void) => {
      // Arrange
      const raw = '';

      // Act
      const parsed = await readProfileFromRaw('empty_raw_acc', raw);

      // Assert
      expect(parsed === null).assertTrue();
      done();
    });

    it('invalid: profile_cache_read_profile_should_return_null_for_blank_account_id', 0, async (done: () => void) => {
      // Arrange
      const raw = JSON.stringify({
        accountId: '   ',
        username: 'Nobody',
        avatarPath: 'avatar.png',
        avatarVersion: 2,
        isInitialized: true,
        createdAt: 10,
        updatedAt: 11
      });

      // Act
      const parsed = await readProfileFromRaw('blank_account_acc', raw);

      // Assert
      expect(parsed === null).assertTrue();
      done();
    });

    it('regression: profile_cache_read_profile_should_fallback_invalid_numbers_to_defaults', 0, async (done: () => void) => {
      // Arrange
      const raw = JSON.stringify({
        accountId: ' profile_num ',
        username: ' Number User ',
        avatarPath: ' avatar.png ',
        avatarVersion: 'bad',
        isInitialized: false,
        createdAt: 'oops',
        updatedAt: null
      });

      // Act
      const parsed = await readProfileFromRaw('profile_num', raw);

      // Assert
      expect(parsed !== null).assertTrue();
      expect(String(parsed?.accountId || '')).assertEqual('profile_num');
      expect(String(parsed?.profileId || '')).assertEqual('profile_num');
      expect(String(parsed?.username || '')).assertEqual('Number User');
      expect(String(parsed?.avatarPath || '')).assertEqual('avatar.png');
      expect(Number(parsed?.avatarVersion || 0)).assertEqual(1);
      expect(Number(parsed?.createdAt ?? -1)).assertEqual(0);
      expect(Number(parsed?.updatedAt ?? -1)).assertEqual(0);
      done();
    });

    it('invalid: profile_cache_read_profile_should_return_null_for_invalid_json', 0, async (done: () => void) => {
      // Arrange
      const raw = '{invalid_json';

      // Act
      const parsed = await readProfileFromRaw('invalid_json_acc', raw);

      // Assert
      expect(parsed === null).assertTrue();
      done();
    });
  });
}
