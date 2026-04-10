export interface UserStrategyProfile {
  avgDensity: number;
  avgPace: number;
  avgPreference: number;
  avgEnergy: number;
  modeFrequency: string;
  sampleCount: number;
  updatedAt: number;
  manualOverrideEnabled?: boolean;
  consistencyMatchCount?: number;
  consistencyMismatchCount?: number;
  lastConsistencyCheckAt?: number;
}

export const DEFAULT_USER_PROFILE: UserStrategyProfile = {
  avgDensity: 1,
  avgPace: 1,
  avgPreference: 0,
  avgEnergy: 1,
  modeFrequency: '{}',
  sampleCount: 0,
  updatedAt: 0,
  manualOverrideEnabled: false,
  consistencyMatchCount: 0,
  consistencyMismatchCount: 0,
  lastConsistencyCheckAt: 0
};
