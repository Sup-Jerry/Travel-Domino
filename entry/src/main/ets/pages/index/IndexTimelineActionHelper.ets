import { hilog } from '@kit.PerformanceAnalysisKit';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { EventEntity } from '../../model/entity/EventEntity';
import { InitDialogData } from './IndexTypes';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export class IndexTimelineActionHelper {
  static handleMoveToBacklog(vm: TimelineViewModel, item: EventEntity, onToast: (message: string) => void): void {
    if (item.status !== 1) {
      onToast('该地点不在日程表中');
      return;
    }
    void vm.moveToBacklog(item);
  }

  static confirmDeleteTimelineEvent(uiContext: UIContext, vm: TimelineViewModel, item: EventEntity): void {
    uiContext.showAlertDialog({
      title: '确认删除',
      message: `确定要删除 "${item.name}" 吗？\n删除后无法恢复。`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.White,
        backgroundColor: '#2F7DFF',
        action: () => {
          vm.hardDelete(item);
        }
      }
    });
  }

  static buildEditDialogData(item: EventEntity): InitDialogData {
    const coordValid = Number.isFinite(item.latitude) && Number.isFinite(item.longitude) &&
      Math.abs(item.latitude) <= 90 && Math.abs(item.longitude) <= 180 &&
      !(item.latitude === 0 && item.longitude === 0);
    hilog.info(
      0x0000,
      'Index',
      `[MAP_TRACE][edit_entry] itemId=${item.id}, source=${item.source}, nameLen=${(item.name || '').length}, coordValid=${coordValid}, lat=${item.latitude}, lng=${item.longitude}`
    );
    const effectiveDayOffset = TimelineDatePolicy.resolveEventDayOffset(item);
    return {
      name: item.name,
      note: item.note,
      duration: item.duration,
      isAnchor: item.lock_status === 1,
      fixedTime: item.fixed_start_time || '',
      dayOffset: effectiveDayOffset || 0,
      lat: item.latitude,
      lng: item.longitude
    };
  }
}
