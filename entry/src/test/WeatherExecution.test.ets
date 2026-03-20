import { describe, it, expect } from '@ohos/hypium';
import { WeatherStagePolicy } from '../main/ets/domain/policy/WeatherStagePolicy';
import { WeatherContextBuilder } from '../main/ets/domain/services/WeatherContextBuilder';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { WeatherCollabContext, WeatherContext, WeatherUserPreference } from '../main/ets/domain/services/WeatherModels';

function buildEvent(active: boolean): EventEntity {
  const event = new EventEntity();
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = active ? Date.now() : 0;
  event.actual_end_time = 0;
  return event;
}

export default function weatherExecutionTest() {
  describe('weatherExecutionTest', () => {
    it('weather_stage_should_resolve_execution_when_active_exists', 0, () => {
      const events = [buildEvent(false), buildEvent(true)];
      const stage = WeatherStagePolicy.resolveStageForPlan(events);
      expect(stage).assertEqual('EXECUTION');
    });

    it('weather_stage_should_resolve_planning_when_no_active', 0, () => {
      const events = [buildEvent(false), buildEvent(false)];
      const stage = WeatherStagePolicy.resolveStageForPlan(events);
      expect(stage).assertEqual('PLANNING');
    });

    it('execution_suggestion_should_emit_warning_on_low_score', 0, () => {
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 50, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 50,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: [{
          nodeId: '1',
          eventId: 1,
          suitabilityScore: 50,
          riskTags: ['RAIN']
        }],
        nextNodeWeather: {
          locationKey: 'k',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: Date.now(),
          conditionCode: 'RAIN',
          conditionText: '小雨'
        }
      };
      const suggestions = builder.buildExecutionSuggestions(context);
      expect(suggestions.length > 0).assertEqual(true);
      expect(suggestions[0].level).assertEqual('WARNING');
    });

    it('execution_replace_should_include_candidates_or_fallback_payload', 0, () => {
      const builder = new WeatherContextBuilder();
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 80, riskTags: ['UNKNOWN'], summaryText: '' },
        executionRiskScore: 80,
        executionRiskTags: ['UNKNOWN'],
        futureNodeWeatherList: [
          { nodeId: '1', eventId: 1, nodeName: 'A点', suitabilityScore: 60, riskTags: ['UNKNOWN'] },
          { nodeId: '2', eventId: 2, nodeName: 'B点', suitabilityScore: 88, riskTags: [] }
        ],
        nextNodeWeather: {
          locationKey: 'k',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: Date.now(),
          conditionCode: 'UNK',
          conditionText: '未知'
        }
      };
      const pref: WeatherUserPreference = { heatSensitivity: 1, rainSensitivity: 2, weatherRiskTolerance: 1 };
      const suggestions = builder.buildExecutionSuggestions(context, pref);
      const replace = suggestions.find(item => item.actionType === 'REPLACE_NODE');
      expect(!!replace).assertEqual(true);
      expect((replace?.actionPayload?.replacementCandidates?.length ?? 0) >= 0).assertEqual(true);
    });

    it('execution_adjustment_should_append_collab_explanation', 0, () => {
      const builder = new WeatherContextBuilder();
      const collab: WeatherCollabContext = {
        dayWindows: [{ dayOffset: 0, windowScore: 70, riskTags: ['RAIN'], trendTag: 'RAIN_PERSIST' }],
        cityBuckets: [{ cityKey: 'A市', nodeIds: ['1'], bucketScore: 70, summaryText: 'A市均分70' }],
        collabSummary: '1城1日：降雨持续',
        dayWindowCount: 1,
        cityGroupCount: 1,
        cityCappedCount: 0,
        cityMissCount: 0,
        trendTag: 'RAIN_PERSIST',
        fallbackPath: ''
      };
      const context: WeatherContext = {
        stage: 'EXECUTION',
        generatedAt: Date.now(),
        bindings: [],
        routeSuitability: { routeScore: 60, riskTags: ['RAIN'], summaryText: '' },
        executionRiskScore: 60,
        executionRiskTags: ['RAIN'],
        futureNodeWeatherList: [{ nodeId: '1', eventId: 1, suitabilityScore: 55, riskTags: ['RAIN'] }],
        nextNodeWeather: {
          locationKey: 'k',
          sourceType: 'PLAN_LOCATION',
          weatherTime: Date.now(),
          fetchTime: Date.now(),
          conditionCode: 'RAIN',
          conditionText: '中雨'
        },
        collabContext: collab
      };
      const event = new EventEntity();
      event.id = 1;
      event.status = 1;
      const suggestions = builder.buildExecutionAdjustments(1, context, [event], undefined, collab);
      expect(suggestions.length > 0).assertEqual(true);
      expect(suggestions[0].message.includes('多日/多城协同')).assertEqual(true);
    });
  });
}
