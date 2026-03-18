import { ComposableStrategy, DensityLevel, PaceLevel, EnergyLevel } from './TravelStrategyDimensions';
import { TravelStrategyProfile } from './TravelStrategyProfile';

export class StrategyBuilder {
  static buildProfile(strategy: ComposableStrategy): TravelStrategyProfile {
    return {
      dailyPoiTarget: this.mapDensityToTarget(strategy.density),
      moveTolerance: this.mapEnergyToTolerance(strategy.energy),
      slackRatio: this.mapPaceToSlack(strategy.pace),
      preferCompactSchedule: strategy.pace === PaceLevel.COMPACT,
      avoidBacktracking: strategy.energy === EnergyLevel.LOW,
      preferenceType: strategy.preference,
      energyLevel: strategy.energy
    };
  }

  private static mapDensityToTarget(density: DensityLevel): { min: number; max: number } {
    const map: Record<number, { min: number; max: number }> = {
      0: { min: 2, max: 4 },
      1: { min: 3, max: 5 },
      2: { min: 6, max: 8 }
    };
    return map[density];
  }

  private static mapPaceToSlack(pace: PaceLevel): number {
    const map: Record<number, number> = { 0: 0.4, 1: 0.25, 2: 0.1 };
    return map[pace];
  }

  private static mapEnergyToTolerance(energy: EnergyLevel): number {
    const map: Record<number, number> = { 0: 30, 1: 35, 2: 45 };
    return map[energy];
  }
}
