import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { WeatherUserPreference } from '../../domain/services/WeatherModels';
import { PlanImportExportService } from '../../infrastructure/services/PlanImportExportService';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexDialogManager } from './IndexDialogManager';

export interface OpenSettingsFlowParams {
  uiContext: UIContext;
  vm: TimelineViewModel;
  onRename: () => void;
  onReschedule: (dateMs: number) => void;
  onShare: () => Promise<void>;
  onWeatherPreferenceError: () => void;
}

export interface OpenShareFlowParams {
  planId: number;
  planTitle: string;
  planStartDate: number;
  events: EventEntity[];
}

export class IndexSettingsFlowHelper {
  static openSettingsDialog(params: OpenSettingsFlowParams): CustomDialogController {
    const controller = IndexDialogManager.createSettingsController({
      onRename: () => {
        setTimeout((): void => params.onRename(), 100);
      },
      onReschedule: () => {
        setTimeout(() => {
          IndexDialogManager.openPlanDatePicker(
            params.uiContext,
            params.vm.planStartDate,
            (dateMs: number) => params.onReschedule(dateMs)
          );
        }, 100);
      },
      onShare: () => {
        setTimeout((): void => {
          void params.onShare();
        }, 100);
      },
      weatherUserPreference: params.vm.getWeatherUserPreference(),
      onWeatherPreferenceChange: async (preference: WeatherUserPreference) => {
        try {
          await params.vm.updateWeatherUserPreference(preference);
          if (params.vm.isWeatherFeatureEnabled()) {
            void params.vm.refreshPlanningWeather(false);
          }
          if (params.vm.isWeatherFeatureEnabled() && params.vm.isExecutionWeatherStage()) {
            void params.vm.refreshExecutionWeather(false, 'MANUAL');
          }
        } catch (_error) {
          params.onWeatherPreferenceError();
        }
      }
    });
    controller.open();
    return controller;
  }

  static openRenameDialog(planTitle: string, onConfirm: (newName: string) => void): CustomDialogController {
    const controller = IndexDialogManager.createRenameController(planTitle, (newName: string) => {
      onConfirm(newName);
    });
    controller.open();
    return controller;
  }

  static async openShareDialog(params: OpenShareFlowParams): Promise<CustomDialogController | null> {
    if (params.planId <= 0) {
      return null;
    }
    const compressedJson = await PlanImportExportService.exportPlanToJson(params.planId);
    const scheduleEvents = params.events.filter((item: EventEntity) => item.status === 1);
    const totalEvents = scheduleEvents.length;
    const dayOffsets = scheduleEvents.map((item: EventEntity) => TimelineDatePolicy.resolveEventDayOffset(item));
    const maxDayOffset = dayOffsets.length > 0 ? Math.max(...dayOffsets) : 0;
    const startDate = params.planStartDate > 0 ? params.planStartDate : Date.now();
    const endDate = TimelineDatePolicy.dayOffsetToDayStartMs(startDate, maxDayOffset);
    const totalDays = Math.max(1, maxDayOffset + 1);
    const controller = IndexDialogManager.createShareController({
      planId: params.planId,
      planTitle: params.planTitle,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      totalEvents: totalEvents,
      compressedJson: compressedJson
    });
    controller.open();
    return controller;
  }
}
