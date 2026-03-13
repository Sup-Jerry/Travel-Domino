import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export type ThemeMode = 'light' | 'dark' | 'system';
export type EffectiveTheme = 'light' | 'dark';

interface ThemeContextConfig {
  colorMode: number;
}

interface ThemeContextLike {
  config?: ThemeContextConfig;
}

export interface ThemePalette {
  pageBg: string;
  cardBg: string;
  cardBgSoft: string;
  companionBg: string;
  companionCardBg: string;
  immersiveBg: string;
  statusPending: string;
  statusSkipped: string;
  statusCompleted: string;
  textPrimary: string;
  textSecondary: string;
  textTertiary: string;
  primary: string;
  border: string;
  divider: string;
  success: string;
  warning: string;
  danger: string;
  toolboxBall: string;
  toolboxBallDisabled: string;
}

const LIGHT_THEME: ThemePalette = {
  pageBg: '#F6F8FC',
  cardBg: '#FFFFFF',
  cardBgSoft: '#F5F7FA',
  companionBg: '#EEF3FA',
  companionCardBg: '#FFFFFF',
  immersiveBg: '#EAF0FA',
  statusPending: '#6F97D8',
  statusSkipped: '#C79A53',
  statusCompleted: '#68A57B',
  textPrimary: '#1F2937',
  textSecondary: '#5B6B82',
  textTertiary: '#8FA1B8',
  primary: '#2F7DFF',
  border: '#DCE5F2',
  divider: '#E7EDF5',
  success: '#2D7C5C',
  warning: '#C58A2A',
  danger: '#B95B72',
  toolboxBall: '#2C5E9C',
  toolboxBallDisabled: '#7A8A9E'
};

const DARK_THEME: ThemePalette = {
  pageBg: '#0F1621',
  cardBg: '#192435',
  cardBgSoft: '#152032',
  companionBg: '#121D2D',
  companionCardBg: '#1A2A42',
  immersiveBg: '#2A2442',
  statusPending: '#7DA8EC',
  statusSkipped: '#D4AD72',
  statusCompleted: '#7BC497',
  textPrimary: '#EAF1FB',
  textSecondary: '#C0CEE1',
  textTertiary: '#8DA0BA',
  primary: '#66A3FF',
  border: '#2A3B56',
  divider: '#26364E',
  success: '#3BA47A',
  warning: '#D8A64D',
  danger: '#D08AA4',
  toolboxBall: '#355F9A',
  toolboxBallDisabled: '#50627B'
};

export class ThemeCenter {
  private static readonly LOG_DOMAIN = 0x0000;
  private static readonly LOG_TAG = 'ThemeCenter';
  static readonly STORAGE_THEME_MODE = 'ThemeMode';
  static readonly STORAGE_EFFECTIVE_THEME = 'EffectiveTheme';

  static normalizeThemeMode(value: string): ThemeMode {
    if (value === 'light' || value === 'dark' || value === 'system') {
      return value;
    }
    return 'system';
  }

  static normalizeEffectiveTheme(value: string): EffectiveTheme {
    return value === 'dark' ? 'dark' : 'light';
  }

  static getPalette(effectiveTheme: string): ThemePalette {
    return ThemeCenter.normalizeEffectiveTheme(effectiveTheme) === 'dark' ? DARK_THEME : LIGHT_THEME;
  }

  static resolveEffectiveTheme(themeMode: ThemeMode, colorMode: number): EffectiveTheme {
    if (themeMode === 'dark') {
      return 'dark';
    }
    if (themeMode === 'light') {
      return 'light';
    }
    return colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? 'dark' : 'light';
  }

  static readColorModeFromContext(context: common.Context): number {
    const contextWithConfig = context as ThemeContextLike;
    const colorMode = contextWithConfig.config?.colorMode;
    if (typeof colorMode === 'number') {
      return colorMode;
    }
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
  }

  static applyThemeMode(context: common.Context, mode: ThemeMode): EffectiveTheme {
    const appContext = context.getApplicationContext();
    try {
      if (mode === 'dark') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === 'light') {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      hilog.error(
        ThemeCenter.LOG_DOMAIN,
        ThemeCenter.LOG_TAG,
        `setColorMode failed, fallback to system. error=${JSON.stringify(error)}`
      );
      try {
        appContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      } catch (fallbackError) {
        hilog.error(
          ThemeCenter.LOG_DOMAIN,
          ThemeCenter.LOG_TAG,
          `setColorMode fallback failed: ${JSON.stringify(fallbackError)}`
        );
      }
    }

    const colorMode = ThemeCenter.readColorModeFromContext(context);
    const effectiveTheme = ThemeCenter.resolveEffectiveTheme(mode, colorMode);
    ThemeCenter.syncThemeToStorage(mode, effectiveTheme);
    return effectiveTheme;
  }

  static syncThemeToStorage(mode: ThemeMode, effectiveTheme: EffectiveTheme): void {
    AppStorage.setOrCreate(ThemeCenter.STORAGE_THEME_MODE, mode);
    AppStorage.setOrCreate(ThemeCenter.STORAGE_EFFECTIVE_THEME, effectiveTheme);
  }
}
