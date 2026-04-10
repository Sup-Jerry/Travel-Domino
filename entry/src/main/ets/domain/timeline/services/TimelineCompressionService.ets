import { hilog } from '@kit.PerformanceAnalysisKit';
import { DateUtil } from '../../../common/utils/DateUtil';
import { EventEntity } from '../../../model/entity/EventEntity';
import { TravelPlanItem } from '../../../model/interface/IStandardEvent';
import { EventRepositoryImpl } from '../../../infrastructure/persistence/EventRepositoryImpl';
import { TimelineConflictResolver } from './TimelineConflictResolver';

const TAG = 'TimelineViewModel';

export type CompressionMode = 'EQUAL' | 'RATIO';

export interface CompressionAffectedItem {
  index: number;
  name: string;
  oldVal: number;
  newVal: number;
}

export interface CompressionPlan {
  status: 'NO_ACTION' | 'COMPRESS_CONFIRM' | 'OVERLOAD' | 'FAIL_TOO_SHORT';
  msg: string;
  affectedItems: CompressionAffectedItem[];
  suggestedTime?: string;
  remainingGapMinutes?: number;
  capacityMinutes?: number;
  mode?: CompressionMode;
}

export interface CompressionSelectionCandidate {
  index: number;
  id: number;
  name: string;
  oldVal: number;
  minAllowed: number;
  maxReducible: number;
  isRigid: boolean;
  selectable: boolean;
  disabledReason?: string;
}

export interface CompressionSelectionContext {
  targetIndex: number;
  targetTime: string;
  neededGapMinutes: number;
  naturalArrivalMinutes: number;
  chainStartIndex: number;
  candidates: CompressionSelectionCandidate[];
}

export interface AdvanceAdjustCandidate {
  id: number;
  index: number;
  name: string;
  currentStartTime: string;
  currentEndTime: string;
  duration: number;
}

export interface AdvanceAdjustContext {
  targetIndex: number;
  targetId: number;
  targetDayOffset: number;
  candidates: AdvanceAdjustCandidate[];
}

export interface AdvanceAdjustPreviewItem {
  id: number;
  index: number;
  name: string;
  oldStartTime: string;
  oldEndTime: string;
  newStartTime: string;
  newEndTime: string;
}

export interface AdvanceAdjustPreview {
  valid: boolean;
  message: string;
  selectedCount: number;
  shiftMinutes: number;
  requiredGapMinutes: number;
  remainingGapMinutes: number;
  firstNewStartTime: string;
  lastNewEndTime: string;
  items: AdvanceAdjustPreviewItem[];
}

export interface AdvanceAdjustApplyResult {
  success: boolean;
  appliedCount: number;
  appliedShiftMinutes: number;
  remainingGapMinutes: number;
  message: string;
}

export interface ITimelineCompressionHost {
  events: EventEntity[];
  planId: number;
  globalStartTime: string;
  getMinEventDurationLimit(): number;
  getEffectiveDayOffset(item: EventEntity): number;
  resolveEffectiveGlobalStartMinutes(): number;
  recalculateFromEventId(eventId: number): void;
  recalculateFromIndex(startIndex: number): void;
  markHasUnsavedPostpone(): void;
}

export interface ITimelineCompressionService {
  fixConflict(item: TravelPlanItem | EventEntity, shiftMinutes: number): Promise<void>;
  smartFixConflict(targetItem: EventEntity): Promise<void>;
  calculateCompressionPlan(targetIndex: number, newTimeStr: string, forcedGapMinutes?: number): CompressionPlan;
  buildCompressionSelectionContext(targetIndex: number, targetTime: string, forcedGapMinutes?: number): CompressionSelectionContext | null;
  buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null;
  previewAdvanceAdjust(targetIndex: number, selectedIds: Set<number>, targetStartTime: string, forcedGapMinutes?: number): AdvanceAdjustPreview;
  applyAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): Promise<AdvanceAdjustApplyResult>;
  calculateCompressionPlanBySelection(
    targetIndex: number,
    targetTime: string,
    selectedIds: Set<number>,
    mode?: CompressionMode,
    forcedGapMinutes?: number
  ): CompressionPlan;
  applyCompressionPlan(plan: CompressionPlan): void;
  calculateDelayPlan(targetIndex: number): CompressionPlan;
  calculateForceCompressPlan(targetIndex: number, newTimeStr: string): CompressionPlan;
  calculateNaturalArrival(targetIndex: number): number;
}

export class TimelineCompressionService implements ITimelineCompressionService {
  private host: ITimelineCompressionHost;

  constructor(host: ITimelineCompressionHost) {
    this.host = host;
  }

  public async fixConflict(item: TravelPlanItem | EventEntity, shiftMinutes: number): Promise<void> {
    const updated = await TimelineConflictResolver.fixConflict(this.host.events, item.id || 0, shiftMinutes, this.host.planId);
    if (updated) {
      this.host.recalculateFromEventId(item.id || 0);
    }
  }

  public async smartFixConflict(targetItem: EventEntity): Promise<void> {
    if (!targetItem || !targetItem.is_conflict) {
      return;
    }

    const index = this.host.events.indexOf(targetItem);
    if (index === -1) {
      return;
    }

    if (targetItem.lock_status === 1 && targetItem.fixed_start_time) {
      console.info(TAG, `SmartFix: 检测到刚性冲突 [${targetItem.name}]，尝试反向压缩...`);

      const plan = this.calculateCompressionPlan(index, targetItem.fixed_start_time);

      if (plan.status === 'NO_ACTION' || plan.status === 'COMPRESS_CONFIRM') {
        if (plan.status === 'COMPRESS_CONFIRM') {
          this.applyCompressionPlan(plan);
        }
        this.host.markHasUnsavedPostpone();
        return;
      }

      console.warn(TAG, 'SmartFix: 刚性冲突且无法压缩，修复失败。请用户手动调整。');
      return;
    }
  }

  public calculateCompressionPlan(targetIndex: number, newTimeStr: string, forcedGapMinutes?: number): CompressionPlan {
    const context = this.buildCompressionSelectionContext(targetIndex, newTimeStr, forcedGapMinutes);
    if (!context || context.neededGapMinutes <= 0) {
      return { status: 'NO_ACTION', msg: '时间充裕', affectedItems: [] };
    }

    const selectedIds = new Set<number>();
    context.candidates.forEach((candidate: CompressionSelectionCandidate) => {
      if (candidate.selectable) {
        selectedIds.add(candidate.id);
      }
    });
    return this.calculateCompressionPlanBySelection(targetIndex, newTimeStr, selectedIds, 'RATIO', forcedGapMinutes);
  }

  private resolveSameDayScheduleStartIndex(targetIndex: number, targetDayOffset: number): number {
    let dayStartIndex = targetIndex;
    for (let i = targetIndex - 1; i >= 0; i--) {
      const item = this.host.events[i];
      if (item.status !== 1) {
        continue;
      }
      const dayOffset = this.host.getEffectiveDayOffset(item);
      if (dayOffset !== targetDayOffset) {
        continue;
      }
      dayStartIndex = i;
    }
    return dayStartIndex;
  }

  private buildCompressionSelectionContextInternal(
    targetIndex: number,
    targetTime: string,
    forcedGapMinutes?: number
  ): CompressionSelectionContext | null {
    if (targetIndex <= 0 || !this.host.events[targetIndex]) {
      return null;
    }
    if (!DateUtil.isValidTimeString(targetTime)) {
      return null;
    }

    const naturalArrivalMinutes = this.calculateNaturalArrival(targetIndex);
    const targetMinutes = DateUtil.timeToMinutes(targetTime);
    const targetDayOffset = this.host.getEffectiveDayOffset(this.host.events[targetIndex]);
    const computedGapMinutes = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);
    const forcedGap = Number.isFinite(forcedGapMinutes) ? Math.max(0, Math.floor(forcedGapMinutes ?? 0)) : 0;
    const neededGapMinutes = Math.max(computedGapMinutes, forcedGap);
    const sameDayStartIndex = this.resolveSameDayScheduleStartIndex(targetIndex, targetDayOffset);
    let chainStartIndex = sameDayStartIndex;
    for (let i = targetIndex - 1; i >= sameDayStartIndex; i--) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }
      if (item.lock_status === 1 && item.fixed_start_time) {
        chainStartIndex = i;
        break;
      }
    }
    const minKeepDuration = this.host.getMinEventDurationLimit();

    const candidates: CompressionSelectionCandidate[] = [];
    for (let i = 0; i < targetIndex; i++) {
      const item = this.host.events[i];
      if (item.status !== 1) {
        continue;
      }
      if (this.host.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }

      const minAllowed = Math.min(item.duration, minKeepDuration);
      const maxReducible = Math.max(0, item.duration - minAllowed);
      const isRigid = item.lock_status === 1;
      const withinActiveChain = i >= chainStartIndex;
      const selectable = !isRigid && withinActiveChain && maxReducible > 0;
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
        minAllowed: minAllowed,
        maxReducible: maxReducible,
        isRigid: isRigid,
        selectable: selectable,
        disabledReason: disabledReason
      });
    }

    return {
      targetIndex: targetIndex,
      targetTime: targetTime,
      neededGapMinutes: neededGapMinutes,
      naturalArrivalMinutes: naturalArrivalMinutes,
      chainStartIndex: chainStartIndex,
      candidates: candidates
    };
  }

  public buildCompressionSelectionContext(targetIndex: number, targetTime: string, forcedGapMinutes?: number): CompressionSelectionContext | null {
    return this.buildCompressionSelectionContextInternal(targetIndex, targetTime, forcedGapMinutes);
  }

  private formatMinuteOnDay(totalMinutes: number): string {
    const normalized = ((Math.floor(totalMinutes) % (24 * 60)) + (24 * 60)) % (24 * 60);
    return DateUtil.minutesToTime(normalized);
  }

  private resolveEffectiveTravelMinutes(item: EventEntity): number {
    if (!item) {
      return 0;
    }
    const raw = item.pre_travel_min;
    if (!Number.isFinite(raw) || raw <= 0) {
      return 0;
    }
    return Math.floor(raw);
  }

  private resolvePlannedStartMinutes(item: EventEntity): number {
    if (!item) {
      return 0;
    }
    const raw = DateUtil.extractPureTime(item.fixed_start_time || item.computed_time || '');
    const minute = raw && DateUtil.isValidTimeString(raw)
      ? DateUtil.timeToMinutes(raw)
      : this.host.resolveEffectiveGlobalStartMinutes();
    const dayOffset = this.host.getEffectiveDayOffset(item);
    return dayOffset * 24 * 60 + minute;
  }

  private resolveConflictTargetTime(target: EventEntity): string {
    const raw = DateUtil.extractPureTime(target.fixed_start_time || target.computed_time || '');
    if (raw && DateUtil.isValidTimeString(raw)) {
      return raw;
    }
    return this.formatMinuteOnDay(this.resolvePlannedStartMinutes(target));
  }

  private resolveRequiredGapMinutes(targetIndex: number, forcedGapMinutes?: number): number {
    const fallbackGap = Number.isFinite(forcedGapMinutes)
      ? Math.max(0, Math.floor(forcedGapMinutes ?? 0))
      : 0;
    const target = this.host.events[targetIndex];
    if (!target || target.status !== 1) {
      return fallbackGap;
    }
    const targetTime = this.resolveConflictTargetTime(target);
    const context = this.buildCompressionSelectionContextInternal(targetIndex, targetTime, forcedGapMinutes);
    if (!context) {
      return fallbackGap;
    }
    return Math.max(0, context.neededGapMinutes);
  }

  public buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null {
    const target = this.host.events[targetIndex];
    if (!target || target.status !== 1 || targetIndex <= 0) {
      return null;
    }
    const targetDayOffset = this.host.getEffectiveDayOffset(target);
    let prevRigidIndex = -1;
    for (let i = targetIndex - 1; i >= 0; i--) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }
      if (item.lock_status === 1) {
        prevRigidIndex = i;
        break;
      }
    }

    const candidates: AdvanceAdjustCandidate[] = [];
    for (let i = prevRigidIndex + 1; i < targetIndex; i++) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }
      if (item.lock_status === 1) {
        continue;
      }
      const startMin = this.resolvePlannedStartMinutes(item);
      const endMin = startMin + item.duration;
      candidates.push({
        id: item.id,
        index: i,
        name: item.name,
        currentStartTime: this.formatMinuteOnDay(startMin),
        currentEndTime: this.formatMinuteOnDay(endMin),
        duration: item.duration
      });
    }

    return {
      targetIndex: targetIndex,
      targetId: target.id,
      targetDayOffset: targetDayOffset,
      candidates: candidates
    };
  }

  private isContinuousAdvanceSelection(candidates: AdvanceAdjustCandidate[], selectedIds: Set<number>): boolean {
    const selected: number[] = candidates
      .filter((item: AdvanceAdjustCandidate): boolean => selectedIds.has(item.id))
      .map((item: AdvanceAdjustCandidate): number => item.index)
      .sort((a: number, b: number): number => a - b);
    if (selected.length === 0) {
      return false;
    }
    for (let i = 1; i < selected.length; i++) {
      if (selected[i] !== selected[i - 1] + 1) {
        return false;
      }
    }
    return true;
  }

  public previewAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): AdvanceAdjustPreview {
    const requiredGapMinutes = this.resolveRequiredGapMinutes(targetIndex, forcedGapMinutes);
    const context = this.buildAdvanceAdjustContext(targetIndex);
    if (!context) {
      return {
        valid: false,
        message: '当前无可前移地点',
        selectedCount: 0,
        shiftMinutes: 0,
        requiredGapMinutes: requiredGapMinutes,
        remainingGapMinutes: requiredGapMinutes,
        firstNewStartTime: '',
        lastNewEndTime: '',
        items: []
      };
    }
    if (!DateUtil.isValidTimeString(targetStartTime)) {
      return {
        valid: false,
        message: '新开始时间格式无效',
        selectedCount: 0,
        shiftMinutes: 0,
        requiredGapMinutes: requiredGapMinutes,
        remainingGapMinutes: requiredGapMinutes,
        firstNewStartTime: '',
        lastNewEndTime: '',
        items: []
      };
    }
    if (!this.isContinuousAdvanceSelection(context.candidates, selectedIds)) {
      return {
        valid: false,
        message: '仅支持选择连续地点',
        selectedCount: selectedIds.size,
        shiftMinutes: 0,
        requiredGapMinutes: requiredGapMinutes,
        remainingGapMinutes: requiredGapMinutes,
        firstNewStartTime: '',
        lastNewEndTime: '',
        items: []
      };
    }

    const selected: AdvanceAdjustCandidate[] = context.candidates
      .filter((item: AdvanceAdjustCandidate): boolean => selectedIds.has(item.id))
      .sort((a: AdvanceAdjustCandidate, b: AdvanceAdjustCandidate): number => a.index - b.index);
    if (selected.length === 0) {
      return {
        valid: false,
        message: '请至少选择一个地点',
        selectedCount: 0,
        shiftMinutes: 0,
        requiredGapMinutes: requiredGapMinutes,
        remainingGapMinutes: requiredGapMinutes,
        firstNewStartTime: '',
        lastNewEndTime: '',
        items: []
      };
    }

    const firstSelected = selected[0];
    const firstEntity = this.host.events[firstSelected.index];
    const firstCurrentStart = this.resolvePlannedStartMinutes(firstEntity);
    const targetStartAbsolute = context.targetDayOffset * 24 * 60 + DateUtil.timeToMinutes(targetStartTime);
    if (targetStartAbsolute >= firstCurrentStart) {
      return {
        valid: false,
        message: '新开始时间必须早于当前计划开始时间',
        selectedCount: selected.length,
        shiftMinutes: 0,
        requiredGapMinutes: requiredGapMinutes,
        remainingGapMinutes: requiredGapMinutes,
        firstNewStartTime: '',
        lastNewEndTime: '',
        items: []
      };
    }

    let prevBoundaryIndex = -1;
    for (let i = firstSelected.index - 1; i >= 0; i--) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== context.targetDayOffset) {
        continue;
      }
      prevBoundaryIndex = i;
      break;
    }
    if (prevBoundaryIndex >= 0) {
      const prevBoundary = this.host.events[prevBoundaryIndex];
      const prevEnd = this.resolvePlannedStartMinutes(prevBoundary) + prevBoundary.duration;
      const requiredStart = prevEnd + this.resolveEffectiveTravelMinutes(firstEntity);
      if (targetStartAbsolute < requiredStart) {
        return {
          valid: false,
          message: '调整后将与前序边界冲突',
          selectedCount: selected.length,
          shiftMinutes: 0,
          requiredGapMinutes: requiredGapMinutes,
          remainingGapMinutes: requiredGapMinutes,
          firstNewStartTime: '',
          lastNewEndTime: '',
          items: []
        };
      }
    }

    const previewItems: AdvanceAdjustPreviewItem[] = [];
    const newStartMap = new Map<number, number>();
    const newEndMap = new Map<number, number>();
    let cursor = targetStartAbsolute;
    for (let i = 0; i < selected.length; i++) {
      const candidate = selected[i];
      const entity = this.host.events[candidate.index];
      const oldStart = this.resolvePlannedStartMinutes(entity);
      const oldEnd = oldStart + entity.duration;
      const newStart = cursor;
      const newEnd = newStart + entity.duration;
      newStartMap.set(candidate.index, newStart);
      newEndMap.set(candidate.index, newEnd);
      previewItems.push({
        id: candidate.id,
        index: candidate.index,
        name: candidate.name,
        oldStartTime: this.formatMinuteOnDay(oldStart),
        oldEndTime: this.formatMinuteOnDay(oldEnd),
        newStartTime: this.formatMinuteOnDay(newStart),
        newEndTime: this.formatMinuteOnDay(newEnd)
      });
      if (i < selected.length - 1) {
        const nextEntity = this.host.events[selected[i + 1].index];
        cursor = newEnd + this.resolveEffectiveTravelMinutes(nextEntity);
      }
    }

    const lastSelected = selected[selected.length - 1];
    let nextUnselectedIndex = -1;
    for (let i = lastSelected.index + 1; i < context.targetIndex; i++) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== context.targetDayOffset) {
        continue;
      }
      nextUnselectedIndex = i;
      break;
    }
    if (nextUnselectedIndex >= 0) {
      const nextItem = this.host.events[nextUnselectedIndex];
      const requiredArrival = (newEndMap.get(lastSelected.index) ?? 0) + this.resolveEffectiveTravelMinutes(nextItem);
      const nextStart = this.resolvePlannedStartMinutes(nextItem);
      if (requiredArrival > nextStart) {
        return {
          valid: false,
          message: '调整后将与后续地点冲突',
          selectedCount: selected.length,
          shiftMinutes: 0,
          requiredGapMinutes: requiredGapMinutes,
          remainingGapMinutes: requiredGapMinutes,
          firstNewStartTime: '',
          lastNewEndTime: '',
          items: previewItems
        };
      }
    }

    const shiftMinutes = Math.max(0, firstCurrentStart - targetStartAbsolute);
    const remainingGapMinutes = Math.max(0, requiredGapMinutes - shiftMinutes);
    return {
      valid: true,
      message: remainingGapMinutes > 0
        ? `可应用前移调整，仍差 ${remainingGapMinutes} 分钟可消除冲突`
        : '可应用前移调整，可消除当前冲突',
      selectedCount: selected.length,
      shiftMinutes: shiftMinutes,
      requiredGapMinutes: requiredGapMinutes,
      remainingGapMinutes: remainingGapMinutes,
      firstNewStartTime: previewItems[0]?.newStartTime ?? '',
      lastNewEndTime: previewItems[previewItems.length - 1]?.newEndTime ?? '',
      items: previewItems
    };
  }

  public async applyAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes?: number
  ): Promise<AdvanceAdjustApplyResult> {
    const targetId = this.host.events[targetIndex]?.id ?? -1;
    const preview = this.previewAdvanceAdjust(targetIndex, selectedIds, targetStartTime, forcedGapMinutes);
    if (!preview.valid || preview.items.length === 0) {
      const currentGap = this.host.events[targetIndex]?.gap_minutes ?? 0;
      return {
        success: false,
        appliedCount: 0,
        appliedShiftMinutes: 0,
        remainingGapMinutes: Math.max(currentGap, preview.remainingGapMinutes),
        message: preview.message
      };
    }

    let minIndex = Number.MAX_SAFE_INTEGER;
    for (let i = 0; i < preview.items.length; i++) {
      const patch = preview.items[i];
      const item = this.host.events[patch.index];
      if (!item || item.status !== 1) {
        continue;
      }
      item.fixed_start_time = patch.newStartTime;
      if (patch.index < minIndex) {
        minIndex = patch.index;
      }
      if (item.id > 0) {
        await EventRepositoryImpl.updateSingleField(item.id, 'fixed_start_time', patch.newStartTime, this.host.planId);
      }
    }

    if (minIndex !== Number.MAX_SAFE_INTEGER) {
      this.host.recalculateFromIndex(minIndex > 0 ? minIndex - 1 : 0);
    }
    let liveRemaining = 0;
    if (targetId > 0) {
      const latestTarget = this.host.events.find((item: EventEntity) => item.id === targetId);
      liveRemaining = latestTarget?.gap_minutes ?? 0;
    } else {
      liveRemaining = this.host.events[targetIndex]?.gap_minutes ?? 0;
    }
    const remaining = Math.max(0, liveRemaining);
    hilog.info(
      0x0000,
      TAG,
      `[CONFLICT_DEBUG][advance_apply] targetIndex=${targetIndex}, targetId=${targetId}, forcedGap=${forcedGapMinutes ?? -1}, appliedShift=${preview.shiftMinutes}, required=${preview.requiredGapMinutes}, liveRemaining=${liveRemaining}, finalRemaining=${remaining}`
    );
    return {
      success: true,
      appliedCount: preview.items.length,
      appliedShiftMinutes: preview.shiftMinutes,
      remainingGapMinutes: remaining,
      message: remaining > 0 ? '前移已应用，仍存在部分冲突' : '前移调整已应用'
    };
  }

  private buildCompressionAffectedItems(
    selected: CompressionSelectionCandidate[],
    reducedMap: Map<number, number>
  ): CompressionAffectedItem[] {
    const affected: CompressionAffectedItem[] = [];
    selected.forEach((candidate: CompressionSelectionCandidate) => {
      const reduced = reducedMap.get(candidate.id) ?? 0;
      if (reduced <= 0) {
        return;
      }
      affected.push({
        index: candidate.index,
        name: candidate.name,
        oldVal: candidate.oldVal,
        newVal: candidate.oldVal - reduced
      });
    });
    return affected;
  }

  public calculateCompressionPlanBySelection(
    targetIndex: number,
    targetTime: string,
    selectedIds: Set<number>,
    mode: CompressionMode = 'RATIO',
    forcedGapMinutes?: number
  ): CompressionPlan {
    const context = this.buildCompressionSelectionContextInternal(targetIndex, targetTime, forcedGapMinutes);
    if (!context) {
      return { status: 'NO_ACTION', msg: '无需操作', affectedItems: [], mode: mode };
    }
    if (context.neededGapMinutes <= 0) {
      return { status: 'NO_ACTION', msg: '时间充裕', affectedItems: [], mode: mode };
    }

    const selected = context.candidates.filter((candidate: CompressionSelectionCandidate) =>
      selectedIds.has(candidate.id) && candidate.selectable
    );
    if (selected.length === 0) {
      return {
        status: 'OVERLOAD',
        msg: '请先选择至少一个可压缩地点',
        affectedItems: [],
        suggestedTime: DateUtil.minutesToTime(context.naturalArrivalMinutes),
        remainingGapMinutes: context.neededGapMinutes,
        capacityMinutes: 0,
        mode: mode
      };
    }

    const remainingCapMap = new Map<number, number>();
    const reducedMap = new Map<number, number>();
    const weightMap = new Map<number, number>();
    let capacityMinutes = 0;
    selected.forEach((candidate: CompressionSelectionCandidate) => {
      remainingCapMap.set(candidate.id, candidate.maxReducible);
      reducedMap.set(candidate.id, 0);
      weightMap.set(candidate.id, Math.max(1, candidate.oldVal));
      capacityMinutes += candidate.maxReducible;
    });

    let remainingNeed = context.neededGapMinutes;

    if (mode === 'EQUAL') {
      let progressed = true;
      while (remainingNeed > 0 && progressed) {
        progressed = false;
        for (let i = 0; i < selected.length; i++) {
          if (remainingNeed <= 0) {
            break;
          }
          const id = selected[i].id;
          const cap = remainingCapMap.get(id) ?? 0;
          if (cap <= 0) {
            continue;
          }
          remainingCapMap.set(id, cap - 1);
          reducedMap.set(id, (reducedMap.get(id) ?? 0) + 1);
          remainingNeed--;
          progressed = true;
        }
      }
    } else {
      let activeIds = selected.map((candidate: CompressionSelectionCandidate) => candidate.id);
      while (remainingNeed > 0 && activeIds.length > 0) {
        let totalWeight = 0;
        activeIds.forEach((id: number) => {
          totalWeight += (weightMap.get(id) ?? 0);
        });
        if (totalWeight <= 0) {
          break;
        }

        let allocatedThisRound = 0;
        const nextActiveIds: number[] = [];
        for (let i = 0; i < activeIds.length; i++) {
          const id = activeIds[i];
          const cap = remainingCapMap.get(id) ?? 0;
          if (cap <= 0) {
            continue;
          }
          const share = Math.floor(remainingNeed * ((weightMap.get(id) ?? 0) / totalWeight));
          const grant = Math.min(cap, Math.max(share, 0));
          if (grant > 0) {
            remainingCapMap.set(id, cap - grant);
            reducedMap.set(id, (reducedMap.get(id) ?? 0) + grant);
            remainingNeed -= grant;
            allocatedThisRound += grant;
          }
          if ((remainingCapMap.get(id) ?? 0) > 0) {
            nextActiveIds.push(id);
          }
        }

        if (allocatedThisRound === 0) {
          const sorted = [...activeIds].sort((a: number, b: number) => (weightMap.get(b) ?? 0) - (weightMap.get(a) ?? 0));
          for (let i = 0; i < sorted.length; i++) {
            if (remainingNeed <= 0) {
              break;
            }
            const id = sorted[i];
            const cap = remainingCapMap.get(id) ?? 0;
            if (cap <= 0) {
              continue;
            }
            remainingCapMap.set(id, cap - 1);
            reducedMap.set(id, (reducedMap.get(id) ?? 0) + 1);
            remainingNeed -= 1;
            allocatedThisRound += 1;
          }
          if (allocatedThisRound === 0) {
            break;
          }
        }

        activeIds = nextActiveIds.filter((id: number) => (remainingCapMap.get(id) ?? 0) > 0);
      }
    }

    const reducedTotal = context.neededGapMinutes - remainingNeed;
    const affectedItems = this.buildCompressionAffectedItems(selected, reducedMap);
    const suggestedMinutes = context.naturalArrivalMinutes - reducedTotal;
    const suggestedTime = DateUtil.minutesToTime(suggestedMinutes);
    const affectedDigest = affectedItems
      .map((item: CompressionAffectedItem) => `${item.name}:${item.oldVal}->${item.newVal}`)
      .join('|');

    if (remainingNeed > 0) {
      hilog.info(
        0x0000,
        TAG,
        `[CONFLICT_DEBUG][compress_calc] status=OVERLOAD, targetIndex=${targetIndex}, targetTime=${targetTime}, needed=${context.neededGapMinutes}, reduced=${reducedTotal}, remain=${remainingNeed}, forcedGap=${forcedGapMinutes ?? -1}, selected=${selected.length}, affected=${affectedDigest}`
      );
      return {
        status: 'OVERLOAD',
        msg: `所选地点可压缩总量不足，仍冲突 ${remainingNeed} 分钟`,
        affectedItems: affectedItems,
        suggestedTime: suggestedTime,
        remainingGapMinutes: remainingNeed,
        capacityMinutes: capacityMinutes,
        mode: mode
      };
    }

    hilog.info(
      0x0000,
      TAG,
      `[CONFLICT_VM][compress_plan_ready] targetIndex=${targetIndex}, mode=${mode}, needed=${context.neededGapMinutes}, capacity=${capacityMinutes}`
    );
    hilog.info(
      0x0000,
      TAG,
      `[CONFLICT_DEBUG][compress_calc] status=COMPRESS_CONFIRM, targetIndex=${targetIndex}, targetTime=${targetTime}, needed=${context.neededGapMinutes}, reduced=${reducedTotal}, remain=0, forcedGap=${forcedGapMinutes ?? -1}, selected=${selected.length}, affected=${affectedDigest}`
    );

    return {
      status: 'COMPRESS_CONFIRM',
      msg: '需要压缩前序行程',
      affectedItems: affectedItems,
      suggestedTime: targetTime,
      remainingGapMinutes: 0,
      capacityMinutes: capacityMinutes,
      mode: mode
    };
  }

  public applyCompressionPlan(plan: CompressionPlan): void {
    if (!plan.affectedItems || plan.affectedItems.length === 0) {
      return;
    }

    let minChangedIndex = Number.MAX_SAFE_INTEGER;
    plan.affectedItems.forEach((change: CompressionAffectedItem) => {
      const item = this.host.events[change.index];
      item.duration = change.newVal;
      if (change.index < minChangedIndex) {
        minChangedIndex = change.index;
      }

      if (item.id) {
        void EventRepositoryImpl.updateSingleField(item.id, 'duration', change.newVal, this.host.planId);
      }
    });

    const startIndex = minChangedIndex > 0 ? minChangedIndex - 1 : 0;
    this.host.recalculateFromIndex(startIndex);
  }

  public calculateDelayPlan(targetIndex: number): CompressionPlan {
    const naturalArrivalMinutes = this.calculateNaturalArrival(targetIndex);
    const timeStr = DateUtil.minutesToTime(naturalArrivalMinutes);

    return {
      status: 'COMPRESS_CONFIRM',
      msg: '顺延',
      affectedItems: [],
      suggestedTime: timeStr
    };
  }

  public calculateForceCompressPlan(targetIndex: number, newTimeStr: string): CompressionPlan {
    const targetMinutes = DateUtil.timeToMinutes(newTimeStr);
    const naturalArrivalMinutes = this.calculateNaturalArrival(targetIndex);
    const targetDayOffset = this.host.getEffectiveDayOffset(this.host.events[targetIndex]);
    const neededGap = naturalArrivalMinutes - (targetDayOffset * 24 * 60 + targetMinutes);

    if (neededGap <= 0) {
      return {
        status: 'NO_ACTION',
        msg: '时间充裕',
        affectedItems: [],
        suggestedTime: newTimeStr
      };
    }

    let prevIndex = -1;
    for (let i = targetIndex - 1; i >= 0; i--) {
      if (this.host.events[i].lock_status !== 1) {
        prevIndex = i;
        break;
      }
    }

    if (prevIndex === -1) {
      return {
        status: 'OVERLOAD',
        msg: '前序行程均为固定时间，无法压缩',
        affectedItems: [],
        suggestedTime: DateUtil.minutesToTime(naturalArrivalMinutes)
      };
    }

    const item = this.host.events[prevIndex];
    const original = item.duration;
    const newDur = original - neededGap;
    const minKeepDuration = this.host.getMinEventDurationLimit();

    if (newDur < minKeepDuration) {
      return {
        status: 'FAIL_TOO_SHORT',
        msg: `行程将低于${minKeepDuration}分钟`,
        affectedItems: [{
          index: prevIndex,
          name: item.name,
          oldVal: original,
          newVal: newDur
        }],
        suggestedTime: ''
      };
    }

    return {
      status: 'COMPRESS_CONFIRM',
      msg: '强力压缩',
      affectedItems: [{
        index: prevIndex,
        name: item.name,
        oldVal: original,
        newVal: newDur
      }],
      suggestedTime: newTimeStr
    };
  }

  public calculateNaturalArrival(targetIndex: number): number {
    const target = this.host.events[targetIndex];
    if (!target || target.status !== 1) {
      return 0;
    }
    const targetDayOffset = this.host.getEffectiveDayOffset(target);
    const sameDayStartIndex = this.resolveSameDayScheduleStartIndex(targetIndex, targetDayOffset);
    let chainStartIndex = sameDayStartIndex;
    for (let i = targetIndex - 1; i >= sameDayStartIndex; i--) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }
      if (item.lock_status === 1 && item.fixed_start_time) {
        chainStartIndex = i;
        break;
      }
    }

    let startMinutes = 0;
    const chainStartItem = this.host.events[chainStartIndex];
    if (chainStartItem) {
      startMinutes = this.resolvePlannedStartMinutes(chainStartItem);
    } else {
      startMinutes = targetDayOffset * 24 * 60 + this.host.resolveEffectiveGlobalStartMinutes();
    }

    let currentCursor = startMinutes;
    for (let i = chainStartIndex; i < targetIndex; i++) {
      const item = this.host.events[i];
      if (item.status !== 1 || this.host.getEffectiveDayOffset(item) !== targetDayOffset) {
        continue;
      }
      if (i > chainStartIndex) {
        currentCursor += this.resolveEffectiveTravelMinutes(item);
      }
      currentCursor += item.duration;
    }

    const targetItem = this.host.events[targetIndex];
    currentCursor += this.resolveEffectiveTravelMinutes(targetItem);

    return currentCursor;
  }
}

