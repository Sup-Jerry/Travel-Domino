export interface UserStrategyProfile {
  avgDensity: number;
  avgPace: number;
  avgPreference: number;
  avgEnergy: number;
  modeFrequency: string;
  sampleCount: number;
  updatedAt: number;
}

export const DEFAULT_USER_PROFILE: UserStrategyProfile = {
  avgDensity: 1,
  avgPace: 1,
  avgPreference: 0,
  avgEnergy: 1,
  modeFrequency: '{}',
  sampleCount: 0,
  updatedAt: 0
};
