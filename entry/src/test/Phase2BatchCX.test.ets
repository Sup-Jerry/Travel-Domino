import { describe, expect, it } from '@ohos/hypium';
import {
  SoftReplanApplyResult,
  SoftReplanMode,
  SoftReplanPreview,
  ReplanChangeSummaryItem,
  WeatherContextBuildResult,
  WeatherStageType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  AiReplanPreviewResult,
  ExecutionSuggestionApplyResult
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { CompressionPlan, TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import {
  AdvanceAdjustApplyResult,
  AdvanceAdjustContext,
  CompressionMode,
  CompressionSelectionContext,
  HistoryTimelineItem,
  HistoryTimelineSummary,
  ReflowHint,
  StartConflictInfo
} from '../main/ets/viewmodel/types/TimelineTypes';

class PlanDateShiftPreviewStubCX {
  hasRigidConflict: boolean = false;
  conflictItemId: number = 0;
  conflictItemName: string = '';
  gapMinutes: number = 0;
  conflictMsg: string = '';
}

class PlanStateManagerStubCX {
  preview: PlanDateShiftPreviewStubCX = new PlanDateShiftPreviewStubCX();
  updatedDate: number = 0;
  renamedTo: string = '';
  conflictResult: boolean = false;

  previewPlanDateShift(_newDateTimestamp: number): PlanDateShiftPreviewStubCX {
    return this.preview;
  }

  async updatePlanDate(newDateTimestamp: number): Promise<void> {
    this.updatedDate = newDateTimestamp;
  }

  async renamePlan(newName: string): Promise<void> {
    this.renamedTo = newName;
  }

  isDateConflict(_targetDateMs: number): boolean {
    return this.conflictResult;
  }
}

class WeatherCoordinatorStubCX {
  applyCalls: number = 0;
  stopCalls: number = 0;
  dismissId: string = '';
  coordinateMissingResult: boolean = true;
  autoRefreshResult: boolean = false;
  featureEnabled: boolean = false;
  preferenceRain: number = 0;

  async applyPlanningWeatherResult(_result: WeatherContextBuildResult, _forceRefresh: boolean): Promise<void> {
    this.applyCalls += 1;
  }

  stopExecutionWeatherScheduler(): void {
    this.stopCalls += 1;
  }

  async requestSoftReplan(
    _planId: number,
    suggestionId: string,
    mode: SoftReplanMode
  ): Promise<SoftReplanApplyResult> {
    const result = new SoftReplanApplyResultStubCX();
    result.preview.suggestionId = `${suggestionId}_${mode}`;
    result.preview.summary = 'soft_cx';
    return result;
  }

  dismissExecutionSuggestion(suggestionId: string): void {
    this.dismissId = suggestionId;
  }

  async applyWeatherSuggestion(suggestionId: string): Promise<SoftReplanApplyResult> {
    const result = new SoftReplanApplyResultStubCX();
    result.preview.suggestionId = suggestionId;
    result.preview.summary = 'apply_weather_cx';
    return result;
  }

  isCoordinateMissingForWeather(_latitude: number, _longitude: number): boolean {
    return this.coordinateMissingResult;
  }

  shouldAutoRefreshPlanningWeather(_maxAgeMs: number): boolean {
    return this.autoRefreshResult;
  }

  async setWeatherFeatureEnabled(enabled: boolean): Promise<void> {
    this.featureEnabled = enabled;
  }

  async updateWeatherUserPreference(preference: WeatherUserPreference): Promise<void> {
    this.preferenceRain = preference.rainSensitivity;
  }
}

class SoftReplanPreviewStubCX implements SoftReplanPreview {
  suggestionId: string = '';
  actionType: 'NONE' | 'PREPARE' | 'REORDER' | 'SHORTEN_STAY' | 'REPLACE_NODE' | 'SKIP_NODE' = 'NONE';
  changedOrder: boolean = false;
  changedDurations: boolean = false;
  skippedNodeIds: string[] = [];
  affectedNodeIds: string[] = [];
  startFromEventId: number = 0;
  changeSummary: ReplanChangeSummaryItem[] = [];
  summary: string = '';
  riskDelta: number = 0;
}

class SoftReplanApplyResultStubCX implements SoftReplanApplyResult {
  success: boolean = true;
  rolledBack: boolean = false;
  errorCode: '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY' = '';
  preview: SoftReplanPreview = new SoftReplanPreviewStubCX();
}

class StrategyManagerStubCX {
  calls: string[] = [];

  async generateByAi(userPrompt: string, strategyMode: number, _customStrategy?: ComposableStrategy): Promise<void> {
    this.calls.push(`generate:${userPrompt}:${strategyMode}`);
  }

  async switchToCustomStrategy(_strategy: ComposableStrategy): Promise<void> {
    this.calls.push('switch');
  }

  async regenerateWithCustomStrategy(_strategy: ComposableStrategy): Promise<void> {
    this.calls.push('regenCustom');
  }

  async regenerateByCurrentStrategy(): Promise<void> {
    this.calls.push('regenCurrent');
  }

  async changeStrategyAndRegenerate(mode: number): Promise<void> {
    this.calls.push(`change:${mode}`);
  }

  async buildReplanPreview(
    strategyMode: number,
    _customStrategy?: ComposableStrategy,
    keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    this.calls.push(`preview:${strategyMode}:${keepCurrentMode === true ? 1 : 0}`);
    return {
      prompt: 'preview_cx',
      strategyMode: strategyMode,
      generatedAt: 99,
      itemCount: 1,
      items: [{ name: 'cx_item', duration: 20, itemType: 1, aiReasoning: 'reason' }]
    } as AiReplanPreviewResult;
  }
}

class ExecutionServiceStubCX {
  calls: string[] = [];
  updateResult: boolean = true;
  conflictInfo: StartConflictInfo | null = {
    eventId: 9101,
    planId: 9201,
    name: 'conflict_cx',
    actualStartTime: 9301
  };

  async checkOutEvent(item: EventEntity): Promise<void> {
    this.calls.push(`checkout:${item.id}`);
  }

  async recordStartTime(item: EventEntity): Promise<void> {
    this.calls.push(`record:${item.id}`);
  }

  async updateActualTime(
    id: number,
    field: 'actual_start_time' | 'actual_end_time',
    timestamp: number
  ): Promise<boolean> {
    this.calls.push(`actual:${id}:${field}:${timestamp}`);
    return this.updateResult;
  }

  async getStartConflictInfo(excludeEventId: number): Promise<StartConflictInfo | null> {
    this.calls.push(`conflict:${excludeEventId}`);
    return this.conflictInfo;
  }
}

class ExecutionCoordinatorStubCX {
  ordered: EventEntity[] = [];
  orderedIndex: number = 2;
  next: EventEntity | null = null;
  firstOfDay: boolean = true;

  getOrderedScheduleEvents(): EventEntity[] {
    return this.ordered;
  }

  getOrderedScheduleIndexById(_eventId: number, _schedule?: EventEntity[]): number {
    return this.orderedIndex;
  }

  getNextExecutableEvent(_afterId: number, _schedule?: EventEntity[]): EventEntity | null {
    return this.next;
  }

  buildReflowHint(
    action: 'start' | 'end' | 'skip',
    beforeTs: number,
    afterTs: number,
    targetName: string,
    nextName: string
  ): ReflowHint {
    return {
      type: action === 'skip' ? 'next_changed' : 'shift',
      minutesDelta: Math.floor((afterTs - beforeTs) / 60000),
      message: `${targetName}->${nextName}`,
      updatedAt: 1
    };
  }

  isFirstScheduledItemOfDay(_item: EventEntity): boolean {
    return this.firstOfDay;
  }
}

class CompressionCoordinatorStubCX {
  delayPlan: CompressionPlan = {
    status: 'NO_ACTION',
    msg: 'delay_cx',
    affectedItems: []
  };
  advanceContext: AdvanceAdjustContext | null = {
    targetIndex: 1,
    targetId: 2,
    targetDayOffset: 0,
    candidates: []
  };
  selectionContext: CompressionSelectionContext | null = {
    targetIndex: 1,
    targetTime: '10:00',
    neededGapMinutes: 10,
    naturalArrivalMinutes: 600,
    chainStartIndex: 0,
    candidates: []
  };
  compressionPlan: CompressionPlan = {
    status: 'COMPRESS_CONFIRM',
    msg: 'compress_cx',
    affectedItems: []
  };
  applyCompressionCalls: number = 0;

  calculateDelayPlan(_targetIndex: number): CompressionPlan {
    return this.delayPlan;
  }

  buildAdvanceAdjustContext(_targetIndex: number): AdvanceAdjustContext | null {
    return this.advanceContext;
  }

  async applyAdvanceAdjust(
    _targetIndex: number,
    selectedIds: Set<number>,
    _targetStartTime: string,
    _forcedGapMinutes?: number
  ): Promise<AdvanceAdjustApplyResult> {
    return {
      success: selectedIds.size > 0,
      appliedCount: selectedIds.size,
      appliedShiftMinutes: 15,
      remainingGapMinutes: 0,
      message: 'advance_cx'
    };
  }

  buildCompressionSelectionContext(
    _targetIndex: number,
    _targetTime: string,
    _forcedGapMinutes?: number
  ): CompressionSelectionContext | null {
    return this.selectionContext;
  }

  calculateCompressionPlanBySelection(
    _targetIndex: number,
    _targetTime: string,
    _selectedIds: Set<number>,
    mode: CompressionMode,
    _forcedGapMinutes?: number
  ): CompressionPlan {
    this.compressionPlan.mode = mode;
    return this.compressionPlan;
  }

  applyCompressionPlan(_plan: CompressionPlan): void {
    this.applyCompressionCalls += 1;
  }
}

class HistoryManagerStubCX {
  summary: HistoryTimelineSummary = {
    planName: 'history_cx',
    completedCount: 1,
    skippedCount: 2,
    activeCount: 3
  };
  items: HistoryTimelineItem[] = [];

  getCurrentPlanHistorySummary(): HistoryTimelineSummary {
    return this.summary;
  }

  getCurrentPlanHistoryTimelineItems(_abnormalThresholdMinutes: number = 10): HistoryTimelineItem[] {
    return this.items;
  }
}

function createEventCX(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `cx_${id}`;
  event.status = 1;
  event.duration = 30;
  return event;
}

function createStrategyCX(): ComposableStrategy {
  return {
    density: 1,
    pace: 1,
    preference: 1,
    energy: 1
  } as ComposableStrategy;
}

export default function phase2BatchCXTest() {
  describe('phase2BatchCX_timeline_viewmodel_remaining_core_facades', () => {
    it('normal: plan_state_facade_should_delegate_preview_update_rename_and_conflict_check', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const manager = new PlanStateManagerStubCX();
      manager.preview.conflictItemName = 'rigid_cx';
      manager.conflictResult = true;
      Reflect.set(vm as Object, 'planStateManager', manager as Object);

      // Act
      const preview = vm.previewPlanDateShift(1733000000000);
      await vm.updatePlanDate(1733000001000);
      await vm.renamePlan('renamed_cx');
      const conflict = vm.isDateConflict(1733000002000);

      // Assert
      expect(preview.conflictItemName).assertEqual('rigid_cx');
      expect(manager.updatedDate).assertEqual(1733000001000);
      expect(manager.renamedTo).assertEqual('renamed_cx');
      expect(conflict).assertTrue();
    });

    it('boundary: weather_facade_should_delegate_soft_replan_suggestion_and_preferences', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const weather = new WeatherCoordinatorStubCX();
      Reflect.set(vm as Object, 'weatherCoordinator', weather as Object);

      // Act
      await vm.applyPlanningWeatherResult({} as WeatherContextBuildResult, true);
      vm.stopExecutionWeatherScheduler();
      const soft = await vm.requestSoftReplan(1, 'abc', 'APPLY' as SoftReplanMode);
      vm.dismissExecutionSuggestion('dismiss_cx');
      const applied = await vm.applyWeatherSuggestion('weather_cx');
      const missing = vm.isCoordinateMissingForWeather(0, 0);
      weather.autoRefreshResult = true;
      const autoRefresh = vm.shouldAutoRefreshPlanningWeather(1);
      await vm.setWeatherFeatureEnabled(true);
      await vm.updateWeatherUserPreference({
        heatSensitivity: 1,
        rainSensitivity: 2,
        weatherRiskTolerance: 2
      });

      // Assert
      expect(weather.applyCalls).assertEqual(1);
      expect(weather.stopCalls).assertEqual(1);
      expect(soft.success).assertTrue();
      expect(weather.dismissId).assertEqual('dismiss_cx');
      expect(applied.preview.summary).assertEqual('apply_weather_cx');
      expect(missing).assertTrue();
      expect(autoRefresh).assertTrue();
      expect(weather.featureEnabled).assertTrue();
      expect(weather.preferenceRain).assertEqual(2);
    });

    it('conflict: strategy_facade_should_refresh_after_generation_and_regeneration_paths', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const strategy = new StrategyManagerStubCX();
      let refreshCalls = 0;
      Reflect.set(vm as Object, 'strategyManager', strategy as Object);
      Reflect.set(vm as Object, 'refreshTimelineView', (): void => {
        refreshCalls += 1;
      });

      // Act
      await vm.generateByAi('prompt_cx', 2, createStrategyCX());
      await vm.switchToCustomStrategy(createStrategyCX());
      await vm.regenerateWithCustomStrategy(createStrategyCX());
      await vm.regenerateByCurrentStrategy();
      await vm.changeStrategyAndRegenerate(1);
      const preview = await vm.buildAiReplanPreview(2, createStrategyCX(), true);
      await vm.generateByAi('prompt_default_cx');
      const defaultPreview = await vm.buildAiReplanPreview(0);

      // Assert
      expect(strategy.calls.indexOf('generate:prompt_cx:2') >= 0).assertTrue();
      expect(strategy.calls.indexOf('generate:prompt_default_cx:0') >= 0).assertTrue();
      expect(strategy.calls.indexOf('switch') >= 0).assertTrue();
      expect(strategy.calls.indexOf('regenCustom') >= 0).assertTrue();
      expect(strategy.calls.indexOf('regenCurrent') >= 0).assertTrue();
      expect(strategy.calls.indexOf('change:1') >= 0).assertTrue();
      expect(preview.items.length).assertEqual(1);
      expect(defaultPreview.strategyMode).assertEqual(0);
      expect(refreshCalls).assertEqual(5);
    });

    it('regression: execution_facade_should_delegate_checkout_record_actual_time_and_conflict_info', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const service = new ExecutionServiceStubCX();
      const event = createEventCX(9301);
      Reflect.set(vm as Object, 'executionService', service as Object);

      // Act
      await vm.checkOutEvent(event);
      await vm.recordStartTime(event);
      const updated = await vm.updateActualTime(9301, 'actual_start_time', 1733000000000);
      const conflict = await vm.getStartConflictInfo(9301);

      // Assert
      expect(updated).assertTrue();
      expect(conflict?.name).assertEqual('conflict_cx');
      expect(service.calls.indexOf('checkout:9301') >= 0).assertTrue();
      expect(service.calls.indexOf('record:9301') >= 0).assertTrue();
      expect(service.calls.indexOf('actual:9301:actual_start_time:1733000000000') >= 0).assertTrue();
      expect(service.calls.indexOf('conflict:9301') >= 0).assertTrue();
    });

    it('combined: execution_and_compression_coordinators_should_return_planning_helpers', 0, async () => {
      // Arrange
      const vm = new TimelineViewModel();
      const execution = new ExecutionCoordinatorStubCX();
      const compression = new CompressionCoordinatorStubCX();
      const first = createEventCX(9401);
      const next = createEventCX(9402);
      execution.ordered = [first, next];
      execution.next = next;
      Reflect.set(vm as Object, 'executionCoordinator', execution as Object);
      Reflect.set(vm as Object, 'compressionCoordinator', compression as Object);

      // Act
      const ordered = vm.getOrderedScheduleEvents();
      const index = vm.getOrderedScheduleIndexById(9402, ordered);
      const executable = vm.getNextExecutableEvent(9401, ordered);
      const hint = vm.buildReflowHint('start', 0, 600000, 'a', 'b');
      const delayPlan = vm.calculateDelayPlan(1);
      const advanceContext = vm.buildAdvanceAdjustContext(1);
      const advanceResult = await vm.applyAdvanceAdjust(1, new Set<number>([9401]), '09:00');
      const selection = vm.buildCompressionSelectionContext(1, '10:00');
      const plan = vm.calculateCompressionPlanBySelection(1, '10:00', new Set<number>([9401]), 'RATIO');
      vm.applyCompressionPlan(plan);

      // Assert
      expect(ordered.length).assertEqual(2);
      expect(index).assertEqual(2);
      expect(executable?.id).assertEqual(9402);
      expect(hint.minutesDelta).assertEqual(10);
      expect(delayPlan.msg).assertEqual('delay_cx');
      expect(advanceContext?.targetId).assertEqual(2);
      expect(advanceResult.appliedCount).assertEqual(1);
      expect(selection?.targetTime).assertEqual('10:00');
      expect(plan.mode).assertEqual('RATIO');
      expect(compression.applyCompressionCalls).assertEqual(1);
    });

    it('invalid: history_and_first_item_facades_should_delegate_summary_and_day_boundary', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const history = new HistoryManagerStubCX();
      const execution = new ExecutionCoordinatorStubCX();
      const event = createEventCX(9501);
      Reflect.set(vm as Object, 'historyManager', history as Object);
      Reflect.set(vm as Object, 'executionCoordinator', execution as Object);

      // Act
      const summary = vm.getCurrentPlanHistorySummary();
      const items = vm.getCurrentPlanHistoryTimelineItems(5);
      const first = vm.isFirstScheduledItemOfDay(event);

      // Assert
      expect(summary.planName).assertEqual('history_cx');
      expect(items.length).assertEqual(0);
      expect(first).assertTrue();
    });
  });
}
