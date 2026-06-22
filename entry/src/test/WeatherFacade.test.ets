import { describe, it, expect } from '@ohos/hypium';
import { WeatherFacade } from '../main/ets/domain/services/WeatherFacade';
import { WeatherDomainService } from '../main/ets/domain/services/WeatherDomainService';
import { WeatherStageCoordinator } from '../main/ets/domain/services/WeatherStageCoordinator';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import {
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabOptions,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherSchedulePolicy,
  WeatherSuggestion,
  WeatherStageType,
  WeatherUserPreference
} from '../main/ets/domain/services/WeatherModels';

class MockWeatherDomainService extends WeatherDomainService {
  public planningCalls: number = 0;
  public executionCalls: number = 0;
  public adjustCalls: number = 0;
  public promptCalls: number = 0;

  public async buildPlanningContext(
    _events: EventEntity[],
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    _stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.planningCalls += 1;
    const map = new Map<number, PlanNodeWeatherBinding>();
    return {
      context: {
        stage: 'CONFIRMED',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 100, riskTags: [], summaryText: '' }
      },
      eventMap: map,
      sourceEvents: []
    };
  }

  public async buildExecutionContext(
    _events: EventEntity[],
    _currentLocation?: GeoPointInput,
    _forceRefresh: boolean = false,
    _preference?: WeatherUserPreference,
    _options?: WeatherCollabOptions,
    _stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    this.executionCalls += 1;
    const map = new Map<number, PlanNodeWeatherBinding>();
    return {
      context: {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 90, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 90,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: []
      },
      eventMap: map,
      sourceEvents: []
    };
  }

  public buildExecutionAdjustments(
    _planId: number,
    _context: WeatherContext,
    _futureNodes: EventEntity[],
    _preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    this.adjustCalls += 1;
    return [];
  }

  public buildPromptSummary(_context: WeatherContext, _preference?: WeatherUserPreference): string {
    this.promptCalls += 1;
    return 'prompt_summary';
  }
}

class MockWeatherStageCoordinator extends WeatherStageCoordinator {
  public resolveStageCalls: number = 0;
  public resolveScheduleCalls: number = 0;
  public nextStage: WeatherStageType = 'READY';

  public resolveStage(
    _status: PlanStatus,
    _events: EventEntity[],
    _runtimeState?: 'IDLE' | 'READY' | 'ACTIVE' | 'PAUSED' | 'GAP'
  ): WeatherStageType {
    this.resolveStageCalls += 1;
    return this.nextStage;
  }

  public resolveSchedulePolicy(stage: WeatherStageType): WeatherSchedulePolicy {
    this.resolveScheduleCalls += 1;
    const policy: WeatherSchedulePolicy = {
      stage,
      pollIntervalMs: stage === 'PLANNING' ? 0 : 12345,
      allowLocationTrigger: stage !== 'PLANNING',
      allowManualBypass: true,
      forceRefreshOnEnter: stage !== 'PAUSED'
    };
    return policy;
  }
}

export default function weatherFacadeTest() {
  describe('weatherFacadeTest', () => {
    it('normal: weather_facade_should_route_calls_to_domain_service', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const mock = new MockWeatherDomainService();
      const facade = new WeatherFacade(mock);
      const events: EventEntity[] = [];
      await facade.buildPlanningContext(events);
      await facade.buildExecutionContext(events);
      facade.buildExecutionAdjustments(1, {
        stage: 'IN_PROGRESS',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 100, riskTags: [], summaryText: '' }
      }, []);
      expect(mock.planningCalls).assertEqual(1);
      expect(mock.executionCalls).assertEqual(1);
      expect(mock.adjustCalls).assertEqual(1);
      done();
    });
  });
  describe('unit_test_case_generator_autofill_WeatherFacade', () => {
    it('boundary: weather_facade_should_return_zero_poll_policy_for_planning_stage', 0, () => {
      // Arrange
      const facade = new WeatherFacade();

      // Act
      const policy = facade.resolveSchedulePolicy('PLANNING');

      // Assert
      expect(policy.stage).assertEqual('PLANNING');
      expect(policy.pollIntervalMs).assertEqual(0);
      expect(policy.allowLocationTrigger).assertFalse();
    });

    it('invalid: weather_facade_should_forward_force_refresh_and_empty_events_to_execution_builder', 0, async (done: () => void) => {
      // Arrange
      let capturedForceRefresh = false;
      let capturedEventCount = -1;
      class InvalidExecutionWeatherDomainService extends MockWeatherDomainService {
        public async buildExecutionContext(
          events: EventEntity[],
          _currentLocation?: GeoPointInput,
          forceRefresh: boolean = false,
          _preference?: WeatherUserPreference,
          _options?: WeatherCollabOptions,
          _stage?: WeatherStageType
        ): Promise<WeatherContextBuildResult> {
          this.executionCalls += 1;
          capturedForceRefresh = forceRefresh;
          capturedEventCount = events.length;
          const map = new Map<number, PlanNodeWeatherBinding>();
          return {
            context: {
              stage: 'IN_PROGRESS',
              generatedAt: 1,
              bindings: [],
              routeSuitability: { routeScore: 0, riskTags: ['EMPTY'], summaryText: 'empty' }
            },
            eventMap: map,
            sourceEvents: []
          };
        }
      }
      const facade = new WeatherFacade(new InvalidExecutionWeatherDomainService());

      // Act
      const result = await facade.buildExecutionContext([], undefined, true);

      // Assert
      expect(result.context.routeSuitability.routeScore).assertEqual(0);
      expect(capturedForceRefresh).assertTrue();
      expect(capturedEventCount).assertEqual(0);
      done();
    });

    it('conflict: weather_facade_should_use_injected_stage_coordinator_instead_of_default_policy', 0, () => {
      // Arrange
      const stageCoordinator = new MockWeatherStageCoordinator();
      stageCoordinator.nextStage = 'PAUSED';
      const facade = new WeatherFacade(undefined, stageCoordinator);

      // Act
      const stage = facade.resolveStage(PlanStatus.READY, [], 'ACTIVE');
      const policy = facade.resolveSchedulePolicy(stage);

      // Assert
      expect(stage).assertEqual('PAUSED');
      expect(policy.stage).assertEqual('PAUSED');
      expect(policy.forceRefreshOnEnter).assertFalse();
      expect(stageCoordinator.resolveStageCalls).assertEqual(1);
      expect(stageCoordinator.resolveScheduleCalls).assertEqual(1);
    });

    it('regression: weather_facade_should_delegate_prompt_summary_to_domain_service', 0, () => {
      // Arrange
      const mock = new MockWeatherDomainService();
      const facade = new WeatherFacade(mock);
      const context: WeatherContext = {
        stage: 'CONFIRMED',
        generatedAt: 123,
        bindings: [],
        routeSuitability: { routeScore: 80, riskTags: [], summaryText: 'ok' }
      };

      // Act
      const summary = facade.buildPromptSummary(context);

      // Assert
      expect(summary).assertEqual('prompt_summary');
      expect(mock.promptCalls).assertEqual(1);
    });

    it('combined: weather_facade_should_coordinate_stage_policy_and_domain_calls_across_planning_and_execution', 0, async (done: () => void) => {
      // Arrange
      const mockDomain = new MockWeatherDomainService();
      const mockStage = new MockWeatherStageCoordinator();
      mockStage.nextStage = 'READY';
      const facade = new WeatherFacade(mockDomain, mockStage);
      const events: EventEntity[] = [];

      // Act
      const stage = facade.resolveStage(PlanStatus.CONFIRMED, events, 'READY');
      const policy = facade.resolveSchedulePolicy(stage);
      await facade.buildPlanningContext(events, undefined, undefined, stage);
      await facade.buildExecutionContext(events, undefined, policy.forceRefreshOnEnter, undefined, undefined, stage);
      const suggestions = facade.buildExecutionAdjustments(9, {
        stage,
        generatedAt: 2,
        bindings: [],
        routeSuitability: { routeScore: 77, riskTags: ['RAIN'], summaryText: 'rain' }
      }, []);

      // Assert
      expect(stage).assertEqual('READY');
      expect(policy.allowLocationTrigger).assertTrue();
      expect(mockDomain.planningCalls).assertEqual(1);
      expect(mockDomain.executionCalls).assertEqual(1);
      expect(mockDomain.adjustCalls).assertEqual(1);
      expect(suggestions.length).assertEqual(0);
      done();
    });
  });
}
