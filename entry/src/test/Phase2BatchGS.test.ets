import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import {
  PlanNodeWeatherBinding,
  WeatherContext,
  WeatherSnapshot,
  WeatherSuggestion
} from '../main/ets/domain/services/WeatherModels';

interface WeatherContextBuilderPrivateGS {
  buildReplacementCandidates(targets: PlanNodeWeatherBinding[]): Object[];
}

function createEventGS(id: number, name: string, duration: number = 60): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = name;
  event.duration = duration;
  event.status = 1;
  event.type = 1;
  event.sort_order = id;
  return event;
}

function createBindingGS(event: EventEntity, score: number): PlanNodeWeatherBinding {
  const weather: WeatherSnapshot = {
    locationKey: `gs_${event.id}`,
    sourceType: 'PLAN_LOCATION',
    weatherTime: 1,
    fetchTime: 1,
    conditionCode: 'CLEAR',
    conditionText: '晴',
    temperatureCelsius: 24
  };
  return {
    nodeId: `${event.id}`,
    eventId: event.id,
    nodeName: event.name,
    weather: weather,
    suitabilityScore: score,
    riskTags: []
  };
}

function createFallbackSuggestionGS(id: string, nodeId: string): WeatherSuggestion {
  return {
    suggestionId: id,
    level: 'INFO',
    triggerType: 'UNKNOWN',
    actionType: 'PREPARE',
    title: 'fallback',
    message: 'fallback_message',
    relatedNodeIds: [nodeId],
    createdAt: 1,
    reason: 'fallback_reason',
    expectedBenefit: 'fallback_benefit',
    canRollback: true,
    cooldownKey: `cooldown_${id}`,
    expiresAt: 2
  };
}

function createExecutionContextGS(): WeatherContext {
  return {
    stage: 'IN_PROGRESS',
    generatedAt: 1700000000123,
    bindings: [],
    routeSuitability: {
      routeScore: 88,
      riskTags: [],
      summaryText: 'route_ok'
    },
    executionRiskScore: 88,
    executionRiskTags: [],
    futureNodeWeatherList: []
  };
}

export default function phase2BatchGSTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGS_weather_context_builder_function', () => {
    it('combined: weather_context_builder_should_cover_execution_fallback_foreach_append', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder();
      const event = createEventGS(701, 'museum');
      const context = createExecutionContextGS();
      Reflect.set(builder as Object, 'buildExecutionSuggestions', (): WeatherSuggestion[] => {
        return [
          createFallbackSuggestionGS('fallback_primary', `${event.id}`),
          createFallbackSuggestionGS('fallback_duplicate', `${event.id}`)
        ];
      });

      // Act
      const suggestions = builder.buildExecutionAdjustments(701, context, [event]);

      // Assert
      expect(suggestions.length).assertEqual(1);
      expect(suggestions[0].actionType).assertEqual('PREPARE');
      expect((suggestions[0].relatedNodeIds ?? [])[0]).assertEqual(`${event.id}`);
    });

    it('combined: weather_context_builder_should_cover_replacement_candidate_sort_desc', 0, () => {
      // Arrange
      const builder = new WeatherContextBuilder() as Object as WeatherContextBuilderPrivateGS;
      const first = createBindingGS(createEventGS(711, 'low_score'), 52);
      const second = createBindingGS(createEventGS(712, 'best_score'), 93);
      const third = createBindingGS(createEventGS(713, 'mid_score'), 78);

      // Act
      const candidates = builder.buildReplacementCandidates([first, second, third]) as Record<string, Object>[];

      // Assert
      expect(candidates.length).assertEqual(2);
      expect(candidates[0].eventId as number).assertEqual(712);
      expect(candidates[1].eventId as number).assertEqual(713);
    });
  });
}
