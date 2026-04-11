import { describe, expect, it } from '@ohos/hypium';
import { TimelineStrategyManager, ITimelineStrategyHost } from '../main/ets/viewmodel/managers/TimelineStrategyManager';
import { ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import {
  ITimelineAiService,
  ExecutionSuggestionApplyResult,
  AiReplanApplyDecision,
  AiReplanPreviewResult,
  AiReplanUndoToken
} from '../main/ets/domain/timeline/services/TimelineAiService';
import { PlanPersistenceFacade, PlanEventsSnapshot } from '../main/ets/viewmodel/internal/PlanPersistenceFacade';
import { SoftReplanApplyResult } from '../main/ets/domain/services/WeatherModels';

class AiServiceSpy implements ITimelineAiService {
  mode: number = 0;
  history: boolean = false;
  applyAdjustmentResult: boolean = false;

  async generateByAi(_userPrompt: string, strategyMode?: number, _customStrategy?: ComposableStrategy): Promise<void> {
    if (strategyMode !== undefined) {
      this.mode = strategyMode;
    }
  }

  getStrategyMode(): number {
    return this.mode;
  }

  hasAiHistory(): boolean {
    return this.history;
  }

  async updateStrategyMode(mode: number): Promise<void> {
    this.mode = mode;
  }

  async switchToCustomStrategy(_strategy: ComposableStrategy): Promise<void> {}

  async applyWeatherStrategyAdjustment(_adjustment?: Object, _hint?: string): Promise<boolean> {
    return this.applyAdjustmentResult;
  }

  async applyExecutionSuggestionWithStrategy(
    _planId: number,
    _suggestionId: string,
    _adjustment?: Object,
    _hint?: string
  ): Promise<ExecutionSuggestionApplyResult> {
    return { strategyApplied: true, replanSuccess: true, errorCode: '' };
  }

  async applyWeatherSuggestion(_suggestionId: string): Promise<SoftReplanApplyResult> {
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
    } as SoftReplanApplyResult;
  }

  async regenerateWithCustomStrategy(_strategy: ComposableStrategy): Promise<void> {}
  async regenerateByCurrentStrategy(): Promise<void> {}
  async changeStrategyAndRegenerate(_mode: number): Promise<void> {}
  async triggerStrategyAdaptation(): Promise<void> {}
  async buildReplanPreview(
    strategyMode: number,
    customStrategy?: ComposableStrategy,
    _keepCurrentMode?: boolean
  ): Promise<AiReplanPreviewResult> {
    return {
      prompt: 'preview',
      strategyMode: strategyMode,
      customStrategy: customStrategy,
      generatedAt: Date.now(),
      itemCount: 0,
      items: []
    };
  }

  async applyReplanPreview(
    _preview: AiReplanPreviewResult,
    _decision: AiReplanApplyDecision
  ): Promise<AiReplanUndoToken> {
    return {
      createdAt: Date.now(),
      events: [],
      strategyMode: this.mode,
      strategyDensity: 1,
      strategyPace: 1,
      strategyPreference: 0,
      strategyEnergy: 1,
      lastAiPrompt: '',
      lastStrategyExplanation: ''
    };
  }

  async restoreFromUndoToken(_token: AiReplanUndoToken): Promise<void> {}
}

class FakePersistence extends PlanPersistenceFacade {
  private snapshot: PlanEventsSnapshot;

  constructor(snapshot: PlanEventsSnapshot) {
    super();
    this.snapshot = snapshot;
  }

  async getPlanAndEvents(_planId: number): Promise<PlanEventsSnapshot> {
    return this.snapshot;
  }
}

class StrategyHost implements ITimelineStrategyHost {
  planId: number;
  persistence: PlanPersistenceFacade;

  constructor(planId: number, persistence: PlanPersistenceFacade) {
    this.planId = planId;
    this.persistence = persistence;
  }
}

export default function timelineStrategyManagerTest() {
  describe('timelineStrategyManagerTest', () => {
    it('normal: get_strategy_mode_should_read_from_ai_service', 0, () => {
      // Arrange
      const ai = new AiServiceSpy();
      ai.mode = 2;
      const host = new StrategyHost(1, new FakePersistence({ events: [] }));
      const manager = new TimelineStrategyManager(host, ai);
      // Act
      const mode = manager.getStrategyMode();
      // Assert
      expect(mode).assertEqual(2);
    });

    it('boundary: clamp_strategy_level_should_clamp_to_0_and_2', 0, () => {
      // Arrange
      const ai = new AiServiceSpy();
      const host = new StrategyHost(1, new FakePersistence({ events: [] }));
      const manager = new TimelineStrategyManager(host, ai);
      // Act
      const low = manager.clampStrategyLevel(-10);
      const high = manager.clampStrategyLevel(10);
      // Assert
      expect(low).assertEqual(0);
      expect(high).assertEqual(2);
    });

    it('invalid: get_current_strategy_should_fallback_to_default_when_plan_missing', 0, async (done: () => void) => {
      // Arrange
      const ai = new AiServiceSpy();
      const host = new StrategyHost(1, new FakePersistence({ events: [] }));
      const manager = new TimelineStrategyManager(host, ai);
      // Act
      const strategy = await manager.getCurrentStrategy();
      // Assert
      expect(strategy.density).assertEqual(1);
      expect(strategy.pace).assertEqual(1);
      expect(strategy.preference).assertEqual(0);
      expect(strategy.energy).assertEqual(1);
      done();
    });

    it('conflict: apply_weather_strategy_adjustment_should_return_false_when_ai_service_rejects', 0, async (done: () => void) => {
      // Arrange
      const ai = new AiServiceSpy();
      ai.applyAdjustmentResult = false;
      const host = new StrategyHost(1, new FakePersistence({ events: [] }));
      const manager = new TimelineStrategyManager(host, ai);
      // Act
      const ok = await manager.applyWeatherStrategyAdjustment();
      // Assert
      expect(ok).assertFalse();
      done();
    });

    it('regression: td-20260411-c4-build-adaptation-key-should-normalize-invalid-values', 0, () => {
      // Arrange
      const ai = new AiServiceSpy();
      const host = new StrategyHost(1, new FakePersistence({ events: [] }));
      const manager = new TimelineStrategyManager(host, ai);
      // Act
      const key = manager.buildWeatherStrategyAdaptationKey(Number.NaN, Number.NaN);
      // Assert
      expect(key).assertEqual('0_-1');
    });

    it('combined: current_strategy_and_prompt_should_reflect_plan_snapshot_and_weather_text', 0, async (done: () => void) => {
      // Arrange
      const ai = new AiServiceSpy();
      ai.history = true;
      const snapshot = {
        plan: {
          id: 7,
          title: 'plan_7',
          createdAt: 1,
          strategyDensity: 2,
          strategyPace: 0,
          strategyPreference: 1,
          strategyEnergy: 2
        },
        events: []
      } as PlanEventsSnapshot;
      const host = new StrategyHost(7, new FakePersistence(snapshot));
      const manager = new TimelineStrategyManager(host, ai);
      // Act
      const strategy = await manager.getCurrentStrategy();
      const prompt = manager.composeWeatherConstraintPrompt('约束A', '摘要B');
      const hasHistory = manager.hasAiHistory();
      // Assert
      expect(strategy.density).assertEqual(2);
      expect(strategy.pace).assertEqual(0);
      expect(strategy.preference).assertEqual(1);
      expect(strategy.energy).assertEqual(2);
      expect(prompt.includes('策略天气联合约束')).assertTrue();
      expect(prompt.includes('约束A')).assertTrue();
      expect(prompt.includes('摘要B')).assertTrue();
      expect(hasHistory).assertTrue();
      done();
    });
  });
}
