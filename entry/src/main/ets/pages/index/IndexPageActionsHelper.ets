import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { EventEntity } from '../../model/entity/EventEntity';
import { InitDialogData } from './IndexTypes';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { IndexDialogManager } from './IndexDialogManager';
import { WeatherUserPreference } from '../../domain/services/WeatherModels';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface EditDialogPrepared {
  editingItemId: number;
  initData: InitDialogData;
}

export interface DateFilterActionContext {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
}

export interface DatePickerActionContext {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  requestPlanDateUpdate: (dateMs: number) => void;
}

export interface RenameActionContext {
  vm: TimelineViewModel;
  planTitle: string;
  setPlanTitle: (title: string) => void;
}

export interface SettingsActionContext {
  vm: TimelineViewModel;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  openRenameDialog: () => void;
  openDatePicker: () => void;
}

export class IndexPageActionsHelper {
  static findLeastBusyDay(vm: TimelineViewModel): number {
    if (vm.groupedEvents.length === 0) {
      return 0;
    }

    let minDay = 0;
    let minCount = Number.MAX_SAFE_INTEGER;

    vm.groupedEvents.forEach(group => {
      if (group.events.length > 0 && group.events.length < minCount) {
        minCount = group.events.length;
        minDay = group.dayOffset;
      }
    });
    return minDay;
  }

  static prepareEditDialog(item: EventEntity): EditDialogPrepared {
    const coordValid = Number.isFinite(item.latitude) && Number.isFinite(item.longitude) &&
      Math.abs(item.latitude) <= 90 && Math.abs(item.longitude) <= 180 &&
      !(item.latitude === 0 && item.longitude === 0);
    hilog.info(
      0x0000,
      'Index',
      `[MAP_TRACE][edit_entry] itemId=${item.id}, source=${item.source}, nameLen=${(item.name || '').length}, coordValid=${coordValid}, lat=${item.latitude}, lng=${item.longitude}`
    );

    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    const initData: InitDialogData = {
      name: item.name,
      note: item.note,
      duration: item.duration,
      isAnchor: item.lock_status === 1,
      fixedTime: item.fixed_start_time || '',
      dayOffset: effectiveDayOffset || 0,
      lat: item.latitude,
      lng: item.longitude
    };

    return {
      editingItemId: item.id,
      initData: initData
    };
  }

  static openDateFilterDialog(context: DateFilterActionContext): CustomDialogController {
    return IndexDialogManager.openDateFilterDialog(
      context.getUIContext(),
      context.vm.planStartDate,
      {
        onShowAll: (): void => {
          context.vm.clearFilter();
        },
        onSelectDate: (dateMs: number): void => {
          context.vm.setFilter(dateMs, dateMs);
        },
        onSelectRange: (startMs: number, endMs: number): void => {
          context.vm.setFilter(startMs, endMs);
        }
      }
    );
  }

  static openDatePicker(context: DatePickerActionContext): void {
    IndexDialogManager.openPlanDatePicker(context.getUIContext(), context.vm.planStartDate, (dateMs: number): void => {
      context.requestPlanDateUpdate(dateMs);
    });
  }

  static openRenameDialog(context: RenameActionContext): CustomDialogController {
    return IndexDialogManager.createRenameController(context.planTitle, (newName: string): void => {
      context.setPlanTitle(newName);
      context.vm.renamePlan(newName);
    });
  }

  static openSettingsDialog(context: SettingsActionContext): CustomDialogController {
    return IndexDialogManager.createSettingsController({
      onRename: (): void => {
        setTimeout((): void => context.openRenameDialog(), 100);
      },
      onReschedule: (): void => {
        setTimeout((): void => context.openDatePicker(), 100);
      },
      onShare: (): void => {
        context.safeShowToast('分享功能暂不可用');
      },
      weatherUserPreference: context.vm.getWeatherUserPreference(),
      onWeatherPreferenceChange: async (preference: WeatherUserPreference): Promise<void> => {
        try {
          await context.vm.updateWeatherUserPreference(preference);
          if (context.vm.isWeatherFeatureEnabled()) {
            void context.vm.refreshPlanningWeather(false);
          }
          if (context.vm.isWeatherFeatureEnabled() && context.vm.isExecutionWeatherStage()) {
            void context.vm.refreshExecutionWeather(false, 'MANUAL');
          }
        } catch (_error) {
          context.safeShowToast('天气偏好保存失败');
        }
      }
    });
  }
}
