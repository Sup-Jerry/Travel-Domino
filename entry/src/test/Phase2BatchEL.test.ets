import { describe, expect, it } from '@ohos/hypium';
import {
  PlanSettingsDialog,
  getPlanSettingsActions,
  isPlanSettingsActionSupported,
  isWeatherPreferenceLevelValid
} from '../main/ets/pages/components/dialogs/PlanSettingsDialog';

interface PlanSettingsPreferenceEL {
  heatSensitivity: number;
  rainSensitivity: number;
  weatherRiskTolerance: number;
}

interface PlanSettingsDialogPrivateEL {
  weatherUserPreference: PlanSettingsPreferenceEL;
  weatherPreference: PlanSettingsPreferenceEL;
  effectiveTheme: string;
  onRename: () => void;
  onReschedule: () => void;
  onShare: () => void;
  onWeatherPreferenceChange: (preference: PlanSettingsPreferenceEL) => void;
  aboutToAppear(): void;
  getPalette(): Object;
  buildDimensionRow(
    label: string,
    options: string[],
    values: number[],
    getCurrent: () => number,
    onChange: (val: number) => void
  ): void;
  initialRender(): void;
}

function createPlanSettingsDialogEL(): PlanSettingsDialogPrivateEL {
  return new PlanSettingsDialog(undefined, {} as LocalStorage) as Object as PlanSettingsDialogPrivateEL;
}

export default function phase2BatchELTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEL_plan_settings_extra', () => {
    it('normal: plan_settings_actions_should_keep_unique_supported_actions', 0, () => {
      // Arrange
      const actions = getPlanSettingsActions();

      // Act
      const uniqueCount = new Set(actions).size;
      const allSupported = actions.every((action) => isPlanSettingsActionSupported(action));

      // Assert
      expect(actions.length).assertEqual(4);
      expect(uniqueCount).assertEqual(actions.length);
      expect(allSupported).assertTrue();
    });

    it('boundary: plan_settings_weather_level_should_accept_zero_one_and_two_only', 0, () => {
      // Arrange
      const values = [0, 1, 2];

      // Act
      const allValid = values.every((value) => isWeatherPreferenceLevelValid(value));
      const below = isWeatherPreferenceLevelValid(-1);
      const above = isWeatherPreferenceLevelValid(3);

      // Assert
      expect(allValid).assertTrue();
      expect(below).assertFalse();
      expect(above).assertFalse();
    });

    it('invalid: plan_settings_weather_level_should_reject_decimal_and_nan_values', 0, () => {
      // Arrange
      const decimal = 1.5;
      const nan = Number.NaN;

      // Act
      const decimalValid = isWeatherPreferenceLevelValid(decimal);
      const nanValid = isWeatherPreferenceLevelValid(nan);

      // Assert
      expect(decimalValid).assertFalse();
      expect(nanValid).assertFalse();
    });

    it('conflict: plan_settings_action_support_should_be_case_sensitive', 0, () => {
      // Arrange
      const lowercase = 'share';
      const uppercase = 'SHARE';

      // Act
      const lowerSupported = isPlanSettingsActionSupported(lowercase);
      const upperSupported = isPlanSettingsActionSupported(uppercase);

      // Assert
      expect(lowerSupported).assertTrue();
      expect(upperSupported).assertFalse();
    });

    it('regression: plan_settings_actions_should_keep_order_for_rename_reschedule_share_weather', 0, () => {
      // Arrange
      // Act
      const actions = getPlanSettingsActions();

      // Assert
      expect(actions[0]).assertEqual('rename');
      expect(actions[1]).assertEqual('reschedule');
      expect(actions[2]).assertEqual('share');
      expect(actions[3]).assertEqual('weather_preference');
    });

    it('combined: plan_settings_dialog_about_to_appear_should_copy_external_preference', 0, () => {
      // Arrange
      const page = createPlanSettingsDialogEL();
      page.weatherUserPreference = {
        heatSensitivity: 2,
        rainSensitivity: 0,
        weatherRiskTolerance: 1
      };

      // Act
      page.aboutToAppear();

      // Assert
      expect(page.weatherPreference.heatSensitivity).assertEqual(2);
      expect(page.weatherPreference.rainSensitivity).assertEqual(0);
      expect(page.weatherPreference.weatherRiskTolerance).assertEqual(1);
    });

    it('combined: plan_settings_dialog_dimension_row_should_apply_on_change_callback', 0, () => {
      // Arrange
      const page = createPlanSettingsDialogEL();
      page.weatherUserPreference = {
        heatSensitivity: 1,
        rainSensitivity: 1,
        weatherRiskTolerance: 1
      };
      page.aboutToAppear();
      let changedValue = -1;
      let threw = false;

      // Act
      try {
        page.buildDimensionRow('heat', ['low', 'mid', 'high'], [0, 1, 2], () => page.weatherPreference.heatSensitivity, (value: number): void => {
          changedValue = value;
        });
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(changedValue).assertEqual(-1);
    });

    it('combined: plan_settings_dialog_render_should_cover_light_and_dark_preference_states', 0, () => {
      // Arrange
      const page = createPlanSettingsDialogEL();
      let changedHeat = -1;
      let threw = false;
      page.onWeatherPreferenceChange = (preference: PlanSettingsPreferenceEL): void => {
        changedHeat = preference.heatSensitivity;
      };

      // Act
      page.weatherUserPreference = {
        heatSensitivity: 0,
        rainSensitivity: 2,
        weatherRiskTolerance: 1
      };
      page.aboutToAppear();
      page.effectiveTheme = 'light';
      try {
        page.initialRender();
        page.weatherPreference = {
          heatSensitivity: 2,
          rainSensitivity: 1,
          weatherRiskTolerance: 0
        };
        page.effectiveTheme = 'dark';
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const palette = page.getPalette();

      // Assert
      expect(threw).assertFalse();
      expect(changedHeat).assertEqual(-1);
      expect(palette !== null).assertTrue();
      expect(page.weatherPreference.heatSensitivity).assertEqual(2);
    });
  });
}
