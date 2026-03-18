export enum TravelStrategyMode {
  DEFAULT = 0,
  SOLDIER = 1,
  LEISURE = 2
}

export class TravelStrategyModeHelper {
  static getDisplayName(mode: TravelStrategyMode): string {
    switch (mode) {
      case TravelStrategyMode.SOLDIER: return '特种兵';
      case TravelStrategyMode.LEISURE: return '休闲';
      default: return '默认';
    }
  }

  static getIcon(mode: TravelStrategyMode): string {
    switch (mode) {
      case TravelStrategyMode.SOLDIER: return '⚡';
      case TravelStrategyMode.LEISURE: return '☕';
      default: return '✨';
    }
  }
}
