import { StrategyService } from '../../domain/strategy/StrategyService';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { WeatherReminderPayload } from '../../common/utils/weather/WeatherReminderStore';
import { ArrivalReminderPayload } from '../../infrastructure/services/ArrivalReminderEngine';
import { WeatherReminderCoordinator } from '../../infrastructure/services/WeatherReminderCoordinator';
import { ArrivalReminderCoordinator } from '../../infrastructure/services/ArrivalReminderCoordinator';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface ReminderDialogContext {
  vm: TimelineViewModel;
  currentPlanId: number;
  getUIContext: () => UIContext;
  weatherCoordinator: WeatherReminderCoordinator;
  arrivalCoordinator: ArrivalReminderCoordinator;
  tryStartEventWithConflictPrompt: (eventId: number) => Promise<boolean>;
  setWeatherDialogOpen: (value: boolean) => void;
  setArrivalDialogOpen: (value: boolean) => void;
  setCompanionMode: (value: boolean) => void;
  safeShowToast: (message: string) => void;
}

export interface StrategyDialogContext {
  vm: TimelineViewModel;
  strategyMode: number;
  getUIContext: () => UIContext;
  regenerateByCurrentStrategy: () => Promise<void>;
}

export class IndexPageBehaviorHelper {
  static showWeatherReminderDialog(context: ReminderDialogContext, payload: WeatherReminderPayload): void {
    context.setWeatherDialogOpen(true);
    const dialogTitle = payload.suggestionId ? `天气建议（可选）· ${payload.title}` : `天气提醒（可选）· ${payload.title}`;
    const affectedText = payload.affectedNodes && payload.affectedNodes.length > 0
      ? `\n受影响节点：${payload.affectedNodes.join('、')}`
      : '';
    const reasonText = payload.reason ? `\n原因：${payload.reason}` : '';
    const benefitText = payload.expectedBenefit ? `\n收益：${payload.expectedBenefit}` : '';
    const durationText = Number.isFinite(payload.suggestedDurationMin)
      ? `\n建议停留：约 ${payload.suggestedDurationMin} 分钟`
      : '';
    const strategyAdjustText = payload.strategyAdjustment
      ? `\n策略调整预览：密度${payload.strategyAdjustment.density ?? 0}，节奏${payload.strategyAdjustment.pace ?? 0}，体力${payload.strategyAdjustment.energy ?? 0}`
      : '';
    const dialogMessage = payload.suggestionId
      ? `${payload.message}${reasonText}${benefitText}${affectedText}${durationText}${payload.strategyHint ? `\n策略建议：${payload.strategyHint}` : ''}${strategyAdjustText}\n\n此建议基于多日/多城天气协同，属可选动作，不会自动执行。`
      : `${payload.message}\n\n你可以选择刷新天气，不影响主流程。`;

    context.getUIContext().showAlertDialog({
      title: dialogTitle,
      message: dialogMessage,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: payload.suggestionId ? '稍后处理' : '知道了',
        action: () => {
          context.setWeatherDialogOpen(false);
          context.weatherCoordinator.clear(context.currentPlanId);
        }
      },
      secondaryButton: {
        value: payload.suggestionId ? '去伴游' : '刷新天气',
        action: () => {
          context.setWeatherDialogOpen(false);
          context.weatherCoordinator.clear(context.currentPlanId);
          if (payload.suggestionId) {
            hilog.info(
              0x0000,
              'Index',
              `[WEATHER_REPLAN][dialog_view_only] planId=${context.currentPlanId}, suggestionId=${payload.suggestionId}, actionType=${payload.actionType ?? 'NONE'}`
            );
            context.setCompanionMode(true);
            context.safeShowToast('已进入伴游，请先查看建议，确认后再应用');
          } else {
            void context.vm.refreshExecutionWeather(true, 'MANUAL');
          }
        }
      }
    });
  }

  static showArrivalReminderDialog(context: ReminderDialogContext, payload: ArrivalReminderPayload): void {
    context.setArrivalDialogOpen(true);
    context.getUIContext().showAlertDialog({
      title: '到达提醒',
      message: `你已到达【${payload.placeName}】附近（约${Math.max(1, payload.distanceMeters)}米）`,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '稍后',
        action: () => {
          context.setArrivalDialogOpen(false);
          context.arrivalCoordinator.acknowledge(payload.eventId, 'dismiss');
        }
      },
      secondaryButton: {
        value: '开始打卡',
        action: () => {
          context.setArrivalDialogOpen(false);
          void context.tryStartEventWithConflictPrompt(payload.eventId).then((started: boolean) => {
            context.arrivalCoordinator.acknowledge(payload.eventId, started ? 'start' : 'dismiss');
          }).catch(() => {
            context.arrivalCoordinator.acknowledge(payload.eventId, 'dismiss');
          });
        }
      }
    });
  }

  static loadStrategyExplanation(strategyMode: number): string {
    return StrategyService.buildStrategyExplanation(strategyMode);
  }

  static startStrategyAdaptationCheck(context: StrategyDialogContext): number {
    return setInterval(() => {
      if (context.vm.strategyAdaptationPrompt) {
        IndexPageBehaviorHelper.showStrategyAdaptationDialog(context);
      }
    }, 1000);
  }

  static showStrategyAdaptationDialog(context: StrategyDialogContext): void {
    const prompt = context.vm.strategyAdaptationPrompt;
    if (!prompt) {
      return;
    }

    context.vm.strategyAdaptationPrompt = null;

    const strategyLabels = ['低', '中', '高'];
    const message = `${prompt.message}\n\n` +
      `密度：${strategyLabels[prompt.oldStrategy.density]} → ${strategyLabels[prompt.newStrategy.density]}\n` +
      `节奏：${strategyLabels[prompt.oldStrategy.pace]} → ${strategyLabels[prompt.newStrategy.pace]}\n` +
      `体力：${strategyLabels[prompt.oldStrategy.energy]} → ${strategyLabels[prompt.newStrategy.energy]}`;

    context.getUIContext().showAlertDialog({
      title: '✨ 策略已自动调整',
      message: message,
      autoCancel: false,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '立即生成',
        action: () => {
          void context.regenerateByCurrentStrategy();
        }
      },
      secondaryButton: {
        value: '稍后',
        action: () => {}
      }
    });
  }
}
