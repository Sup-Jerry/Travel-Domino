import { describe, it, expect } from '@ohos/hypium';
import {
  createSettingsNotificationPageForTest,
  resolveArchiveTipToggleToast,
  resolveDeleteTipToggleToast
} from '../main/ets/pages/SettingsNotificationPage';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';

interface SettingsNotificationPagePrivateDG {
  showArchiveTip: boolean;
  showDeleteTip: boolean;
  loading: boolean;
  effectiveTheme: string;
  aboutToAppear(): void;
  getThemePalette(): Object;
  safeShowToast(message: string): void;
  reload(): Promise<void>;
  onShowArchiveTipChanged(value: boolean): Promise<void>;
  onShowDeleteTipChanged(value: boolean): Promise<void>;
  resetAllTips(): Promise<void>;
}

interface PreferenceLikeDG {
  getValue(key: string, defaultValue: Object): Promise<Object>;
  setValue(key: string, value: Object): Promise<void>;
}

class PreferenceMockDG implements PreferenceLikeDG {
  public values: Map<string, Object> = new Map<string, Object>();
  public setCalls: string[] = [];
  public failSetKey: string = '';

  async getValue(key: string, defaultValue: Object): Promise<Object> {
    return this.values.has(key) ? (this.values.get(key) as Object) : defaultValue;
  }

  async setValue(key: string, value: Object): Promise<void> {
    this.setCalls.push(`${key}:${value}`);
    if (key === this.failSetKey) {
      throw new Error('preference_set_fail_dg');
    }
    this.values.set(key, value);
  }
}

class StaticPatchDG {
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

function createPageDG(): SettingsNotificationPagePrivateDG {
  return createSettingsNotificationPageForTest() as SettingsNotificationPagePrivateDG;
}

function patchPreferenceDG(pref: PreferenceMockDG): StaticPatchDG {
  return new StaticPatchDG(PreferenceManager as Object, 'getInstance', (): PreferenceLikeDG => pref);
}

async function flushMicrotasksDG(): Promise<void> {
  await Promise.resolve();
  await Promise.resolve();
}

export default function phase2BatchDGTest() {
  describe('phase2BatchDGTest', () => {
    it('normal: settings_notification_reload_should_apply_persisted_visibility_flags', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDG();
      pref.values.set(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, true);
      pref.values.set(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, false);
      const patch = patchPreferenceDG(pref);
      const page = createPageDG();

      // Act
      await page.reload();
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.showArchiveTip).assertFalse();
      expect(page.showDeleteTip).assertTrue();
    });

    it('boundary: settings_notification_about_to_appear_should_start_reload_and_clear_loading', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDG();
      pref.values.set(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, false);
      pref.values.set(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, true);
      const patch = patchPreferenceDG(pref);
      const page = createPageDG();

      // Act
      page.aboutToAppear();
      await flushMicrotasksDG();
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.showArchiveTip).assertTrue();
      expect(page.showDeleteTip).assertFalse();
    });

    it('invalid: settings_notification_archive_toggle_should_rollback_when_preference_write_fails', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDG();
      pref.failSetKey = PreferenceManager.KEY_HIDE_ARCHIVE_TIP;
      const patch = patchPreferenceDG(pref);
      const page = createPageDG();
      page.showArchiveTip = true;

      // Act
      await page.onShowArchiveTipChanged(false);
      patch.restore();

      // Assert
      expect(page.showArchiveTip).assertTrue();
      expect(pref.setCalls.length).assertEqual(1);
    });

    it('regression: settings_notification_delete_toggle_should_persist_inverse_hide_flag_and_reload', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDG();
      const patch = patchPreferenceDG(pref);
      const page = createPageDG();
      page.showDeleteTip = true;

      // Act
      await page.onShowDeleteTipChanged(false);
      patch.restore();

      // Assert
      expect(pref.values.get(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP) as boolean).assertTrue();
      expect(page.showDeleteTip).assertFalse();
      expect(resolveDeleteTipToggleToast(page.showDeleteTip).trim().length > 0).assertTrue();
    });

    it('combined: settings_notification_reset_all_should_restore_both_tips_and_theme_palette', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDG();
      pref.values.set(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, true);
      pref.values.set(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, true);
      const patch = patchPreferenceDG(pref);
      const page = createPageDG();
      page.effectiveTheme = 'dark';
      page.showArchiveTip = false;
      page.showDeleteTip = false;

      // Act
      await page.resetAllTips();
      const palette = page.getThemePalette();
      page.safeShowToast('dg_toast');
      patch.restore();

      // Assert
      expect(page.showArchiveTip).assertTrue();
      expect(page.showDeleteTip).assertTrue();
      expect(pref.values.get(PreferenceManager.KEY_HIDE_ARCHIVE_TIP) as boolean).assertFalse();
      expect(pref.values.get(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP) as boolean).assertFalse();
      expect(palette !== null).assertTrue();
      expect(resolveArchiveTipToggleToast(page.showArchiveTip).trim().length > 0).assertTrue();
    });
  });
}