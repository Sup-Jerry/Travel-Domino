import { ComposableStrategy, DensityLevel, PaceLevel, EnergyLevel } from './TravelStrategyDimensions';
import { TravelStrategyProfile, DailyPoiTarget } from './TravelStrategyProfile';

export class StrategyBuilder {
  static buildProfile(strategy: ComposableStrategy): TravelStrategyProfile {
    return {
      dailyPoiTarget: StrategyBuilder.mapDensityToTarget(strategy.density),
      moveTolerance: StrategyBuilder.mapEnergyToTolerance(strategy.energy),
      slackRatio: StrategyBuilder.mapPaceToSlack(strategy.pace),
      preferCompactSchedule: strategy.pace === PaceLevel.COMPACT,
      avoidBacktracking: strategy.energy === EnergyLevel.LOW,
      preferenceType: strategy.preference,
      energyLevel: strategy.energy
    };
  }

  private static mapDensityToTarget(density: DensityLevel): DailyPoiTarget {
    if (density === DensityLevel.LOW) return { min: 2, max: 4 };
    if (density === DensityLevel.HIGH) return { min: 6, max: 8 };
    return { min: 3, max: 5 };
  }

  private static mapPaceToSlack(pace: PaceLevel): number {
    if (pace === PaceLevel.RELAXED) return 0.4;
    if (pace === PaceLevel.COMPACT) return 0.1;
    return 0.25;
  }

  private static mapEnergyToTolerance(energy: EnergyLevel): number {
    if (energy === EnergyLevel.LOW) return 30;
    if (energy === EnergyLevel.HIGH) return 45;
    return 35;
  }
}
