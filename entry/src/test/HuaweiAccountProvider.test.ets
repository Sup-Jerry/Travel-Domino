import { describe, expect, it } from '@ohos/hypium';
import { HuaweiAccountProvider } from '../main/ets/infrastructure/auth/HuaweiAccountProvider';

class AuthCredentialMock {
  authorizationCode: string = '';
  idToken: string = '';
  openID: string = '';
  unionID: string = '';
}

export default function huaweiAccountProviderTest() {
  describe('huaweiAccountProviderTest', () => {
    it('normal: get_instance_should_return_singleton_instance', 0, () => {
      // Arrange
      // Act
      const first = HuaweiAccountProvider.getInstance();
      const second = HuaweiAccountProvider.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('boundary: from_authentication_credential_should_keep_full_fields', 0, () => {
      // Arrange
      const provider = HuaweiAccountProvider.getInstance();
      const credential = new AuthCredentialMock();
      credential.authorizationCode = 'code_b';
      credential.idToken = 'token_b';
      credential.openID = 'openid_b';
      credential.unionID = 'unionid_b';
      // Act
      const normalized = provider.fromAuthenticationCredential(credential as never);
      // Assert
      expect(normalized.authorizationCode).assertEqual('code_b');
      expect(normalized.idToken).assertEqual('token_b');
      expect(normalized.openId).assertEqual('openid_b');
      expect(normalized.unionId).assertEqual('unionid_b');
    });

    it('invalid: from_authentication_credential_should_convert_missing_values_to_empty', 0, () => {
      // Arrange
      const provider = HuaweiAccountProvider.getInstance();
      const credential = new AuthCredentialMock();
      // Act
      const normalized = provider.fromAuthenticationCredential(credential as never);
      // Assert
      expect(normalized.authorizationCode).assertEqual('');
      expect(normalized.idToken).assertEqual('');
      expect(normalized.openId).assertEqual('');
      expect(normalized.unionId).assertEqual('');
    });

    it('conflict: from_authentication_credential_should_allow_openid_unionid_to_differ', 0, () => {
      // Arrange
      const provider = HuaweiAccountProvider.getInstance();
      const credential = new AuthCredentialMock();
      credential.openID = 'open_x';
      credential.unionID = 'union_y';
      // Act
      const normalized = provider.fromAuthenticationCredential(credential as never);
      // Assert
      expect(normalized.openId).assertEqual('open_x');
      expect(normalized.unionId).assertEqual('union_y');
    });

    it('regression: td-20260412-c4-openid-should-map-from-openID-field', 0, () => {
      // Arrange
      const provider = HuaweiAccountProvider.getInstance();
      const credential = new AuthCredentialMock();
      credential.openID = 'openid_regression';
      // Act
      const normalized = provider.fromAuthenticationCredential(credential as never);
      // Assert
      expect(normalized.openId).assertEqual('openid_regression');
    });

    it('combined: normalize_two_credentials_should_keep_each_result_isolated', 0, () => {
      // Arrange
      const provider = HuaweiAccountProvider.getInstance();
      const first = new AuthCredentialMock();
      first.authorizationCode = 'code_1';
      const second = new AuthCredentialMock();
      second.authorizationCode = 'code_2';
      // Act
      const firstNormalized = provider.fromAuthenticationCredential(first as never);
      const secondNormalized = provider.fromAuthenticationCredential(second as never);
      // Assert
      expect(firstNormalized.authorizationCode).assertEqual('code_1');
      expect(secondNormalized.authorizationCode).assertEqual('code_2');
      expect(firstNormalized.authorizationCode === secondNormalized.authorizationCode).assertFalse();
    });
  });
}
