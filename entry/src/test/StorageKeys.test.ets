import { describe, it, expect } from '@ohos/hypium';
import { StorageKeys } from '../main/ets/common/constants/StorageKeys';

export default function storageKeysTest() {
  describe('storageKeysTest', () => {
    it('normal: storage_keys_profile_cache_key_should_use_account_id', 0, () => {
      // Arrange
      const accountId = 'u100';

      // Act
      const key = StorageKeys.buildProfileCacheKey(accountId);

      // Assert
      expect(key).assertEqual('profile_cache_u100');
    });

    it('boundary: storage_keys_avatar_cache_key_should_trim_account_id', 0, () => {
      // Arrange
      const accountId = '  user_x  ';

      // Act
      const key = StorageKeys.buildAvatarCacheKey(accountId);

      // Assert
      expect(key).assertEqual('avatar_cache_user_x');
    });

    it('invalid: storage_keys_should_fallback_to_guest_local_when_account_id_empty', 0, () => {
      // Arrange
      const accountId = '';

      // Act
      const profileKey = StorageKeys.buildProfileCacheKey(accountId);
      const avatarKey = StorageKeys.buildAvatarCacheKey(accountId);

      // Assert
      expect(profileKey).assertEqual('profile_cache_guest_local');
      expect(avatarKey).assertEqual('avatar_cache_guest_local');
    });

    it('conflict: storage_keys_profile_and_avatar_prefix_should_stay_isolated', 0, () => {
      // Arrange
      const accountId = 'same_user';

      // Act
      const profileKey = StorageKeys.buildProfileCacheKey(accountId);
      const avatarKey = StorageKeys.buildAvatarCacheKey(accountId);

      // Assert
      expect(profileKey === avatarKey).assertFalse();
    });

    it('regression: td-20260412-storage_keys_session_cache_constant_should_stay_stable', 0, () => {
      // Arrange
      const key = StorageKeys.SESSION_CACHE;

      // Act
      const stable = key === 'session_cache';

      // Assert
      expect(stable).assertTrue();
    });

    it('combined: storage_keys_builders_should_support_trim_and_guest_fallback_together', 0, () => {
      // Arrange
      const profileTrimmed = StorageKeys.buildProfileCacheKey('  abc  ');
      const avatarFallback = StorageKeys.buildAvatarCacheKey('   ');

      // Act
      const valid = profileTrimmed === 'profile_cache_abc' && avatarFallback === 'avatar_cache_guest_local';

      // Assert
      expect(valid).assertTrue();
    });
  });
}
