import { describe, it, expect } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import {
  AiReplanPreviewResult,
  ITimelineAiHost,
  TimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { PlanPersistenceFacade, PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import {
  DEFAULT_WEATHER_USER_PREFERENCE,
  SoftReplanApplyResult,
  SoftReplanMode,
  WeatherCollabOptions,
  WeatherContextBuildResult,
  WeatherStageType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { AdaptationPrompt } from '../main/ets/domain/strategy/StrategyAdaptationEngine';

class StaticPatchDD {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

class WeatherFacadeDD {
}

class PersistenceDD extends PlanPersistenceFacade {
  snapshot: PlanEventsSnapshot;
  saveAiContextCalls: number = 0;
  updateStrategyModeCalls: number = 0;
  saveAllEventsCalls: number = 0;

  constructor(snapshot: PlanEventsSnapshot) {
    super();
    this.snapshot = snapshot;
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return this.snapshot;
  }

  async saveAllEvents(_planId: number, events: TravelPlanItem[]): Promise<void> {
    this.saveAllEventsCalls += 1;
    this.snapshot = { plan: this.snapshot.plan, events: events };
  }

  async saveAiContext(_planId: number, _prompt: string, _explanation: string): Promise<void> {
    this.saveAiContextCalls += 1;
  }

  async updateStrategyMode(_planId: number, _mode: number): Promise<void> {
    this.updateStrategyModeCalls += 1;
  }
}

class TimelineAiHostDD implements ITimelineAiHost {
  events: EventEntity[] = [];
  planId: number = 9301;
  currentStrategyMode: number = 0;
  isRegenerating: boolean = false;
  weatherFeatureEnabled: boolean = false;
  weatherUserPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: WeatherCollabOptions = {};
  weatherStrategyHint: string = '';
  strategyAdaptationPrompt: AdaptationPrompt | null = null;
  behaviorTracker: UserBehaviorTracker = new UserBehaviorTracker();
  persistence: PlanPersistenceFacade;
  weatherFacade: WeatherFacade = new WeatherFacadeDD() as WeatherFacade;
  scheduleChangedCalls: number = 0;
  recalculateCalls: number = 0;

  constructor(events: EventEntity[], persistence: PlanPersistenceFacade) {
    this.events = events;
    this.persistence = persistence;
  }

  resolveCurrentWeatherStage(): WeatherStageType {
    return 'PLANNING';
  }

  async applyPlanningWeatherResult(_result: WeatherContextBuildResult, _forceRefresh: boolean): Promise<void> {
    return;
  }

  composeWeatherConstraintPrompt(weatherAwareConstraint: string, weatherSummary: string): string {
    return `${weatherAwareConstraint}${weatherSummary}`;
  }

  async getCurrentStrategy(): Promise<ComposableStrategy> {
    return { density: 1, pace: 1, preference: 0, energy: 1 };
  }

  clampStrategyLevel(value: number): 0 | 1 | 2 {
    if (value <= 0) {
      return 0;
    }
    if (value >= 2) {
      return 2;
    }
    return 1;
  }

  async requestSoftReplan(_planId: number, _suggestionId: string, _mode: SoftReplanMode): Promise<SoftReplanApplyResult> {
    return {
      success: true,
      rolledBack: false,
      errorCode: '',
      preview: {
        suggestionId: 'dd',
        actionType: 'NONE',
        changedOrder: false,
        changedDurations: false,
        skippedNodeIds: [],
        affectedNodeIds: [],
        changeSummary: [],
        summary: 'ok',
        riskDelta: 0
      }
    };
  }

  markScheduleChanged(): void {
    this.scheduleChangedCalls += 1;
  }

  recalculateFromIndex(_startIndex: number): void {
    this.recalculateCalls += 1;
  }
}

interface PreviewItemDD {
  name: string;
  duration: number;
  itemType: number;
  aiReasoning: string;
}

function buildTravelItemDD(id: number, name: string, source: number, status: number, sortOrder: number): TravelPlanItem {
  return {
    id: id,
    name: name,
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: sortOrder,
    status: status,
    lockStatus: 0,
    fixedStartTime: '',
    dayOffset: 0,
    itemType: 0,
    priority: 1,
    isTravelManual: 0,
    source: source,
    aiReasoning: 'seed',
    delFlag: 0,
    groupId: 0,
    address: '',
    travelMode: 2
  };
}

function buildPreviewDD(): AiReplanPreviewResult {
  const items: PreviewItemDD[] = [
    { name: 'dd-new-a', duration: 50, itemType: 0, aiReasoning: 'a' },
    { name: 'dd-new-b', duration: 70, itemType: 1, aiReasoning: 'b' }
  ];
  return {
    prompt: 'DD one day plan',
    strategyMode: 1,
    generatedAt: Date.now(),
    itemCount: items.length,
    items: items
  };
}

export default function phase2BatchDDTest() {
  describe('phase2BatchDDTest', () => {
    it('normal: ai_replan_overwrite_success_should_sort_new_items_after_existing_schedule', 0, async () => {
      // Arrange
      const oldAi = buildTravelItemDD(1, 'dd-old-ai', 1, 1, 100);
      const manual = buildTravelItemDD(2, 'dd-manual', 0, 1, 300);
      const backlog = buildTravelItemDD(3, 'dd-backlog', 0, 0, 50);
      const events = [
        EventEntity.fromInterface(oldAi, 9301),
        EventEntity.fromInterface(manual, 9301),
        EventEntity.fromInterface(backlog, 9301)
      ];
      const persistence = new PersistenceDD({
        plan: {
          id: 9301,
          title: 'dd-plan',
          createdAt: 1,
          strategyMode: 0,
          strategyDensity: 1,
          strategyPace: 1,
          strategyPreference: 0,
          strategyEnergy: 1
        },
        events: [oldAi, manual, backlog]
      } as PlanEventsSnapshot);
      const host = new TimelineAiHostDD(events, persistence);
      const service = new TimelineAiService(host);
      let updateFieldsCalls = 0;
      let nextId = 9400;
      const deletePatch = new StaticPatchDD(EventRepositoryImpl, 'deleteEventsBySource', async (): Promise<void> => {});
      const updatePatch = new StaticPatchDD(EventRepositoryImpl, 'updateFields', async (): Promise<void> => {
        updateFieldsCalls += 1;
      });
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        nextId += 1;
        return nextId;
      });

      // Act
      const token = await service.applyReplanPreview(buildPreviewDD(), 'OVERWRITE');
      TimelineAiService.setInsertAiEventHookForTest(null);
      updatePatch.restore();
      deletePatch.restore();

      // Assert
      expect(token.events.length).assertEqual(3);
      expect(host.events.length).assertEqual(4);
      expect(host.events[0].id).assertEqual(2);
      expect(host.events[1].id).assertEqual(3);
      expect(host.events[2].sort_order).assertEqual(400);
      expect(host.events[3].sort_order).assertEqual(500);
      expect(updateFieldsCalls).assertEqual(2);
      expect(host.scheduleChangedCalls).assertEqual(1);
      expect(host.recalculateCalls).assertEqual(1);
      expect(persistence.saveAiContextCalls).assertEqual(1);
      expect(persistence.updateStrategyModeCalls).assertEqual(1);
    });
  });
}
