import { describe, it, expect } from '@ohos/hypium';
import { createSettingsGeneralPageForTest } from '../main/ets/pages/SettingsGeneralPage';
import {
  AiDailyPoiRangeConfig,
  PreferenceManager
} from '../main/ets/common/utils/PreferenceManager';
import { ThemeMode } from '../main/ets/common/utils/ThemeCenter';

interface SettingsGeneralPagePrivateDH {
  weatherFeatureEnabled: boolean;
  enableIdleGapDetection: boolean;
  idleGapTriggerMinutes: number;
  idleGapTriggerInput: string;
  minEventDuration: number;
  minEventDurationInput: string;
  aiDefaultMinInput: string;
  aiDefaultMaxInput: string;
  aiSoldierMinInput: string;
  aiSoldierMaxInput: string;
  aiLeisureMinInput: string;
  aiLeisureMaxInput: string;
  loading: boolean;
  themeMode: ThemeMode;
  effectiveTheme: string;
  aboutToAppear(): void;
  safeShowToast(message: string): void;
  showThemeModeDialog(): void;
  applyThemeMode(mode: ThemeMode): Promise<void>;
  reload(): Promise<void>;
  onWeatherFeatureChanged(value: boolean): Promise<void>;
  onIdleGapDetectionChanged(value: boolean): Promise<void>;
  saveIdleGapTriggerMinutes(): Promise<void>;
  saveMinEventDuration(): Promise<void>;
  saveAiDailyPoiRanges(): Promise<void>;
}

interface AlertButtonDH {
  value: string;
  action: () => void;
}

interface AlertOptionsDH {
  title: string;
  message: string;
  buttons: AlertButtonDH[];
}

interface GeneralUiContextDH {
  showAlertDialog(options: AlertOptionsDH): void;
  getHostContext(): Object;
}

interface GeneralConfigDH {
  colorMode?: number;
}

class GeneralAppContextDH {
  public modes: number[] = [];

  setColorMode(mode: number): void {
    this.modes.push(mode);
  }
}

class GeneralHostContextDH {
  public config: GeneralConfigDH = {};
  private readonly appContext: GeneralAppContextDH;

  constructor(appContext: GeneralAppContextDH) {
    this.appContext = appContext;
  }

  getApplicationContext(): GeneralAppContextDH {
    return this.appContext;
  }
}

class GeneralUiContextMockDH implements GeneralUiContextDH {
  public alertOptions: AlertOptionsDH | null = null;
  public readonly appContext: GeneralAppContextDH = new GeneralAppContextDH();
  private readonly hostContext: GeneralHostContextDH = new GeneralHostContextDH(this.appContext);

  showAlertDialog(options: AlertOptionsDH): void {
    this.alertOptions = options;
  }

  getHostContext(): Object {
    return this.hostContext;
  }
}

class PreferenceMockDH {
  public themeMode: string = 'system';
  public weatherEnabled: boolean = true;
  public idleEnabled: boolean = true;
  public idleMinutes: number = 45;
  public minDuration: number = 30;
  public aiRange: AiDailyPoiRangeConfig = {
    defaultMin: 4,
    defaultMax: 6,
    soldierMin: 5,
    soldierMax: 8,
    leisureMin: 3,
    leisureMax: 5
  };
  public failMethod: string = '';
  public setCalls: string[] = [];

  async getThemeMode(): Promise<string> {
    return this.themeMode;
  }

  async setThemeMode(mode: string): Promise<void> {
    this.setCalls.push(`setThemeMode:${mode}`);
    this.throwIfNeeded('setThemeMode');
    this.themeMode = mode;
  }

  async isWeatherFeatureEnabled(): Promise<boolean> {
    return this.weatherEnabled;
  }

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.setCalls.push(`setWeatherFeatureEnabled:${enabled}`);
    this.throwIfNeeded('setWeatherFeatureEnabled');
    this.weatherEnabled = enabled;
  }

  async getIdleGapDetectionEnabled(): Promise<boolean> {
    return this.idleEnabled;
  }

  async setIdleGapDetectionEnabled(enabled: boolean): Promise<void> {
    this.setCalls.push(`setIdleGapDetectionEnabled:${enabled}`);
    this.throwIfNeeded('setIdleGapDetectionEnabled');
    this.idleEnabled = enabled;
  }

  async getIdleGapTriggerMinutes(): Promise<number> {
    return this.idleMinutes;
  }

  async setIdleGapTriggerMinutes(value: number): Promise<void> {
    this.setCalls.push(`setIdleGapTriggerMinutes:${value}`);
    this.throwIfNeeded('setIdleGapTriggerMinutes');
    this.idleMinutes = value;
  }

  async getMinEventDuration(): Promise<number> {
    return this.minDuration;
  }

  async setMinEventDuration(value: number): Promise<void> {
    this.setCalls.push(`setMinEventDuration:${value}`);
    this.throwIfNeeded('setMinEventDuration');
    this.minDuration = value;
  }

  async getAiDailyPoiRangeConfig(): Promise<AiDailyPoiRangeConfig> {
    return this.aiRange;
  }

  async setAiDailyPoiRangeConfig(value: AiDailyPoiRangeConfig): Promise<void> {
    this.setCalls.push(`setAiDailyPoiRangeConfig:${value.defaultMin}-${value.defaultMax}`);
    this.throwIfNeeded('setAiDailyPoiRangeConfig');
    this.aiRange = value;
  }

  private throwIfNeeded(method: string): void {
    if (this.failMethod === method) {
      throw new Error(`${method}_failed_dh`);
    }
  }
}

class StaticPatchDH {
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

function createPageDH(uiContext?: GeneralUiContextDH): SettingsGeneralPagePrivateDH {
  const page = createSettingsGeneralPageForTest() as SettingsGeneralPagePrivateDH;
  if (uiContext) {
    Reflect.set(page as Object, 'getUIContext', (): GeneralUiContextDH => uiContext);
  }
  return page;
}

function patchPreferenceDH(pref: PreferenceMockDH): StaticPatchDH {
  return new StaticPatchDH(PreferenceManager as Object, 'getInstance', (): PreferenceMockDH => pref);
}

async function flushMicrotasksDH(): Promise<void> {
  for (let i = 0; i < 20; i += 1) {
    await Promise.resolve();
  }
}

export default function phase2BatchDHTest() {
  describe('phase2BatchDHTest', () => {
    it('normal: settings_general_reload_should_apply_persisted_preferences', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      pref.themeMode = 'dark';
      pref.weatherEnabled = false;
      pref.idleEnabled = false;
      pref.idleMinutes = 90;
      pref.minDuration = 20;
      pref.aiRange = {
        defaultMin: 2,
        defaultMax: 5,
        soldierMin: 6,
        soldierMax: 10,
        leisureMin: 1,
        leisureMax: 4
      };
      const patch = patchPreferenceDH(pref);
      const page = createPageDH(new GeneralUiContextMockDH());

      // Act
      await page.reload();
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.themeMode).assertEqual('dark');
      expect(page.weatherFeatureEnabled).assertFalse();
      expect(page.enableIdleGapDetection).assertFalse();
      expect(page.idleGapTriggerInput).assertEqual('90');
      expect(page.minEventDurationInput).assertEqual('20');
      expect(page.aiSoldierMaxInput).assertEqual('10');
    });

    it('boundary: settings_general_about_to_appear_should_start_reload_and_clear_loading', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      pref.themeMode = 'light';
      const patch = patchPreferenceDH(pref);
      const page = createPageDH(new GeneralUiContextMockDH());

      // Act
      page.aboutToAppear();
      await flushMicrotasksDH();
      patch.restore();

      // Assert
      expect(page.loading).assertFalse();
      expect(page.themeMode).assertEqual('light');
      expect(page.effectiveTheme).assertEqual('light');
    });

    it('normal: settings_general_theme_dialog_should_apply_selected_mode', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      const patch = patchPreferenceDH(pref);
      const uiContext = new GeneralUiContextMockDH();
      const page = createPageDH(uiContext);

      // Act
      page.showThemeModeDialog();
      const options = uiContext.alertOptions as AlertOptionsDH;
      options.buttons[2].action();
      await flushMicrotasksDH();
      patch.restore();

      // Assert
      expect(options.buttons.length).assertEqual(3);
      expect(page.themeMode).assertEqual('dark');
      expect(page.effectiveTheme).assertEqual('dark');
      expect(pref.setCalls.indexOf('setThemeMode:dark') >= 0).assertTrue();
    });

    it('invalid: settings_general_weather_toggle_should_rollback_when_save_fails', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      pref.failMethod = 'setWeatherFeatureEnabled';
      const patch = patchPreferenceDH(pref);
      const page = createPageDH();
      page.weatherFeatureEnabled = true;

      // Act
      await page.onWeatherFeatureChanged(false);
      patch.restore();

      // Assert
      expect(page.weatherFeatureEnabled).assertTrue();
      expect(pref.setCalls.length).assertEqual(1);
    });

    it('conflict: settings_general_idle_toggle_should_persist_and_reload_stored_value', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      const patch = patchPreferenceDH(pref);
      const page = createPageDH();
      page.enableIdleGapDetection = false;

      // Act
      await page.onIdleGapDetectionChanged(true);
      patch.restore();

      // Assert
      expect(page.enableIdleGapDetection).assertTrue();
      expect(pref.idleEnabled).assertTrue();
      expect(pref.setCalls.indexOf('setIdleGapDetectionEnabled:true') >= 0).assertTrue();
    });

    it('regression: settings_general_numeric_saves_should_normalize_persist_and_rollback_on_failure', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      const patch = patchPreferenceDH(pref);
      const page = createPageDH();
      page.idleGapTriggerMinutes = 45;
      page.idleGapTriggerInput = '999';
      page.minEventDuration = 30;
      page.minEventDurationInput = 'bad';

      // Act
      await page.saveIdleGapTriggerMinutes();
      pref.failMethod = 'setMinEventDuration';
      await page.saveMinEventDuration();
      patch.restore();

      // Assert
      expect(page.idleGapTriggerMinutes).assertEqual(720);
      expect(page.idleGapTriggerInput).assertEqual('720');
      expect(page.minEventDuration).assertEqual(30);
      expect(page.minEventDurationInput).assertEqual('30');
    });

    it('combined: settings_general_ai_range_save_should_swap_reversed_inputs_and_keep_stored_values', 0, async () => {
      // Arrange
      const pref = new PreferenceMockDH();
      const patch = patchPreferenceDH(pref);
      const page = createPageDH();
      page.aiDefaultMinInput = '9';
      page.aiDefaultMaxInput = '3';
      page.aiSoldierMinInput = 'bad';
      page.aiSoldierMaxInput = '12';
      page.aiLeisureMinInput = '2';
      page.aiLeisureMaxInput = '4';

      // Act
      await page.saveAiDailyPoiRanges();
      page.safeShowToast('dh_toast');
      patch.restore();

      // Assert
      expect(pref.aiRange.defaultMin).assertEqual(3);
      expect(pref.aiRange.defaultMax).assertEqual(9);
      expect(page.aiSoldierMinInput).assertEqual('5');
      expect(page.aiSoldierMaxInput).assertEqual('12');
      expect(page.aiLeisureMinInput).assertEqual('2');
      expect(page.aiLeisureMaxInput).assertEqual('4');
    });
  });
}
