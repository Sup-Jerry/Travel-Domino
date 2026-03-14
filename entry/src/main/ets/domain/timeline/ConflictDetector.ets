// path: domain/timeline/ConflictDetector.ets
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

export interface ConflictCheckResult {
  hasConflict: boolean;
  conflictItemId: number;
  conflictItemName: string;
  gapMinutes: number;
  conflictMsg: string;
}

export class ConflictDetector {
  public static checkConflicts(
    events: EventEntity[],
    calculatedResults: TravelPlanItem[]
  ): ConflictCheckResult {
    for (let i = 0; i < events.length; i++) {
      const event = events[i];
      const result = calculatedResults[i];

      if (!event || !result) continue;
      if (event.status !== 1 || event.lock_status !== 1) continue;
      if (!result.isConflict) continue;

      const gapMinutes = result.gapMinutes && result.gapMinutes > 0
        ? result.gapMinutes
        : ConflictDetector.parseConflictMinutes(result.conflictMsg || '');

      return {
        hasConflict: true,
        conflictItemId: event.id,
        conflictItemName: event.name,
        gapMinutes,
        conflictMsg: result.conflictMsg || ''
      };
    }

    return {
      hasConflict: false,
      conflictItemId: -1,
      conflictItemName: '',
      gapMinutes: 0,
      conflictMsg: ''
    };
  }

  private static parseConflictMinutes(conflictMsg: string): number {
    const match = conflictMsg ? conflictMsg.match(/(\d+)/) : null;
    if (!match || match.length < 2) return 0;

    const parsed = Number.parseInt(match[1], 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }
}
