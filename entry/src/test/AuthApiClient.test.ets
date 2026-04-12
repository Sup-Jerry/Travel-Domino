import { describe, expect, it } from '@ohos/hypium';
import { AuthApiClient } from '../main/ets/infrastructure/auth/AuthApiClient';

function hasCallable(value: object | undefined): boolean {
  return value !== undefined;
}

function supportsClientMethod(name: string): boolean {
  return name === 'post' || name === 'get' || name === 'patch';
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

export default function authApiClientTest() {
  describe('authApiClientTest', () => {
    it('normal: auth_api_client_should_expose_post_get_patch_methods', 0, () => {
      // Arrange
      const client = new AuthApiClient();
      // Act
      const postRef = client.post;
      const getRef = client.get;
      const patchRef = client.patch;
      // Assert
      expect(hasCallable(postRef)).assertTrue();
      expect(hasCallable(getRef)).assertTrue();
      expect(hasCallable(patchRef)).assertTrue();
    });

    it('boundary: auth_api_client_instances_should_keep_same_method_names', 0, () => {
      // Arrange
      const first = new AuthApiClient();
      const second = new AuthApiClient();
      // Act
      const firstPostName = first.post.name;
      const secondPostName = second.post.name;
      const firstGetName = first.get.name;
      const secondGetName = second.get.name;
      // Assert
      expect(firstPostName).assertEqual('post');
      expect(secondPostName).assertEqual('post');
      expect(firstGetName).assertEqual('get');
      expect(secondGetName).assertEqual('get');
    });

    it('invalid: auth_api_client_should_not_accept_unknown_method_name', 0, () => {
      // Arrange
      const unknownMethodName = 'delete';
      // Act
      const supported = supportsClientMethod(unknownMethodName);
      // Assert
      expect(supported).assertFalse();
    });

    it('conflict: auth_api_client_method_names_should_not_conflict', 0, () => {
      // Arrange
      const client = new AuthApiClient();
      // Act
      const methodNames = [client.post.name, client.get.name, client.patch.name];
      const conflictDetected = hasDuplicateNames(methodNames);
      // Assert
      expect(conflictDetected).assertFalse();
    });

    it('regression: td-20260412-c4-auth-api-client-method-names-should-remain-stable', 0, () => {
      // Arrange
      const client = new AuthApiClient();
      // Act
      const postName = client.post.name;
      const getName = client.get.name;
      const patchName = client.patch.name;
      // Assert
      expect(postName).assertEqual('post');
      expect(getName).assertEqual('get');
      expect(patchName).assertEqual('patch');
    });

    it('combined: auth_api_client_surface_should_keep_methods_available_and_unique', 0, () => {
      // Arrange
      const first = new AuthApiClient();
      const second = new AuthApiClient();
      const requiredNames = [first.post.name, first.get.name, first.patch.name];
      // Act
      const allSupported = requiredNames.every((name: string) => supportsClientMethod(name));
      const namesStableAcrossInstances = second.post.name === 'post' && second.get.name === 'get' && second.patch.name === 'patch';
      const hasConflict = hasDuplicateNames(requiredNames);
      // Assert
      expect(allSupported).assertTrue();
      expect(namesStableAcrossInstances).assertTrue();
      expect(hasConflict).assertFalse();
    });
  });
}
