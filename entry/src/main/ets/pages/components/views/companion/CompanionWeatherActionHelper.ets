import { hilog } from '@kit.PerformanceAnalysisKit';
import { TimelineViewModel } from '../../../../viewmodel/TimelineViewModel';
import { WeatherSuggestion } from '../../../../domain/services/WeatherModels';
import {
  buildCompanionExecutionSuggestionExplanation,
  buildCompanionReplanToastMessage
} from './CompanionDisplayHelper';

export type CompanionWeatherSuggestionDismissMode = 'later' | 'ignore';

export function getCompanionWeatherGuidePopupText(): string {
  return '调整建议（用途）\n在天气不利时，尽量保持计划可执行并降低中断概率。\n可做动作\n重排顺序、缩短停留、跳过高风险点、替代节点。\n按钮说明\n可选应用=立即尝试调整；稍后=先不处理，下次可再看；忽略=移除该建议。\n仅作为建议，不会自动改行程。';
}

export function getCompanionWeatherSuggestionDetailText(item: WeatherSuggestion): string {
  return buildCompanionExecutionSuggestionExplanation(item);
}

export function getCompanionDismissSuggestionToast(mode: CompanionWeatherSuggestionDismissMode): string {
  return mode === 'later' ? '已暂不处理该建议' : '已忽略该可选建议';
}

interface CompanionApplyWeatherSuggestionParams {
  vm: TimelineViewModel;
  item: WeatherSuggestion;
  showToast: (message: string) => void;
  showApplyConfirm: (title: string, message: string, onConfirm: () => void) => void;
}

export function applyCompanionWeatherSuggestion(params: CompanionApplyWeatherSuggestionParams): void {
  const vm = params.vm;
  const item = params.item;
  const showToast = params.showToast;
  const showApplyConfirm = params.showApplyConfirm;
  hilog.info(
    0x0000,
    'CompanionView',
    `[WEATHER_REPLAN][ui_apply_click] planId=${vm.planId}, suggestionId=${item.suggestionId}, actionType=${item.actionType}, applying=${vm.executionWeatherApplying ? 1 : 0}`
  );
  if (vm.executionWeatherApplying) {
    hilog.warn(
      0x0000,
      'CompanionView',
      `[WEATHER_REPLAN][ui_apply_blocked] reason=applying_busy, suggestionId=${item.suggestionId}`
    );
    showToast('正在应用建议，请稍候');
    return;
  }

  showApplyConfirm(
    '确认应用可选建议',
    `建议：${item.title}\n动作：${item.actionType}\n\n应用后将尝试调整后续行程。`,
    () => {
      void vm.requestSoftReplan(vm.planId, item.suggestionId, 'APPLY').then((result) => {
        hilog.info(
          0x0000,
          'CompanionView',
          `[WEATHER_REPLAN][ui_apply_result] planId=${vm.planId}, suggestionId=${item.suggestionId}, actionType=${item.actionType}, success=${result.success ? 1 : 0}, errorCode=${result.errorCode || 'NONE'}, reasonCode=${result.reasonCode ?? ''}, startFromEventId=${result.startFromEventId ?? 0}, rolledBack=${result.rolledBack ? 1 : 0}`
        );
        if (!result.success) {
          hilog.warn(
            0x0000,
            'CompanionView',
            `[WEATHER_REPLAN][ui_apply_fail] planId=${vm.planId}, suggestionId=${item.suggestionId}, actionType=${item.actionType}, errorCode=${result.errorCode}, reasonCode=${result.reasonCode ?? ''}, startFromEventId=${result.startFromEventId ?? 0}, rolledBack=${result.rolledBack ? 1 : 0}`
          );
        }
        showToast(buildCompanionReplanToastMessage(result));
      }).catch((error: Object) => {
        hilog.error(
          0x0000,
          'CompanionView',
          `[WEATHER_REPLAN][ui_apply_exception] planId=${vm.planId}, suggestionId=${item.suggestionId}, actionType=${item.actionType}, reason=${JSON.stringify(error)}`
        );
        showToast('可选建议应用失败：执行异常');
      });
    }
  );
}
