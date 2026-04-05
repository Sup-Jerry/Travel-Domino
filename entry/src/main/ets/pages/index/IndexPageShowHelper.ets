import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppStorageKeys } from '../../common/constants/AppStorageKeys';
import { PageDraftRecovery } from '../../common/utils/PageDraftRecovery';
import { InitDialogData } from './IndexTypes';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export interface IndexPageShowParams {
  vm: TimelineViewModel;
  onStartArrivalReminderEngine: () => void;
  onRefreshUnsavedFlag: () => void;
  onReadDraftStorage: (key: string) => string;
  onClearDraftStorage: () => void;
  onOpenDialog: (initData?: InitDialogData) => void;
  onSafeToast: (message: string) => void;
  onSanitizeError: (error: Object) => string;
}

export class IndexPageShowHelper {
  static handlePageShow(params: IndexPageShowParams): void {
    params.onStartArrivalReminderEngine();
    params.vm.reloadMinEventDurationLimit().catch((error: Error) => {
      const reason: string = params.onSanitizeError(error);
      hilog.warn(0x0000, 'Index', `[SETTING_UI][min_duration_reload_failed] reason=${reason}`);
    });
    params.vm.reloadRouteSwitches().catch((error: Error) => {
      const reason: string = params.onSanitizeError(error);
      hilog.warn(0x0000, 'Index', `[SETTING_UI][route_switch_reload_failed] reason=${reason}`);
    });

    params.onRefreshUnsavedFlag();
    const tempStateStr = params.onReadDraftStorage(AppStorageKeys.TEMP_DIALOG_STATE);
    const pickedLocStr = params.onReadDraftStorage(AppStorageKeys.PICKED_LOCATION_STR);
    const recovery = PageDraftRecovery.recover(tempStateStr, pickedLocStr);
    if (recovery.shouldClear) {
      params.onClearDraftStorage();
    }
    if (recovery.shouldRestore && recovery.restored) {
      params.onOpenDialog({
        name: recovery.restored.name,
        note: recovery.restored.note,
        duration: recovery.restored.duration,
        isAnchor: recovery.restored.isAnchor,
        fixedTime: recovery.restored.fixedTime,
        dayOffset: recovery.restored.dayOffset,
        isSchedule: recovery.restored.isSchedule,
        lat: recovery.restored.lat,
        lng: recovery.restored.lng
      });
    } else if (recovery.reason === 'temp_invalid') {
      params.onSafeToast('草稿已损坏，已自动清理。');
    } else if (recovery.reason === 'picked_invalid') {
      params.onSafeToast('地图选点缓存损坏，已自动清理。');
    }
  }
}
