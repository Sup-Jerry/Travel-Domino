import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { EventEntity } from '../../model/entity/EventEntity';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { InitDialogData } from './IndexTypes';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { IndexDialogManager } from './IndexDialogManager';
import { WeatherUserPreference } from '../../domain/services/WeatherModels';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { IndexAddDialogHelper } from './IndexAddDialogHelper';

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

export interface MoveToScheduleContext {
  vm: TimelineViewModel;
  setEditingItemId: (id: number) => void;
  openDialog: (initData?: InitDialogData) => void;
}

export interface MoveToScheduleItem {
  id?: number;
  name: string;
  note?: string;
  duration?: number;
}

export interface BacklogActionContext {
  vm: TimelineViewModel;
  safeShowToast: (message: string) => void;
  getUIContext: () => UIContext;
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

  static moveItemToSchedule(context: MoveToScheduleContext, item: MoveToScheduleItem): void {
    const suggestedDay = IndexPageActionsHelper.findLeastBusyDay(context.vm);
    const smartTime = IndexAddDialogHelper.calculateSmartTime(context.vm.events, item.id ?? -1);
    context.setEditingItemId(item.id ?? -1);
    context.openDialog({
      name: item.name,
      note: item.note ?? '',
      duration: item.duration ?? 60,
      isAnchor: false,
      fixedTime: smartTime,
      dayOffset: suggestedDay,
      isSchedule: true
    });
  }
  static moveTravelPlanItemToSchedule(context: MoveToScheduleContext, item: TravelPlanItem): void {
    IndexPageActionsHelper.moveItemToSchedule(context, {
      id: item.id,
      name: item.name,
      note: item.note,
      duration: item.duration
    });
  }
  static handleMoveAllToSchedule(context: BacklogActionContext): void {
    const movedCount = context.vm.moveAllBacklogToSchedule();
    if (movedCount > 0) {
      context.safeShowToast(`已加入日程 ${movedCount} 个地点`);
      return;
    }
    context.safeShowToast('暂存池暂无可加入地点');
  }

  static handleConfirmMoveToBacklog(context: BacklogActionContext, item: EventEntity): void {
    if (item.status !== 1) {
      context.safeShowToast('该地点不在日程表中');
      return;
    }
    void context.vm.moveToBacklog(item).then((): void => {
      context.vm.refreshTimelineView();
    }).catch((_error: Object): void => {
      context.safeShowToast('暂存失败，请重试');
    });
  }

  static handleConfirmDeleteEvent(context: BacklogActionContext, item: EventEntity): void {
    context.getUIContext().showAlertDialog({
      title: '确认删除',
      message: `确定要删除 "${item.name}" 吗？\n删除后无法恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.White,
        backgroundColor: '#2F7DFF',
        action: (): void => {
          void context.vm.hardDelete(item).then((): void => {
            context.vm.refreshTimelineView();
          }).catch((_error: Object): void => {
            context.safeShowToast('删除失败，请重试');
          });
        }
      }
    });
  }
}

