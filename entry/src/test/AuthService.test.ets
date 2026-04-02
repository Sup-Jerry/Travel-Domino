import { describe, expect, it } from '@ohos/hypium';
import { AuthService } from '../main/ets/infrastructure/auth/AuthService';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import { DeviceInfo, SocialCredential, UpdateUsernamePayload } from '../main/ets/domain/auth/AuthModels';

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

export default function authServiceTest() {
  describe('authServiceTest', () => {
    it('social_login_default_username_should_not_be_empty', 0, () => {
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_0`), new DeviceInfo('d0', 'dev0', 'HARMONY'));
      expect(login.code).assertEqual(0);
      const defaultName = String(login.data.user.nickname || '').trim();
      expect(defaultName.length > 0).assertTrue();
      expect(String(login.data.user.accountId || '').length > 0).assertTrue();
    });

    it('update_username_should_succeed_for_social_user', 0, () => {
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_1`), new DeviceInfo('d1', 'dev1', 'HARMONY'));
      expect(login.code).assertEqual(0);

      const updated = service.updateUsername(login.data.session.accessToken, makeUsernamePayload('旅行者_01'));
      expect(updated.code).assertEqual(0);
      expect(updated.data.nickname).assertEqual('旅行者_01');
    });

    it('update_username_should_reject_guest_user', 0, () => {
      const service = AuthService.getInstance();
      const guest = service.createGuest(new DeviceInfo(`gd_${Date.now()}`, 'guest', 'HARMONY'));
      expect(guest.code).assertEqual(0);

      const updated = service.updateUsername(guest.data.session.accessToken, makeUsernamePayload('guest_name'));
      expect(updated.code).assertEqual(AuthErrorCode.GUEST_USERNAME_UNSUPPORTED);
    });

    it('update_username_should_reject_invalid_pattern', 0, () => {
      const service = AuthService.getInstance();
      const login = service.loginWithSocial('HUAWEI', makeSocialCredential(`uid_${Date.now()}_2`), new DeviceInfo('d2', 'dev2', 'HARMONY'));
      expect(login.code).assertEqual(0);

      const updated = service.updateUsername(login.data.session.accessToken, makeUsernamePayload('@@@'));
      expect(updated.code).assertEqual(AuthErrorCode.USERNAME_INVALID);
    });

    it('update_username_should_allow_duplicates', 0, () => {
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

  });
}
