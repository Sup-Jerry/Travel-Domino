import { describe, it, expect } from '@ohos/hypium';
import { BundleVersion } from '@kit.CoreFileKit';
import EntryBackupAbility from '../main/ets/entrybackupability/EntryBackupAbility';

export default function entryBackupAbilityTest() {
  describe('entryBackupAbilityTest', () => {
    it('normal: entry_backup_ability_on_backup_should_resolve', 0, async (done: () => void) => {
      // Arrange
      const ability = new EntryBackupAbility();

      // Act
      await ability.onBackup();

      // Assert
      expect(true).assertTrue();
      done();
    });

    it('boundary: entry_backup_ability_on_restore_should_resolve_with_empty_bundle_version', 0, async (done: () => void) => {
      // Arrange
      const ability = new EntryBackupAbility();
      const bundleVersion = {} as BundleVersion;

      // Act
      await ability.onRestore(bundleVersion);

      // Assert
      expect(true).assertTrue();
      done();
    });

    it('regression: td-20260412-entry_backup_ability_lifecycle_should_return_promise', 0, () => {
      // Arrange
      const ability = new EntryBackupAbility();

      // Act
      const backupPromise = ability.onBackup();

      // Assert
      expect(typeof (backupPromise as Object)).assertEqual('object');
    });

    it('invalid: entry_backup_ability_on_restore_should_accept_sparse_bundle_version_object', 0, async (done: () => void) => {
      // Arrange
      const ability = new EntryBackupAbility();
      const bundleVersion = { name: '', code: 0 } as BundleVersion;

      // Act
      await ability.onRestore(bundleVersion);

      // Assert
      expect(true).assertTrue();
      done();
    });

    it('conflict: entry_backup_ability_backup_then_restore_should_not_throw', 0, async (done: () => void) => {
      // Arrange
      const ability = new EntryBackupAbility();
      const bundleVersion = {} as BundleVersion;

      // Act
      await ability.onBackup();
      await ability.onRestore(bundleVersion);

      // Assert
      expect(true).assertTrue();
      done();
    });

    it('combined: entry_backup_ability_lifecycle_promises_should_be_awaitable_in_sequence', 0, async (done: () => void) => {
      // Arrange
      const ability = new EntryBackupAbility();
      const bundleVersion = {} as BundleVersion;

      // Act
      const backupPromise = ability.onBackup();
      await backupPromise;
      await ability.onRestore(bundleVersion);

      // Assert
      expect(typeof (backupPromise as Object)).assertEqual('object');
      done();
    });
  });
}
