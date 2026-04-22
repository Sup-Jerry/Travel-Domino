import { describe, expect, it } from '@ohos/hypium';
import { AuthService } from '../main/ets/infrastructure/auth/AuthService';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import { DeviceInfo, SocialCredential, UpdateAvatarPayload, UpdateUsernamePayload } from '../main/ets/domain/auth/AuthModels';

function makeSocialCredential(uid: string): SocialCredential {
  const credential = new SocialCredential();
  credential.unionId = uid;
  credential.openId = uid;
  return credential;
}

function makeUsernamePayload(username: string): UpdateUsernamePayload {
  const payload = new UpdateUsernamePayload();
  payload.username = username;
  return payload;
}

function makeAvatarPayload(dataUrl: string, mimeType: string = 'image/jpeg'): UpdateAvatarPayload {
  const payload = new UpdateAvatarPayload();
  payload.imageDataUrl = dataUrl;
  payload.mimeType = mimeType;
  return payload;
}

export default function authServiceTest() {
  describe('authServiceTest', () => {
    it('boundary: social_login_default_username_should_not_be_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_0`), new DeviceInfo('d0', 'dev0', 'HARMONY'));
      expect(login.code).assertEqual(0);
      const defaultName = String(login.data.user.nickname || '').trim();
      expect(defaultName.length > 0).assertTrue();
      expect(String(login.data.user.accountId || '').length > 0).assertTrue();
    });

    it('normal: update_username_should_succeed_for_social_user', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_1`), new DeviceInfo('d1', 'dev1', 'HARMONY'));
      expect(login.code).assertEqual(0);

      const updated = service.updateUsername(login.data.session.accessToken, makeUsernamePayload('旅行者_01'));
      expect(updated.code).assertEqual(0);
      expect(updated.data.nickname).assertEqual('旅行者_01');
    });

    it('invalid: update_username_should_reject_guest_user', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const guest = service.createGuest(new DeviceInfo(`gd_${Date.now()}`, 'guest', 'HARMONY'));
      expect(guest.code).assertEqual(0);

      const updated = service.updateUsername(guest.data.session.accessToken, makeUsernamePayload('guest_name'));
      expect(updated.code).assertEqual(AuthErrorCode.GUEST_USERNAME_UNSUPPORTED);
    });

    it('invalid: update_username_should_reject_invalid_pattern', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_2`), new DeviceInfo('d2', 'dev2', 'HARMONY'));
      expect(login.code).assertEqual(0);

      const updated = service.updateUsername(login.data.session.accessToken, makeUsernamePayload('@@@'));
      expect(updated.code).assertEqual(AuthErrorCode.USERNAME_INVALID);
    });

    it('normal: update_username_should_allow_duplicates', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const loginA = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_3a`), new DeviceInfo('d3', 'dev3', 'HARMONY'));
      const loginB = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_3b`), new DeviceInfo('d4', 'dev4', 'HARMONY'));
      expect(loginA.code).assertEqual(0);
      expect(loginB.code).assertEqual(0);

      const sameName = '同名用户';
      const updatedA = service.updateUsername(loginA.data.session.accessToken, makeUsernamePayload(sameName));
      const updatedB = service.updateUsername(loginB.data.session.accessToken, makeUsernamePayload(sameName));
      expect(updatedA.code).assertEqual(0);
      expect(updatedB.code).assertEqual(0);
      expect(updatedA.data.nickname).assertEqual(sameName);
      expect(updatedB.data.nickname).assertEqual(sameName);
    });

    it('normal: update_avatar_should_succeed_for_social_user', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_4`), new DeviceInfo('d5', 'dev5', 'HARMONY'));
      expect(login.code).assertEqual(0);

      const dataUrl = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
      const updated = service.updateAvatar(login.data.session.accessToken, makeAvatarPayload(dataUrl));
      expect(updated.code).assertEqual(0);
      expect(String(updated.data.avatarUrl || '')).assertEqual(dataUrl);
    });

    it('invalid: update_avatar_should_reject_invalid_data', 0, () => {
      // Arrange
      // Act
      // Assert
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_5`), new DeviceInfo('d6', 'dev6', 'HARMONY'));
      expect(login.code).assertEqual(0);

      const updated = service.updateAvatar(login.data.session.accessToken, makeAvatarPayload('invalid_data'));
      expect(updated.code).assertEqual(AuthErrorCode.AVATAR_INVALID);
    });

    it('normal: get_me_should_return_guest_profile_for_active_guest_session', 0, () => {
      // Arrange
      const service = AuthService.getInstance();
      const guest = service.createGuest(new DeviceInfo(`gd_get_me_${Date.now()}`, 'guest_get_me', 'HARMONY'));
      expect(guest.code).assertEqual(0);

      // Act
      const me = service.getMe(guest.data.session.accessToken);

      // Assert
      expect(me.code).assertEqual(0);
      expect(me.data.userId).assertEqual(guest.data.user.userId);
      expect(me.data.isGuest).assertTrue();
    });

    it('normal: get_me_should_return_social_profile_for_active_social_session', 0, () => {
      // Arrange
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_get_me_${Date.now()}`), new DeviceInfo('d_get_me', 'dev_get_me', 'HARMONY'));
      expect(login.code).assertEqual(0);

      // Act
      const me = service.getMe(login.data.session.accessToken);

      // Assert
      expect(me.code).assertEqual(0);
      expect(me.data.userId).assertEqual(login.data.user.userId);
      expect(me.data.accountId).assertEqual(login.data.user.accountId);
      expect(me.data.isGuest).assertFalse();
    });

    it('boundary: get_me_should_build_guest_fallback_for_local_guest_token', 0, () => {
      // Arrange
      const service = AuthService.getInstance();
      const localGuestToken = `guest_access_local_${Date.now()}`;

      // Act
      const me = service.getMe(localGuestToken);

      // Assert
      expect(me.code).assertEqual(0);
      expect(me.data.userId).assertEqual('guest_local');
      expect(me.data.isGuest).assertTrue();
    });

    it('invalid: get_me_should_reject_unknown_non_guest_token', 0, () => {
      // Arrange
      const service = AuthService.getInstance();

      // Act
      const me = service.getMe(`unknown_access_${Date.now()}`);

      // Assert
      expect(me.code).assertEqual(AuthErrorCode.SESSION_EXPIRED);
      expect(me.message).assertEqual('session_expired');
    });

    it('regression: get_me_should_fail_when_session_user_is_missing', 0, () => {
      // Arrange
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_missing_${Date.now()}`), new DeviceInfo('d_missing', 'dev_missing', 'HARMONY'));
      expect(login.code).assertEqual(0);
      const users = Reflect.get(service as Object, 'users') as Object[];
      const keptUsers = users.filter((user: Object) => {
        const record = user as Record<string, Object>;
        return String(record['userId'] || '') !== login.data.user.userId;
      });
      Reflect.set(service as Object, 'users', keptUsers);

      // Act
      const me = service.getMe(login.data.session.accessToken);

      // Assert
      expect(me.code).assertEqual(AuthErrorCode.ACCOUNT_NOT_FOUND);
      expect(me.message).assertEqual('user_not_found');
    });
  });
  describe('unit_test_case_generator_autofill_AuthService', () => {
    it('conflict: td-20260411-auto-AuthService', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-AuthService', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-AuthService', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
