// path: domain/timeline/CompressionEngine.ets
import { EventEntity } from '../../model/entity/EventEntity';
import { DateUtil } from '../../common/utils/DateUtil';

export type CompressionMode = 'EQUAL' | 'RATIO';

export interface CompressionCandidate {
  index: number;
  id: number;
  name: string;
  oldVal: number;
  minAllowed: number;
  maxReducible: number;
  selectable: boolean;
  disabledReason: string;
}

export interface CompressionContext {
  neededGapMinutes: number;
  candidates: CompressionCandidate[];
}

export class CompressionEngine {
  public static buildContext(
    events: EventEntity[],
    targetIndex: number,
    targetTime: string,
    chainStartIndex: number,
    minKeepDuration: number,
    naturalArrivalMinutes: number,
    targetDayOffset: number
  ): CompressionContext | null {
    if (targetIndex <= 0 || !events[targetIndex]) return null;
    if (!DateUtil.isValidTimeString(targetTime)) return null;

    const targetMinutes = DateUtil.timeToMinutes(targetTime);
    const neededGapMinutes = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);

    const candidates: CompressionCandidate[] = [];
    for (let i = 0; i < targetIndex; i++) {
      const item = events[i];
      if (item.status !== 1) continue;

      const minAllowed = Math.min(item.duration, minKeepDuration);
      const maxReducible = Math.max(0, item.duration - minAllowed);
      const isRigid = item.lock_status === 1;
      const withinActiveChain = i >= chainStartIndex;
      let selectable = !isRigid && withinActiveChain && maxReducible > 0;
      let disabledReason = '';

      if (isRigid) {
        disabledReason = '刚性地点不可压缩';
      } else if (!withinActiveChain) {
        disabledReason = '受前序刚性锚点阻断';
      } else if (maxReducible <= 0) {
        disabledReason = `已达到最短停留 ${minKeepDuration} 分钟`;
      }

      candidates.push({
        index: i,
        id: item.id,
        name: item.name,
        oldVal: item.duration,
        minAllowed,
        maxReducible,
        selectable,
        disabledReason
      });
    }

    return { neededGapMinutes, candidates };
  }
}
