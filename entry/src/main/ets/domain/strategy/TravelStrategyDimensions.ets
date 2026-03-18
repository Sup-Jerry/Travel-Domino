export enum DensityLevel {
  LOW = 0,
  MEDIUM = 1,
  HIGH = 2
}

export enum PaceLevel {
  RELAXED = 0,
  BALANCED = 1,
  COMPACT = 2
}

export enum PreferenceType {
  BALANCED = 0,
  SCENIC = 1,
  FOOD = 2,
  CULTURE = 3,
  NIGHT = 4
}

export enum EnergyLevel {
  LOW = 0,
  MEDIUM = 1,
  HIGH = 2
}

export interface ComposableStrategy {
  density: DensityLevel;
  pace: PaceLevel;
  preference: PreferenceType;
  energy: EnergyLevel;
}
