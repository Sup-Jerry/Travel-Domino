import { Want } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import EntryAbility from '../main/ets/entryability/EntryAbility';

class EntryAbilityWantDQ {
  uri?: string;
  parameters?: Record<string, Object>;
}

class EntryAbilityHostDQ {
  public currentThemeMode: string = 'light';
  public notificationCount: number = 0;
  public deepLinkCount: number = 0;
  public notificationUri: string = '';
  public deepLinkUri: string = '';

  handleNotificationLaunchWant(want: Want): void {
    this.notificationCount += 1;
    this.notificationUri = want.uri ?? '';
  }

  handleDeepLinkWant(want: Want): void {
    this.deepLinkCount += 1;
    this.deepLinkUri = want.uri ?? '';
  }
}

function getEntryAbilityMethodDQ<T>(name: string): T {
  const prototype = Reflect.get(EntryAbility as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeEntryAbilityMethodDQ<THost, TResult, TArgs extends (Object | Want)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

function createWantDQ(uri: string): Want {
  const want = new EntryAbilityWantDQ();
  want.uri = uri;
  return want as Want;
}

const onDestroyDQ = getEntryAbilityMethodDQ<(this: EntryAbilityHostDQ) => void>('onDestroy');
const onWindowStageDestroyDQ = getEntryAbilityMethodDQ<(this: EntryAbilityHostDQ) => void>('onWindowStageDestroy');
const onBackgroundDQ = getEntryAbilityMethodDQ<(this: EntryAbilityHostDQ) => void>('onBackground');
const onForegroundDQ = getEntryAbilityMethodDQ<(this: EntryAbilityHostDQ) => void>('onForeground');
const onNewWantDQ = getEntryAbilityMethodDQ<(this: EntryAbilityHostDQ, want: Want, launchParam: Object) => void>('onNewWant');

export default function phase2BatchDQTest() {
  describe('phase2BatchDQTest', () => {
    it('normal: entry_ability_on_new_want_should_dispatch_notification_and_deep_link_handlers', 0, () => {
      // Arrange
      const host = new EntryAbilityHostDQ();
      const want = createWantDQ('travelapp://import?batch=dq');

      // Act
      invokeEntryAbilityMethodDQ(onNewWantDQ, host, want, new Object());

      // Assert
      expect(host.notificationCount).assertEqual(1);
      expect(host.deepLinkCount).assertEqual(1);
      expect(host.notificationUri).assertEqual('travelapp://import?batch=dq');
      expect(host.deepLinkUri).assertEqual('travelapp://import?batch=dq');
    });

    it('boundary: entry_ability_destroy_lifecycle_methods_should_not_throw', 0, () => {
      // Arrange
      const host = new EntryAbilityHostDQ();
      let threw = false;

      // Act
      try {
        invokeEntryAbilityMethodDQ(onDestroyDQ, host);
        invokeEntryAbilityMethodDQ(onWindowStageDestroyDQ, host);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('invalid: entry_ability_background_should_not_require_context', 0, () => {
      // Arrange
      const host = new EntryAbilityHostDQ();
      let threw = false;

      // Act
      try {
        invokeEntryAbilityMethodDQ(onBackgroundDQ, host);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('conflict: entry_ability_foreground_should_skip_system_theme_sync_for_fixed_mode', 0, () => {
      // Arrange
      const host = new EntryAbilityHostDQ();
      host.currentThemeMode = 'dark';
      let threw = false;

      // Act
      try {
        invokeEntryAbilityMethodDQ(onForegroundDQ, host);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(host.currentThemeMode).assertEqual('dark');
    });

    it('regression: entry_ability_on_new_want_should_preserve_dispatch_order_across_repeated_wants', 0, () => {
      // Arrange
      const host = new EntryAbilityHostDQ();
      const first = createWantDQ('travelapp://import?batch=dq-1');
      const second = createWantDQ('travelapp://import?batch=dq-2');

      // Act
      invokeEntryAbilityMethodDQ(onNewWantDQ, host, first, new Object());
      invokeEntryAbilityMethodDQ(onNewWantDQ, host, second, new Object());

      // Assert
      expect(host.notificationCount).assertEqual(2);
      expect(host.deepLinkCount).assertEqual(2);
      expect(host.notificationUri).assertEqual('travelapp://import?batch=dq-2');
      expect(host.deepLinkUri).assertEqual('travelapp://import?batch=dq-2');
    });

    it('combined: entry_ability_lifecycle_sequence_should_run_without_state_corruption', 0, () => {
      // Arrange
      const host = new EntryAbilityHostDQ();
      host.currentThemeMode = 'light';
      const want = createWantDQ('travelapp://import?batch=dq-combined');
      let threw = false;

      // Act
      try {
        invokeEntryAbilityMethodDQ(onNewWantDQ, host, want, new Object());
        invokeEntryAbilityMethodDQ(onForegroundDQ, host);
        invokeEntryAbilityMethodDQ(onBackgroundDQ, host);
        invokeEntryAbilityMethodDQ(onDestroyDQ, host);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(host.notificationCount).assertEqual(1);
      expect(host.deepLinkCount).assertEqual(1);
      expect(host.currentThemeMode).assertEqual('light');
    });
  });
}
