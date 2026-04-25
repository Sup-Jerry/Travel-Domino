import { Want } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import EntryAbility from '../main/ets/entryability/EntryAbility';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';

class WantStubGO {
  uri: string = '';
}

class AbilityConfigGO {
  colorMode: number = 0;
}

class AbilityContextGO {
  config: AbilityConfigGO = new AbilityConfigGO();
}

class LaunchParamGO {
}

class AbilityHostGO {
  context: AbilityContextGO = new AbilityContextGO();
  currentThemeMode: string = 'system';
  handleNotificationLaunchWantCount: number = 0;
  handleDeepLinkWantCount: number = 0;
  lastWantUri: string = '';

  handleNotificationLaunchWant(want: Want): void {
    this.handleNotificationLaunchWantCount += 1;
    this.lastWantUri = want.uri ?? '';
  }

  handleDeepLinkWant(want: Want): void {
    this.handleDeepLinkWantCount += 1;
    this.lastWantUri = want.uri ?? '';
  }

  runOnNewWant(want: Want, launchParam: Object): void {
    invokeEntryAbilityMethodGO(onNewWantGO, this, want, launchParam);
  }

  runOnForeground(): void {
    invokeEntryAbilityMethodGO(onForegroundGO, this);
  }

  runOnBackground(): void {
    invokeEntryAbilityMethodGO(onBackgroundGO, this);
  }

  runOnDestroy(): void {
    invokeEntryAbilityMethodGO(onDestroyGO, this);
  }

  runOnWindowStageDestroy(): void {
    invokeEntryAbilityMethodGO(onWindowStageDestroyGO, this);
  }
}

function getEntryAbilityMethodGO<T>(name: string): T {
  const prototype = Reflect.get(EntryAbility as Object, 'prototype') as Object;
  return Reflect.get(prototype, name) as T;
}

function invokeEntryAbilityMethodGO<THost, TResult, TArgs extends (Object | Want)[]>(
  method: (this: THost, ...args: TArgs) => TResult,
  host: THost,
  ...args: TArgs
): TResult {
  const bound = method.bind(host) as (...boundArgs: TArgs) => TResult;
  return bound(...args);
}

const onNewWantGO = getEntryAbilityMethodGO<(this: AbilityHostGO, want: Want, launchParam: Object) => void>('onNewWant');
const onForegroundGO = getEntryAbilityMethodGO<(this: AbilityHostGO) => void>('onForeground');
const onBackgroundGO = getEntryAbilityMethodGO<(this: AbilityHostGO) => void>('onBackground');
const onDestroyGO = getEntryAbilityMethodGO<(this: AbilityHostGO) => void>('onDestroy');
const onWindowStageDestroyGO = getEntryAbilityMethodGO<(this: AbilityHostGO) => void>('onWindowStageDestroy');

export default function phase2BatchGOTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGO_entry_ability_foreground_and_want_lines', () => {
    it('combined: entry_ability_on_new_want_should_forward_notification_and_deep_link_handlers', 0, () => {
      const host = new AbilityHostGO();
      const want = new WantStubGO() as Want;
      want.uri = 'travelapp://import?plan=1';

      host.runOnNewWant(want, new LaunchParamGO());

      expect(host.handleNotificationLaunchWantCount).assertEqual(1);
      expect(host.handleDeepLinkWantCount).assertEqual(1);
      expect(host.lastWantUri).assertEqual('travelapp://import?plan=1');
    });

    it('combined: entry_ability_on_foreground_should_sync_system_mode_only_and_lifecycle_noops_should_not_throw', 0, () => {
      const host = new AbilityHostGO();
      host.context.config.colorMode = 2;

      host.currentThemeMode = 'system';
      host.runOnForeground();
      const systemMode = AppStorage.get<string>(ThemeCenter.STORAGE_THEME_MODE) ?? '';
      const systemEffective = AppStorage.get<string>(ThemeCenter.STORAGE_EFFECTIVE_THEME) ?? '';
      host.currentThemeMode = 'dark';
      host.runOnForeground();
      const afterDarkMode = AppStorage.get<string>(ThemeCenter.STORAGE_THEME_MODE) ?? '';
      const afterDarkEffective = AppStorage.get<string>(ThemeCenter.STORAGE_EFFECTIVE_THEME) ?? '';
      host.runOnBackground();
      host.runOnDestroy();
      host.runOnWindowStageDestroy();

      expect(systemMode).assertEqual('system');
      expect(systemEffective.length > 0).assertTrue();
      expect(afterDarkMode).assertEqual('system');
      expect(afterDarkEffective).assertEqual(systemEffective);
    });
  });
}
