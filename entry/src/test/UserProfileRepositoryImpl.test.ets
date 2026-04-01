import { describe, expect, it } from '@ohos/hypium';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';

export default function userProfileRepositoryImplTest() {
  describe('userProfileRepositoryImplTest', () => {
    it('default_username_should_match_pattern', 0, () => {
      const username = UserProfileRepositoryImpl.buildDefaultUsername();
      expect(/^旅行者\d{4}$/.test(username)).assertTrue();
    });

    it('default_avatar_path_should_use_local_placeholder_resource', 0, () => {
      expect(UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH).assertEqual('app.media.headphoto');
    });
  });
}
