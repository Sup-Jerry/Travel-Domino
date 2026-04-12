import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineEventMutationManager, ITimelineEventMutationHost } from '../main/ets/viewmodel/managers/TimelineEventMutationManager';
import { GeoPointInput } from '../main/ets/domain/services/WeatherModels';
import {
  AiReplanApplyDecision,
  AiReplanPreviewResult,
  AiReplanUndoToken,
  ExecutionSuggestionApplyResult,
  ITimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { TimelineStrategyManager } from '../main/ets/viewmodel/managers/TimelineStrategyManager';
import { PlanPersistenceFacade } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { WeatherStrategyAdjustment } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { SoftReplanApplyResult } from '../main/ets/domain/services/WeatherModels';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';

class SimpleGeoPoint implements GeoPointInput {
  latitude: number = 0;
  longitude: number = 0;
}

class FakeTimelineAiService implements ITimelineAiService {
  async generateByAi(_userPrompt: string, _strategyMode?: number, _customStrategy?: ComposableStrategy): Promise<void> {
    return;
  }

  getStrategyMode(): number {
    return 0;
  }

  hasAiHistory(): boolean {
    return false;
  }

  async updateStrategyMode(_mode: number): Promise<void> {
    return;
  }

  async switchToCustomStrategy(_strategy: ComposableStrategy): Promise<void> {
    return;
  }

  async applyWeatherStrategyAdjustment(_adjustment?: WeatherStrategyAdjustment, _hint?: string): Promise<boolean> {
    return false;
  }

  async applyExecutionSuggestionWithStrategy(
    _planId: number,
    _suggestionId: string,
    _adjustment?: WeatherStrategyAdjustment,
    _hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    throw new Error('unused');
  }

  async applyWeatherSuggestion(_suggestionId: string): Promise<SoftReplanApplyResult> {
    throw new Error('unused');
  }

  async regenerateWithCustomStrategy(_strategy: ComposableStrategy): Promise<void> {
    return;
  }

  async regenerateByCurrentStrategy(): Promise<void> {
    return;
  }

  async changeStrategyAndRegenerate(_mode: number): Promise<void> {
    return;
  }

  async triggerStrategyAdaptation(): Promise<void> {
    return;
  }

  async buildReplanPreview(
    _strategyMode: number,
    _customStrategy?: ComposableStrategy,
    _keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    throw new Error('unused');
  }

  async applyReplanPreview(_preview: AiReplanPreviewResult, _decision: AiReplanApplyDecision): Promise<AiReplanUndoToken> {
    throw new Error('unused');
  }

  async restoreFromUndoToken(_token: AiReplanUndoToken): Promise<void> {
    return;
  }
}

class FakeTimelineEventMutationHost implements ITimelineEventMutationHost {
  events: EventEntity[] = [];
  planId: number = 1;
  enableAutoAmapRoute: boolean = true;
  enableGlobalAmapRouteApi: boolean = true;

  recalculateFromEventIdCalls: number = 0;
  recalculateFromIndexCalls: number = 0;
  recalculateFromIndexLast: number = -1;
  saveCalls: number = 0;
  updatePlanDateCalls: number = 0;
  refreshCalls: number = 0;
  endMutationCalls: number = 0;
  firstScheduleIds: number[] = [];

  isFirstScheduledItemOfDay(item: EventEntity): boolean {
    return this.firstScheduleIds.indexOf(item.id) >= 0;
  }

  async resolveCoordinatesForPlaceName(
    _placeName: string,
    lat?: number,
    lng?: number,
    _source?: 'add' | 'update',
    fallbackLat?: number,
    fallbackLng?: number
  ): Promise<GeoPointInput> {
    const point = new SimpleGeoPoint();
    point.latitude = (lat !== undefined && Number.isFinite(lat)) ? lat : (fallbackLat ?? 0);
    point.longitude = (lng !== undefined && Number.isFinite(lng)) ? lng : (fallbackLng ?? 0);
    return point;
  }

  isCoordinateMissingForWeather(latitude: number, longitude: number): boolean {
    return latitude === 0 || longitude === 0;
  }

  recalculateFromEventId(_eventId: number): void {
    this.recalculateFromEventIdCalls += 1;
  }

  recalculateFromIndex(startIndex: number): void {
    this.recalculateFromIndexCalls += 1;
    this.recalculateFromIndexLast = startIndex;
  }

  async save(): Promise<void> {
    this.saveCalls += 1;
  }

  async updatePlanDate(_newDateTimestamp: number): Promise<void> {
    this.updatePlanDateCalls += 1;
  }

  tryBeginMutation(_itemId: number): boolean {
    return true;
  }

  endMutation(_itemId: number): void {
    this.endMutationCalls += 1;
  }

  refreshTimelineView(): void {
    this.refreshCalls += 1;
  }
}

function createEvent(id: number, status: number, sortOrder: number, fixedStart: string, dayOffset: number): EventEntity {
  const item = new EventEntity(`event_${id}`, 30);
  item.id = id;
  item.status = status;
  item.sort_order = sortOrder;
  item.fixed_start_time = fixedStart;
  item.day_offset = dayOffset;
  item.dynamic_day_offset = dayOffset;
  item.computed_time = fixedStart;
  item.is_travel_manual = 0;
  item.pre_travel_min = 0;
  return item;
}

function createManager(host: FakeTimelineEventMutationHost): TimelineEventMutationManager {
  const behaviorTracker = new UserBehaviorTracker();
  const strategyManager = new TimelineStrategyManager(
    { planId: 1, persistence: new PlanPersistenceFacade() },
    new FakeTimelineAiService()
  );
  return new TimelineEventMutationManager(host, behaviorTracker, strategyManager);
}

export default function timelineEventMutationManagerTest() {
  describe('timelineEventMutationManagerTest', () => {
    it('normal: insert_smart_for_compat_should_insert_schedule_item_by_day_and_time', 0, () => {
      // Arrange
      const host = new FakeTimelineEventMutationHost();
      host.events = [
        createEvent(1, 1, 100, '10:00', 0),
        createEvent(2, 1, 200, '09:00', 1)
      ];
      const manager = createManager(host);
      const inserting = createEvent(3, 1, 0, '08:30', 0);
      // Act
      manager.insertSmartForCompat(inserting);
      // Assert
      expect(host.events.length).assertEqual(3);
      expect(host.events[0].id).assertEqual(3);
      expect(host.events[1].id).assertEqual(1);
      expect(host.events[2].id).assertEqual(2);
      expect(host.events[0].sort_order).assertEqual(0);
      expect(host.events[1].sort_order).assertEqual(100);
      expect(host.events[2].sort_order).assertEqual(200);
    });

    it('boundary: insert_smart_for_compat_should_append_backlog_item_to_tail', 0, () => {
      // Arrange
      const host = new FakeTimelineEventMutationHost();
      host.events = [
        createEvent(10, 1, 0, '09:00', 0),
        createEvent(11, 0, 0, '', 0)
      ];
      const manager = createManager(host);
      const backlog = createEvent(12, 0, 0, '', 0);
      // Act
      manager.insertSmartForCompat(backlog);
      // Assert
      expect(host.events.length).assertEqual(3);
      expect(host.events[2].id).assertEqual(12);
    });

    it('invalid: move_event_should_ignore_out_of_range_index', 0, async () => {
      // Arrange
      const host = new FakeTimelineEventMutationHost();
      host.events = [createEvent(20, 1, 0, '09:00', 0)];
      const manager = createManager(host);
      // Act
      await manager.moveEvent(-1, 'down');
      // Assert
      expect(host.events[0].id).assertEqual(20);
      expect(host.recalculateFromIndexCalls).assertEqual(0);
    });

    it('conflict: move_event_should_ignore_when_target_item_is_backlog', 0, async () => {
      // Arrange
      const host = new FakeTimelineEventMutationHost();
      host.events = [
        createEvent(30, 0, 0, '', 0),
        createEvent(31, 1, 100, '10:00', 0)
      ];
      const manager = createManager(host);
      // Act
      await manager.moveEvent(0, 'down');
      // Assert
      expect(host.events[0].id).assertEqual(30);
      expect(host.events[1].id).assertEqual(31);
      expect(host.recalculateFromIndexCalls).assertEqual(0);
    });

    it('regression: td-20260412-c4-move-all-backlog-to-schedule-should-enable-auto-pretravel', 0, async () => {
      // Arrange
      const host = new FakeTimelineEventMutationHost();
      const first = createEvent(40, 1, 100, '09:00', 0);
      const backlog = createEvent(41, 0, 0, '', 0);
      host.events = [first, backlog];
      host.firstScheduleIds = [40];
      const manager = createManager(host);
      // Act
      const moved = await manager.moveAllBacklogToSchedule();
      // Assert
      expect(moved).assertEqual(1);
      expect(backlog.status).assertEqual(1);
      expect(backlog.pre_travel_min).assertEqual(-1);
      expect(host.recalculateFromIndexCalls).assertEqual(1);
      expect(host.recalculateFromIndexLast).assertEqual(0);
      expect(host.saveCalls).assertEqual(1);
    });

    it('combined: move_all_backlog_to_schedule_should_sort_and_refresh_with_multiple_backlogs', 0, async () => {
      // Arrange
      const host = new FakeTimelineEventMutationHost();
      const schedule = createEvent(50, 1, 100, '09:00', 0);
      const backlogA = createEvent(51, 0, 0, '', 0);
      const backlogB = createEvent(52, 0, 0, '', 0);
      host.events = [backlogA, schedule, backlogB];
      host.firstScheduleIds = [50];
      const manager = createManager(host);
      // Act
      const moved = await manager.moveAllBacklogToSchedule();
      // Assert
      expect(moved).assertEqual(2);
      expect(host.events[0].id).assertEqual(50);
      expect(host.events[1].id).assertEqual(51);
      expect(host.events[2].id).assertEqual(52);
      expect(host.events[1].sort_order > host.events[0].sort_order).assertTrue();
      expect(host.events[2].sort_order > host.events[1].sort_order).assertTrue();
      expect(host.refreshCalls >= 2).assertTrue();
    });
  });
}
