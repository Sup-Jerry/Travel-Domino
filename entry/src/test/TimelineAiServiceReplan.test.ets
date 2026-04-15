import { describe, expect, it } from '@ohos/hypium';
import {
  AiReplanApplyDecision,
  AiReplanPreviewResult,
  AiReplanUndoToken,
  ITimelineAiHost,
  TimelineAiService
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
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

class DummyWeatherFacade {
}

interface PreviewSeedItem {
  name: string;
  duration: number;
  itemType: number;
  aiReasoning: string;
}

class FakePersistence extends PlanPersistenceFacade {
  private snapshot: PlanEventsSnapshot;
  public saveAllEventsCalls: number = 0;
  public updateStrategyModeCalls: number = 0;
  public saveAiContextCalls: number = 0;

  constructor(snapshot: PlanEventsSnapshot) {
    super();
    this.snapshot = snapshot;
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return this.snapshot;
  }

  async saveAllEvents(_planId: number, events: TravelPlanItem[]): Promise<void> {
    this.saveAllEventsCalls += 1;
    const saved: TravelPlanItem[] = [];
    for (let i = 0; i < events.length; i++) {
      saved.push(events[i]);
    }
    this.snapshot = {
      plan: this.snapshot.plan,
      events: saved
    };
  }

  async updateStrategyMode(_planId: number, _mode: number): Promise<void> {
    this.updateStrategyModeCalls += 1;
  }

  async saveAiContext(_planId: number, _prompt: string, _explanation: string): Promise<void> {
    this.saveAiContextCalls += 1;
  }
}

class FakeTimelineAiHost implements ITimelineAiHost {
  events: EventEntity[];
  planId: number;
  currentStrategyMode: number = 0;
  isRegenerating: boolean = false;
  weatherFeatureEnabled: boolean = false;
  weatherUserPreference: WeatherUserPreference = DEFAULT_WEATHER_USER_PREFERENCE;
  weatherCollabOptions: WeatherCollabOptions = {};
  weatherStrategyHint: string = '';
  strategyAdaptationPrompt: AdaptationPrompt | null = null;
  behaviorTracker: UserBehaviorTracker = new UserBehaviorTracker();
  persistence: PlanPersistenceFacade;
  weatherFacade: WeatherFacade;
  recalculateCalls: number = 0;
  scheduleChangedCalls: number = 0;

  constructor(planId: number, events: EventEntity[], persistence: PlanPersistenceFacade) {
    this.planId = planId;
    this.events = events;
    this.persistence = persistence;
    this.weatherFacade = new DummyWeatherFacade() as WeatherFacade;
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
    return {
      density: 1,
      pace: 1,
      preference: 0,
      energy: 1
    };
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
        suggestionId: 's',
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

function createTravelItem(id: number, name: string, source: number = 1): TravelPlanItem {
  return {
    id: id,
    name: name,
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: id * 100,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '',
    dayOffset: 0,
    itemType: 0,
    priority: 1,
    isTravelManual: 0,
    source: source,
    aiReasoning: 'r',
    delFlag: 0,
    groupId: 0,
    address: '',
    travelMode: 2
  };
}

function createEntityFromItem(item: TravelPlanItem, planId: number): EventEntity {
  return EventEntity.fromInterface(item, planId);
}

function createPreview(mode: number, names: string[]): AiReplanPreviewResult {
  const items: PreviewSeedItem[] = [];
  for (let i = 0; i < names.length; i++) {
    const item: PreviewSeedItem = {
      name: names[i],
      duration: 90,
      itemType: i % 2,
      aiReasoning: 'r'
    };
    items.push(item);
  }
  return {
    prompt: '北京一日游',
    strategyMode: mode,
    generatedAt: Date.now(),
    itemCount: items.length,
    items: items
  };
}

function createUndoToken(events: TravelPlanItem[]): AiReplanUndoToken {
  return {
    createdAt: Date.now(),
    events: events,
    strategyMode: 0,
    strategyDensity: 1,
    strategyPace: 1,
    strategyPreference: 0,
    strategyEnergy: 1,
    lastAiPrompt: 'p',
    lastStrategyExplanation: 'e'
  };
}

export default function timelineAiServiceReplanTest() {
  describe('timelineAiServiceReplanTest', () => {
    it('normal: restore_from_undo_token_should_restore_events_and_mode', 0, async () => {
      // Arrange
      const seed = createTravelItem(11, 'seed');
      const persistence = new FakePersistence({ events: [] } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, [], persistence);
      host.currentStrategyMode = 2;
      const service = new TimelineAiService(host);
      const token = createUndoToken([seed]);

      // Act
      await service.restoreFromUndoToken(token);

      // Assert
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].name).assertEqual('seed');
      expect(host.currentStrategyMode).assertEqual(0);
      expect(persistence.saveAllEventsCalls).assertEqual(1);
    });

    it('boundary: apply_replan_preview_keep_should_insert_single_item', 0, async () => {
      // Arrange
      const persistence = new FakePersistence({ events: [] } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, [], persistence);
      const service = new TimelineAiService(host);
      const preview = createPreview(0, ['new_a']);
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        return 501;
      });

      // Act
      const token = await service.applyReplanPreview(preview, 'KEEP');

      // Assert
      expect(token.events.length).assertEqual(0);
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].id).assertEqual(501);
      TimelineAiService.setInsertAiEventHookForTest(null);
    });

    it('invalid: apply_replan_preview_should_fail_when_preview_empty', 0, async () => {
      // Arrange
      const persistence = new FakePersistence({ events: [] } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, [], persistence);
      const service = new TimelineAiService(host);
      const preview = createPreview(0, []);

      // Act
      let message = '';
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('预览结果为空，无法应用');
    });

    it('conflict: build_replan_preview_should_reject_when_generating', 0, async () => {
      // Arrange
      const persistence = new FakePersistence({ events: [] } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, [], persistence);
      host.isRegenerating = true;
      const service = new TimelineAiService(host);

      // Act
      let message = '';
      try {
        await service.buildReplanPreview(0);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('正在生成中，请稍后重试');
    });

    it('regression: td-20260415-apply_replan_preview_should_release_regenerating_flag_after_failure', 0, async () => {
      // Arrange
      const persistence = new FakePersistence({ events: [] } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, [], persistence);
      const service = new TimelineAiService(host);
      const preview = createPreview(0, ['new_a']);
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        throw new Error('always_fail');
      });

      // Act
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (_error) {
      }
      TimelineAiService.setInsertAiEventHookForTest(null);

      // Assert
      expect(host.isRegenerating).assertFalse();
    });

    it('combined: apply_replan_preview_should_rollback_snapshot_on_insert_failure', 0, async () => {
      // Arrange
      const seed = createTravelItem(21, 'old_ai', 1);
      const seedEntity = createEntityFromItem(seed, 1);
      const persistence = new FakePersistence({
        plan: {
          id: 1,
          title: 'p',
          createdAt: 1,
          strategyMode: 0,
          strategyDensity: 1,
          strategyPace: 1,
          strategyPreference: 0,
          strategyEnergy: 1
        },
        events: [seed]
      } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, [seedEntity], persistence);
      const service = new TimelineAiService(host);
      const preview = createPreview(0, ['new_a', 'new_b']);
      let insertCalls = 0;
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        insertCalls += 1;
        if (insertCalls === 1) {
          return 601;
        }
        throw new Error('insert_fail');
      });

      // Act
      let message = '';
      try {
        await service.applyReplanPreview(preview, 'KEEP');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      TimelineAiService.setInsertAiEventHookForTest(null);

      // Assert
      expect(insertCalls).assertEqual(2);
      expect(message.indexOf('insert_fail') >= 0).assertTrue();
      expect(persistence.saveAllEventsCalls).assertEqual(1);
      expect(host.events.length).assertEqual(1);
      expect(host.events[0].name).assertEqual('old_ai');
      expect(host.isRegenerating).assertFalse();
    });

    it('combined: apply_replan_preview_overwrite_should_restore_old_ai_when_insert_fails', 0, async () => {
      // Arrange
      const oldAi = createTravelItem(31, 'old_ai', 1);
      const oldManual = createTravelItem(32, 'old_manual', 0);
      const hostEvents: EventEntity[] = [
        createEntityFromItem(oldAi, 1),
        createEntityFromItem(oldManual, 1)
      ];
      const persistence = new FakePersistence({
        plan: {
          id: 1,
          title: 'p',
          createdAt: 1,
          strategyMode: 2,
          strategyDensity: 1,
          strategyPace: 1,
          strategyPreference: 0,
          strategyEnergy: 1
        },
        events: [oldAi, oldManual]
      } as PlanEventsSnapshot);
      const host = new FakeTimelineAiHost(1, hostEvents, persistence);
      host.currentStrategyMode = 2;
      const service = new TimelineAiService(host);
      const preview = createPreview(0, ['new_a', 'new_b']);
      let insertCalls = 0;
      TimelineAiService.setInsertAiEventHookForTest(async (): Promise<number> => {
        insertCalls += 1;
        if (insertCalls === 1) {
          return 701;
        }
        throw new Error('overwrite_insert_fail');
      });

      // Act
      let message = '';
      try {
        await service.applyReplanPreview(preview, 'OVERWRITE');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      TimelineAiService.setInsertAiEventHookForTest(null);

      // Assert
      expect(insertCalls).assertEqual(2);
      expect(message.indexOf('overwrite_insert_fail') >= 0).assertTrue();
      expect(persistence.saveAllEventsCalls).assertEqual(1);
      expect(host.events.length).assertEqual(2);
      expect(host.events[0].name).assertEqual('old_ai');
      expect(host.events[1].name).assertEqual('old_manual');
      expect(host.currentStrategyMode).assertEqual(2);
      expect(host.isRegenerating).assertFalse();
    });
  });
}
