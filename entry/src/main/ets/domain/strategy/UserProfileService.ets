import { PreferenceManager } from '../../common/utils/PreferenceManager';
import { ComposableStrategy, DensityLevel, PaceLevel, PreferenceType, EnergyLevel } from './TravelStrategyDimensions';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from './UserStrategyProfile';

interface ModeFrequencyMap {
  modeCustom: number;
  modeDefault: number;
  modeSoldier: number;
  modeLeisure: number;
}

const EWMA_ALPHA = 0.3;
const RECOMMEND_SAMPLE_THRESHOLD = 3;

export class UserProfileService {
  static async recordStrategyUsage(mode: number, custom?: ComposableStrategy): Promise<void> {
    const profile = await UserProfileService.loadProfile();
    const frequency = UserProfileService.parseModeFrequency(profile.modeFrequency);
    UserProfileService.increaseModeFrequency(frequency, mode);

    let nextAvgDensity = profile.avgDensity;
    let nextAvgPace = profile.avgPace;
    let nextAvgPreference = profile.avgPreference;
    let nextAvgEnergy = profile.avgEnergy;

    if (mode === 1) {
      nextAvgDensity = UserProfileService.ewma(profile.avgDensity, 2);
      nextAvgPace = UserProfileService.ewma(profile.avgPace, 2);
      nextAvgEnergy = UserProfileService.ewma(profile.avgEnergy, 2);
    } else if (mode === 2) {
      nextAvgDensity = UserProfileService.ewma(profile.avgDensity, 0);
      nextAvgPace = UserProfileService.ewma(profile.avgPace, 0);
      nextAvgEnergy = UserProfileService.ewma(profile.avgEnergy, 0);
    } else if (mode === -1 && custom) {
      nextAvgDensity = UserProfileService.ewma(profile.avgDensity, custom.density);
      nextAvgPace = UserProfileService.ewma(profile.avgPace, custom.pace);
      nextAvgPreference = UserProfileService.ewma(profile.avgPreference, custom.preference);
      nextAvgEnergy = UserProfileService.ewma(profile.avgEnergy, custom.energy);
    }

    const nextProfile: UserStrategyProfile = {
      avgDensity: nextAvgDensity,
      avgPace: nextAvgPace,
      avgPreference: nextAvgPreference,
      avgEnergy: nextAvgEnergy,
      modeFrequency: UserProfileService.stringifyModeFrequency(frequency),
      sampleCount: profile.sampleCount + 1,
      updatedAt: Date.now()
    };
    await UserProfileService.saveProfile(nextProfile);
  }

  static async getRecommendedStrategy(): Promise<ComposableStrategy | null> {
    const profile = await UserProfileService.loadProfile();
    if (profile.sampleCount < RECOMMEND_SAMPLE_THRESHOLD) {
      return null;
    }

    const density = UserProfileService.clampInt(Math.round(profile.avgDensity), 0, 2) as DensityLevel;
    const pace = UserProfileService.clampInt(Math.round(profile.avgPace), 0, 2) as PaceLevel;
    const preference = UserProfileService.clampInt(Math.round(profile.avgPreference), 0, 4) as PreferenceType;
    const energy = UserProfileService.clampInt(Math.round(profile.avgEnergy), 0, 2) as EnergyLevel;
    return {
      density: density,
      pace: pace,
      preference: preference,
      energy: energy
    };
  }

  static async getRecommendationHint(): Promise<string> {
    const profile = await UserProfileService.loadProfile();
    if (profile.sampleCount < RECOMMEND_SAMPLE_THRESHOLD) {
      return '';
    }

    const density = UserProfileService.getDensityText(profile.avgDensity);
    const style = UserProfileService.getStyleText(UserProfileService.parseModeFrequency(profile.modeFrequency), profile.avgPace);
    return `根据你的${profile.sampleCount}次记录，偏好${density}密度·${style}风格`;
  }

  static async loadProfile(): Promise<UserStrategyProfile> {
    const manager = PreferenceManager.getInstance();
    return await manager.getUserStrategyProfile();
  }

  static async saveProfile(profile: UserStrategyProfile): Promise<void> {
    const manager = PreferenceManager.getInstance();
    await manager.setUserStrategyProfile(profile);
  }

  private static ewma(previous: number, current: number): number {
    return previous * (1 - EWMA_ALPHA) + current * EWMA_ALPHA;
  }

  private static parseModeFrequency(raw: string): ModeFrequencyMap {
    const safeRaw = raw || '';
    return {
      modeCustom: UserProfileService.parseModeCount(safeRaw, '-1'),
      modeDefault: UserProfileService.parseModeCount(safeRaw, '0'),
      modeSoldier: UserProfileService.parseModeCount(safeRaw, '1'),
      modeLeisure: UserProfileService.parseModeCount(safeRaw, '2')
    };
  }

  private static getStyleText(frequency: ModeFrequencyMap, avgPace: number): string {
    let maxMode = 0;
    let maxCount = frequency.modeDefault;
    if (frequency.modeSoldier > maxCount) {
      maxMode = 1;
      maxCount = frequency.modeSoldier;
    }
    if (frequency.modeLeisure > maxCount) {
      maxMode = 2;
      maxCount = frequency.modeLeisure;
    }
    if (frequency.modeCustom > maxCount) {
      maxMode = -1;
    }

    if (maxMode === 1) {
      return '特种兵';
    }
    if (maxMode === 2) {
      return '休闲';
    }
    if (maxMode === -1) {
      return '自定义';
    }
    if (avgPace >= 1.5) {
      return '特种兵';
    }
    if (avgPace <= 0.5) {
      return '休闲';
    }
    return '平衡';
  }

  private static getDensityText(avgDensity: number): string {
    if (avgDensity >= 1.5) {
      return '高';
    }
    if (avgDensity <= 0.5) {
      return '低';
    }
    return '中';
  }

  private static clampInt(value: number, min: number, max: number): number {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  private static parseModeCount(raw: string, key: string): number {
    const pattern = new RegExp(`"${key}"\\s*:\\s*(\\d+)`);
    const match = raw.match(pattern);
    if (!match || match.length < 2) {
      return 0;
    }
    const value = Number(match[1]);
    if (!Number.isFinite(value) || value <= 0) {
      return 0;
    }
    return Math.floor(value);
  }

  private static stringifyModeFrequency(frequency: ModeFrequencyMap): string {
    const custom = Math.max(0, Math.floor(frequency.modeCustom));
    const modeDefault = Math.max(0, Math.floor(frequency.modeDefault));
    const soldier = Math.max(0, Math.floor(frequency.modeSoldier));
    const leisure = Math.max(0, Math.floor(frequency.modeLeisure));
    return `{"-1":${custom},"0":${modeDefault},"1":${soldier},"2":${leisure}}`;
  }

  private static increaseModeFrequency(frequency: ModeFrequencyMap, mode: number): void {
    if (mode === -1) {
      frequency.modeCustom += 1;
      return;
    }
    if (mode === 1) {
      frequency.modeSoldier += 1;
      return;
    }
    if (mode === 2) {
      frequency.modeLeisure += 1;
      return;
    }
    frequency.modeDefault += 1;
  }
}
