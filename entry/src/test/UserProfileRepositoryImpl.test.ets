import { describe, expect, it } from '@ohos/hypium';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';

interface TimestampCarrierForUserProfileTest {
  toNumber?: () => number;
  toString?: () => string;
}

interface NumberReaderForUserProfileTest {
  toNumber?: () => number;
}

class NaNNumberCarrierForUserProfileTest implements TimestampCarrierForUserProfileTest {
  toNumber(): number {
    return Number.NaN;
  }
}

class InvalidStringCarrierForUserProfileTest implements TimestampCarrierForUserProfileTest {
  toString(): string {
    return 'not_number';
  }
}

class InvalidTimestampCarrierForUserProfileTest implements TimestampCarrierForUserProfileTest {
  toNumber(): number {
    return Number.NaN;
  }

  toString(): string {
    return 'still_invalid';
  }
}

class ProfileRecordForUserProfileTest {
  accountId: string = '';
  username: string = '';
  avatarPath: string = '';
  avatarVersion: Object = '';
  isInitialized: number = 0;
  createdAt: Object = new Object();
  updatedAt: Object = new Object();
}

interface UserProfileRepositoryPrivateForTest {
  ensureCloudDbZone: () => Promise<Object>;
  toEntity: (record: Object) => UserProfileEntity;
  toCloudRecord: (entity: UserProfileEntity) => Object;
  toTimestamp: (rawValue: Object | number | undefined) => number;
}

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

    it('boundary: ensure_cloud_db_zone_should_return_cached_zone_without_reopening', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepositoryPrivateForTest;
      const cachedZone = new Object();
      Reflect.set(repo as Object, 'cloudDbZone', cachedZone);
      // Act
      const zone = await repo.ensureCloudDbZone();
      // Assert
      expect(zone === cachedZone).assertTrue();
    });

    it('invalid: update_username_should_throw_when_account_id_blank_even_if_name_present', 0, async () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl();
      let message = '';
      // Act
      try {
        await repo.updateUsername('   ', 'valid_name');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('account_id_required');
    });

    it('regression: private_entity_and_record_helpers_should_fallback_invalid_avatar_and_timestamps', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepositoryPrivateForTest;
      const input = new UserProfileEntity();
      input.accountId = 'acc_private';
      input.username = 'Private';
      input.avatarPath = 'avatar.png';
      input.avatarVersion = 3;
      input.isInitialized = true;
      input.createdAt = 0;
      input.updatedAt = -1;
      const record = new ProfileRecordForUserProfileTest();
      record.accountId = ' acc_private ';
      record.username = ' Private ';
      record.avatarPath = ' avatar.png ';
      record.avatarVersion = 'bad_version';
      record.isInitialized = 1;
      record.createdAt = new NaNNumberCarrierForUserProfileTest() as Object;
      record.updatedAt = new InvalidStringCarrierForUserProfileTest() as Object;
      // Act
      const entity = repo.toEntity(record as Object);
      const cloudRecord = repo.toCloudRecord(input);
      const createdAt = Reflect.get(cloudRecord, 'createdAt') as NumberReaderForUserProfileTest;
      const updatedAt = Reflect.get(cloudRecord, 'updatedAt') as NumberReaderForUserProfileTest;
      // Assert
      expect(entity.accountId).assertEqual('acc_private');
      expect(entity.avatarVersion).assertEqual(1);
      expect(entity.createdAt).assertEqual(0);
      expect(entity.updatedAt).assertEqual(0);
      expect((createdAt.toNumber?.() ?? 0) > 0).assertTrue();
      expect((updatedAt.toNumber?.() ?? 0) > 0).assertTrue();
    });

    it('combined: private_timestamp_helper_should_return_zero_when_to_number_and_to_string_are_invalid', 0, () => {
      // Arrange
      const repo = new UserProfileRepositoryImpl() as Object as UserProfileRepositoryPrivateForTest;
      const carrier = new InvalidTimestampCarrierForUserProfileTest();
      // Act
      const timestamp = repo.toTimestamp(carrier as Object);
      // Assert
      expect(timestamp).assertEqual(0);
    });
  });
}
