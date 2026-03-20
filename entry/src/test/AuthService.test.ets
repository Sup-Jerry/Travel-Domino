import { describe, expect, it } from '@ohos/hypium';
import { AuthService } from '../main/ets/infrastructure/auth/AuthService';
import { AuthErrorCode } from '../main/ets/infrastructure/auth/AuthErrorCode';
import { DeviceInfo, SocialCredential } from '../main/ets/domain/auth/AuthModels';

export default function authServiceTest() {
  describe('authServiceTest', () => {
    it('phone_login_should_not_create_duplicate_user', 0, () => {
      const service = AuthService.getInstance();
      service.resetForTest();

      const code1 = service.debugIssuePhoneCode('13800138000');
      const first = service.loginWithPhone('13800138000', '+86', code1, true, new DeviceInfo('d1', 'dev1', 'HARMONY'));

      const code2 = service.debugIssuePhoneCode('13800138000');
      const second = service.loginWithPhone('13800138000', '+86', code2, true, new DeviceInfo('d2', 'dev2', 'HARMONY'));

      expect(first.code).assertEqual(0);
      expect(second.code).assertEqual(0);
      expect(first.data.user.userId).assertEqual(second.data.user.userId);
      expect(first.data.isNewUser).assertEqual(true);
      expect(second.data.isNewUser).assertEqual(false);
    });

    it('unbind_should_block_last_login_method', 0, () => {
      const service = AuthService.getInstance();
      service.resetForTest();

      const code = service.debugIssuePhoneCode('13900139000');
      const login = service.loginWithPhone('13900139000', '+86', code, true, new DeviceInfo('d1', 'dev1', 'HARMONY'));

      const unbind = service.unbind(login.data.session.accessToken, 'PHONE');
      expect(unbind.code).assertEqual(AuthErrorCode.LAST_LOGIN_METHOD_CANNOT_UNBIND);
    });

    it('social_first_login_should_return_pending_action', 0, () => {
      const service = AuthService.getInstance();
      service.resetForTest();

      const credential = new SocialCredential();
      credential.authCode = 'wx_auth_1';
      credential.openId = 'wx_open_1';

      const result = service.loginWithSocial('WECHAT', credential, true, new DeviceInfo('d1', 'dev1', 'HARMONY'));
      expect(result.code).assertEqual(0);
      expect(result.data.action).assertEqual('NEED_BIND_OR_CREATE');
    });

    it('agreement_should_block_phone_login', 0, () => {
      const service = AuthService.getInstance();
      service.resetForTest();

      const code = service.debugIssuePhoneCode('13700137000');
      const login = service.loginWithPhone('13700137000', '+86', code, false, new DeviceInfo('d1', 'dev1', 'HARMONY'));
      expect(login.code).assertEqual(AuthErrorCode.AGREEMENT_NOT_ACCEPTED);
    });

    it('guest_upgrade_should_mark_migration_done', 0, () => {
      const service = AuthService.getInstance();
      service.resetForTest();

      const guest = service.createGuest(new DeviceInfo('gd1', 'guest', 'HARMONY'));

      const code = service.debugIssuePhoneCode('13600136000');
      const user = service.loginWithPhone('13600136000', '+86', code, true, new DeviceInfo('d1', 'dev1', 'HARMONY'));

      const upgrade = service.upgradeGuest(guest.data.user.userId, user.data.user.userId);
      expect(upgrade.code).assertEqual(0);
      expect(upgrade.data.migrateStatus).assertEqual('DONE');
    });
  });
}
