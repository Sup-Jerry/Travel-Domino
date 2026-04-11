import { describe, it, expect } from '@ohos/hypium';
import {
  ExecutionSuggestionApplyResult,
  TimelineViewModel
} from '../main/ets/viewmodel/TimelineViewModel';
import { WeatherStrategyAdjustment } from '../main/ets/common/utils/weather/WeatherReminderStore';
import { SoftReplanApplyResult } from '../main/ets/domain/services/WeatherModels';
type ReplanErrorCode = '' | 'REPLAN_CONFLICT' | 'REPLAN_IMMUTABLE' | 'REPLAN_NO_CANDIDATE' | 'REPLAN_TIMEOUT' | 'REPLAN_INVALID' | 'REPLAN_BUSY';

interface TimelineWeatherInternal {
  buildWeatherStrategyAdaptationKey: (generatedAt: number, routeScore: number) => string;
  composeWeatherConstraintPrompt: (weatherAwareConstraint: string, weatherSummary: string) => string;
  applyWeatherStrategyAdjustment: (adjustment?: WeatherStrategyAdjustment, hint?: string) => Promise<boolean>;
  requestSoftReplan: (planId: number, suggestionId: string, mode: 'PREVIEW' | 'APPLY') => Promise<SoftReplanApplyResult>;
}

function buildReplanResult(success: boolean, errorCode: ReplanErrorCode): SoftReplanApplyResult {
  return {
    success: success,
    rolledBack: false,
    errorCode: errorCode,
    preview: {
      suggestionId: 's1',
      actionType: 'NONE',
      changedOrder: false,
      changedDurations: false,
      skippedNodeIds: [],
      affectedNodeIds: [],
      changeSummary: [],
      summary: success ? 'ok' : 'fail',
      riskDelta: 0
    }
  };
}

export default function timelineWeatherLinkageIntegrationTest() {
  describe('timelineWeatherLinkageIntegrationTest', () => {
    it('normal: weather_strategy_adaptation_key_should_use_timestamp_and_score', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const internal = vm as Object as TimelineWeatherInternal;
      const key = internal.buildWeatherStrategyAdaptationKey(1710900000000, 72);
      expect(key).assertEqual('1710900000000_72');
    });

    it('combined: weather_prompt_should_include_joint_constraint_header', 0, () => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const internal = vm as Object as TimelineWeatherInternal;
      const prompt = internal.composeWeatherConstraintPrompt('联合约束文本', '天气摘要文本');
      expect(prompt.includes('策略天气联合约束')).assertEqual(true);
      expect(prompt.includes('联合约束文本')).assertEqual(true);
      expect(prompt.includes('天气摘要文本')).assertEqual(true);
    });

    it('invalid: execution_apply_should_return_partial_success_when_strategy_ok_and_replan_fail', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const vm = new TimelineViewModel();
      const internal = vm as Object as TimelineWeatherInternal;
      internal.applyWeatherStrategyAdjustment = async (_adjustment?: WeatherStrategyAdjustment, _hint?: string): Promise<boolean> => true;
      internal.requestSoftReplan = async (_planId: number, _suggestionId: string, _mode: 'PREVIEW' | 'APPLY'): Promise<SoftReplanApplyResult> => {
        return buildReplanResult(false, 'REPLAN_CONFLICT');
      };
      const result: ExecutionSuggestionApplyResult = await vm.applyExecutionSuggestionWithStrategy(
        1,
        's1',
        { density: -1 },
        '测试'
      );
      expect(result.strategyApplied).assertEqual(true);
      expect(result.replanSuccess).assertEqual(false);
      expect(result.errorCode).assertEqual('REPLAN_CONFLICT');
      done();
    });
  });
  describe('unit_test_case_generator_backfill_TimelineWeatherLinkageIntegration', () => {
    it('boundary: execution_apply_should_return_replan_conflict_when_error_code_empty', 0, async (done: () => void) => {
      // Arrange
      const vm = new TimelineViewModel();
      const internal = vm as Object as TimelineWeatherInternal;
      internal.applyWeatherStrategyAdjustment = async (_adjustment?: WeatherStrategyAdjustment, _hint?: string): Promise<boolean> => false;
      internal.requestSoftReplan = async (_planId: number, _suggestionId: string, _mode: 'PREVIEW' | 'APPLY'): Promise<SoftReplanApplyResult> => {
        return buildReplanResult(false, '');
      };
      // Act
      const result = await vm.applyExecutionSuggestionWithStrategy(1, 's1');
      // Assert
      expect(result.strategyApplied).assertEqual(false);
      expect(result.replanSuccess).assertEqual(false);
      expect(result.errorCode).assertEqual('REPLAN_CONFLICT');
      done();
    });

    it('conflict: execution_apply_should_keep_replan_success_false_when_strategy_apply_throws', 0, async (done: () => void) => {
      // Arrange
      const vm = new TimelineViewModel();
      const internal = vm as Object as TimelineWeatherInternal;
      internal.requestSoftReplan = async (_planId: number, _suggestionId: string, _mode: 'PREVIEW' | 'APPLY'): Promise<SoftReplanApplyResult> => {
        return buildReplanResult(false, 'REPLAN_BUSY');
      };
      // Act
      const result = await vm.applyExecutionSuggestionWithStrategy(1, 's1');
      // Assert
      expect(result.strategyApplied).assertEqual(false);
      expect(result.replanSuccess).assertEqual(false);
      expect(result.errorCode).assertEqual('REPLAN_BUSY');
      done();
    });

    it('regression: td-20260411-weather_adaptation_key_should_reflect_score_changes', 0, () => {
      // Arrange
      const vm = new TimelineViewModel();
      const internal = vm as Object as TimelineWeatherInternal;
      // Act
      const keyLow = internal.buildWeatherStrategyAdaptationKey(1710900000000, 60);
      const keyHigh = internal.buildWeatherStrategyAdaptationKey(1710900000000, 90);
      // Assert
      expect(keyLow).assertEqual('1710900000000_60');
      expect(keyHigh).assertEqual('1710900000000_90');
      expect(keyLow === keyHigh).assertEqual(false);
    });
  });
}
