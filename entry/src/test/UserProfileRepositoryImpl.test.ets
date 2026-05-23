import { describe, expect, it } from '@ohos/hypium';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';

export default function userProfileRepositoryImplTest() {
  describe('userProfileRepositoryImplTest', () => {
    it('normal: default_username_should_match_pattern', 0, () => {
      // Arrange
      // Act
      // Assert
      const username = UserProfileRepositoryImpl.buildDefaultUsername();
      expect(/^旅行者\d{4}$/.test(username)).assertTrue();
    });

    it('normal: default_avatar_path_should_use_local_placeholder_resource', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH).assertEqual('app.media.headphoto');
    });
  });
  describe('unit_test_case_generator_autofill_UserProfileRepositoryImpl', () => {
    it('boundary: generated_username_should_keep_fixed_prefix_and_four_digit_suffix', 0, () => {
      // Arrange
      const username = UserProfileRepositoryImpl.buildDefaultUsername();

      // Act
      const suffix = username.substring(3);

      // Assert
      expect(username.indexOf('旅行者')).assertEqual(0);
      expect(suffix.length).assertEqual(4);
      expect(/^\d{4}$/.test(suffix)).assertTrue();
    });

    it('invalid: generated_username_should_never_contain_whitespace_or_placeholder_avatar_path', 0, () => {
      // Arrange
      const username = UserProfileRepositoryImpl.buildDefaultUsername();

      // Act
      const hasWhitespace = /\s/.test(username);
      const avatarPath = UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH;

      // Assert
      expect(hasWhitespace).assertFalse();
      expect(avatarPath).assertEqual('app.media.headphoto');
    });

    it('conflict: singleton_repository_instance_should_remain_stable_across_repeated_access', 0, () => {
      // Arrange
      const first = UserProfileRepositoryImpl.getInstance();

      // Act
      const second = UserProfileRepositoryImpl.getInstance();

      // Assert
      expect(first === second).assertTrue();
    });

    it('regression: generated_username_should_stay_within_expected_numeric_range', 0, () => {
      // Arrange
      const username = UserProfileRepositoryImpl.buildDefaultUsername();

      // Act
      const suffix = Number(username.substring(3));

      // Assert
      expect(suffix >= 1000).assertTrue();
      expect(suffix <= 9999).assertTrue();
    });

    it('combined: singleton_username_and_avatar_defaults_should_coordinate_for_profile_bootstrap_contract', 0, () => {
      // Arrange
      const repository = UserProfileRepositoryImpl.getInstance();
      const username = UserProfileRepositoryImpl.buildDefaultUsername();
      const avatarPath = UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH;

      // Act
      const looksLikeDefaultProfile = (repository !== null) &&
        /^旅行者\d{4}$/.test(username) &&
        avatarPath === 'app.media.headphoto';

      // Assert
      expect(looksLikeDefaultProfile).assertTrue();
    });
  });
}
