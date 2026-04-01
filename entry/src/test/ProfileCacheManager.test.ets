import { describe, expect, it } from '@ohos/hypium';
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

export default function profileCacheManagerTest() {
  describe('profileCacheManagerTest', () => {
    it('profile_cache_key_should_include_account_id', 0, () => {
      expect(PreferenceManager.buildProfileCacheKey('acc_a')).assertEqual('profile_cache_acc_a');
      expect(PreferenceManager.buildProfileCacheKey('')).assertEqual('profile_cache_guest_local');
    });

    it('profile_cache_should_be_isolated_between_accounts', 0, async (done: () => void) => {
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
}
