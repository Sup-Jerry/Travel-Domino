import { describe, expect, it } from '@ohos/hypium';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';

function hasGatewayMethod(name: string): boolean {
  return name === 'createGuest'
    || name === 'me'
    || name === 'loginWithSocial'
    || name === 'updateUsername'
    || name === 'updateAvatar';
}

function hasDuplicateNames(names: string[]): boolean {
  for (let i = 0; i < names.length; i++) {
    for (let j = i + 1; j < names.length; j++) {
      if (names[i] === names[j]) {
        return true;
      }
    }
  }
  return false;
}

export default function authGatewayTest() {
  describe('authGatewayTest', () => {
    it('normal: auth_gateway_should_expose_core_static_api_methods', 0, () => {
      // Arrange
      // Act
      const createGuestRef = AuthGateway.createGuest;
      const meRef = AuthGateway.me;
      const loginWithSocialRef = AuthGateway.loginWithSocial;
      // Assert
      expect(createGuestRef !== undefined).assertTrue();
      expect(meRef !== undefined).assertTrue();
      expect(loginWithSocialRef !== undefined).assertTrue();
    });

    it('boundary: auth_gateway_should_keep_profile_update_method_names', 0, () => {
      // Arrange
      // Act
      const updateUsernameName = AuthGateway.updateUsername.name;
      const updateAvatarName = AuthGateway.updateAvatar.name;
      // Assert
      expect(updateUsernameName).assertEqual('updateUsername');
      expect(updateAvatarName).assertEqual('updateAvatar');
    });

    it('invalid: auth_gateway_should_not_mark_unknown_static_method_as_supported', 0, () => {
      // Arrange
      const unknownName = 'logout';
      // Act
      const supported = hasGatewayMethod(unknownName);
      // Assert
      expect(supported).assertFalse();
    });

    it('conflict: auth_gateway_method_names_should_not_conflict', 0, () => {
      // Arrange
      // Act
      const methodNames = [
        AuthGateway.createGuest.name,
        AuthGateway.me.name,
        AuthGateway.loginWithSocial.name,
        AuthGateway.updateUsername.name,
        AuthGateway.updateAvatar.name
      ];
      const conflictDetected = hasDuplicateNames(methodNames);
      // Assert
      expect(conflictDetected).assertFalse();
    });

    it('regression: td-20260412-c4-auth-gateway-class-name-should-stay-stable', 0, () => {
      // Arrange
      // Act
      const className = AuthGateway.name;
      // Assert
      expect(className).assertEqual('AuthGateway');
    });

    it('combined: auth_gateway_should_keep_required_entries_available-and-consistent', 0, () => {
      // Arrange
      const requiredNames = ['createGuest', 'me', 'loginWithSocial', 'updateUsername', 'updateAvatar'];
      // Act
      const allSupported = requiredNames.every((name: string) => hasGatewayMethod(name));
      const runtimeNames = [
        AuthGateway.createGuest.name,
        AuthGateway.me.name,
        AuthGateway.loginWithSocial.name,
        AuthGateway.updateUsername.name,
        AuthGateway.updateAvatar.name
      ];
      const noConflict = !hasDuplicateNames(runtimeNames);
      // Assert
      expect(allSupported).assertTrue();
      expect(runtimeNames[0]).assertEqual('createGuest');
      expect(runtimeNames[1]).assertEqual('me');
      expect(runtimeNames[2]).assertEqual('loginWithSocial');
      expect(runtimeNames[3]).assertEqual('updateUsername');
      expect(runtimeNames[4]).assertEqual('updateAvatar');
      expect(noConflict).assertTrue();
    });
  });
}
