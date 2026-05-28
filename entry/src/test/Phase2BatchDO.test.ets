import { describe, it, expect } from '@ohos/hypium';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import {
  createSettingsPrivacyPageForTest,
  resolveAmapRouteApiToggleToast
} from '../main/ets/pages/SettingsPrivacyPage';

interface SettingsPrivacyPaletteDO {
  textPrimary: Object;
  pageBg: Object;
  cardBg: Object;
}

interface SettingsPrivacyPagePrivateDO {
  enableAmapRouteApi: boolean;
  loading: boolean;
  effectiveTheme: string;
  getThemePalette(): SettingsPrivacyPaletteDO;
  aboutToAppear(): void;
  safeShowToast(message: string): void;
  reload(): Promise<void>;
  onAmapRouteApiChanged(value: boolean): Promise<void>;
  handleAmapRouteApiToggle(value: boolean): Promise<void>;
  initialRender(): void;
}

class PreferenceMockDO {
  public enabled: boolean = false;
  public failSet: boolean = false;
  public failRead: boolean = false;
  public setCalls: boolean[] = [];

  async isAmapRouteApiEnabled(): Promise<boolean> {
    if (this.failRead) {
      throw new Error('read_failed_do');
    }
    return this.enabled;
  }

  async setAmapRouteApiEnabled(value: boolean): Promise<void> {
    this.setCalls.push(value);
    if (this.failSet) {
      throw new Error('set_failed_do');
    }
    this.enabled = value;
  }
}

class StaticPatchDO {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

function createPageDO(): SettingsPrivacyPagePrivateDO {
  const page = createSettingsPrivacyPageForTest() as SettingsPrivacyPagePrivateDO;
  Reflect.set(page as Object, 'safeShowToast', (_message: string): void => {});
  return page;
}

function patchPreferenceDO(pref: PreferenceMockDO): StaticPatchDO {
  return new StaticPatchDO(PreferenceManager as Object, 'getInstance', (): PreferenceMockDO => pref);
}

async function flushMicrotasksDO(): Promise<void> {
  for (let i = 0; i < 20; i += 1) {
    await Promise.resolve();
  }
}

export default function phase2BatchDOTest() {
  describe('phase2BatchDOTest', () => {
    it('normal: settings_privacy_reload_should_read_route_api_flag_from_preference', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDO();
      pref.enabled = true;
      const patch = patchPreferenceDO(pref);
      const page = createPageDO();

      // Act
      await page.reload();
      patch.restore();

      // Assert
      expect(page.enableAmapRouteApi).assertTrue();
      expect(page.loading).assertFalse();
    });

    it('boundary: settings_privacy_about_to_appear_should_trigger_reload_async', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDO();
      pref.enabled = false;
      const patch = patchPreferenceDO(pref);
      const page = createPageDO();
      page.enableAmapRouteApi = true;

      // Act
      page.aboutToAppear();
      await flushMicrotasksDO();
      patch.restore();

      // Assert
      expect(page.enableAmapRouteApi).assertFalse();
      expect(page.loading).assertFalse();
    });

    it('invalid: settings_privacy_reload_should_clear_loading_even_when_preference_read_fails', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDO();
      pref.failRead = true;
      const patch = patchPreferenceDO(pref);
      const page = createPageDO();
      let message = '';

      // Act
      try {
        await page.reload();
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      patch.restore();

      // Assert
      expect(message).assertEqual('read_failed_do');
      expect(page.loading).assertFalse();
    });

    it('conflict: settings_privacy_toggle_should_restore_old_value_when_save_fails', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDO();
      pref.failSet = true;
      const patch = patchPreferenceDO(pref);
      const page = createPageDO();
      page.enableAmapRouteApi = false;

      // Act
      await page.onAmapRouteApiChanged(true);
      patch.restore();

      // Assert
      expect(page.enableAmapRouteApi).assertFalse();
      expect(pref.setCalls.length).assertEqual(1);
      expect(pref.setCalls[0]).assertTrue();
    });

    it('regression: settings_privacy_toggle_success_should_confirm_saved_preference_value', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDO();
      const patch = patchPreferenceDO(pref);
      const page = createPageDO();

      // Act
      await page.onAmapRouteApiChanged(true);
      await page.onAmapRouteApiChanged(false);
      patch.restore();

      // Assert
      expect(pref.setCalls.length).assertEqual(2);
      expect(page.enableAmapRouteApi).assertFalse();
      expect(resolveAmapRouteApiToggleToast(page.enableAmapRouteApi).indexOf('API') >= 0).assertTrue();
    });

    it('combined: settings_privacy_toggle_handler_should_delegate_to_change_logic', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDO();
      const patch = patchPreferenceDO(pref);
      const page = createPageDO();

      // Act
      await page.handleAmapRouteApiToggle(true);
      patch.restore();

      // Assert
      expect(pref.setCalls.length).assertEqual(1);
      expect(pref.setCalls[0]).assertTrue();
      expect(page.enableAmapRouteApi).assertTrue();
    });

    it('combined: settings_privacy_render_and_palette_should_handle_loading_and_enabled_states', 0, () => {
      // Arrange
      const page = createPageDO();
      page.effectiveTheme = 'dark';
      page.loading = false;
      page.enableAmapRouteApi = true;
      let threw = false;

      // Act
      const palette = page.getThemePalette();
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(palette.pageBg !== undefined).assertTrue();
      expect(threw).assertFalse();
    });
  });
}
