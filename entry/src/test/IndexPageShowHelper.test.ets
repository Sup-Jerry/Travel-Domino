import { describe, it, expect } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { InitDialogData } from '../main/ets/pages/index/IndexTypes';
import { IndexPageShowHelper } from '../main/ets/pages/index/IndexPageShowHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface PageShowVm {
  reloadMinEventDurationLimit(): Promise<void>;
  reloadRouteSwitches(): Promise<void>;
}

class PageShowVmMock implements PageShowVm {
  private readonly rejectMinReload: boolean;
  private readonly rejectRouteReload: boolean;

  constructor(rejectMinReload: boolean, rejectRouteReload: boolean) {
    this.rejectMinReload = rejectMinReload;
    this.rejectRouteReload = rejectRouteReload;
  }

  reloadMinEventDurationLimit(): Promise<void> {
    if (this.rejectMinReload) {
      return Promise.reject(new Error('reload_min_failed'));
    }
    return Promise.resolve();
  }

  reloadRouteSwitches(): Promise<void> {
    if (this.rejectRouteReload) {
      return Promise.reject(new Error('reload_route_failed'));
    }
    return Promise.resolve();
  }
}

class PageShowProbe {
  public startCount: number = 0;
  public refreshCount: number = 0;
  public clearCount: number = 0;
  public toastCount: number = 0;
  public sanitizeCount: number = 0;
  public openCount: number = 0;
  public lastDialogData?: InitDialogData;
  private readonly tempStateRaw: string;
  private readonly pickedRaw: string;

  constructor(tempStateRaw: string, pickedRaw: string) {
    this.tempStateRaw = tempStateRaw;
    this.pickedRaw = pickedRaw;
  }

  public run(vm: PageShowVmMock): void {
    IndexPageShowHelper.handlePageShow({
      vm: vm as Object as TimelineViewModel,
      onStartArrivalReminderEngine: () => {
        this.startCount += 1;
      },
      onRefreshUnsavedFlag: () => {
        this.refreshCount += 1;
      },
      onReadDraftStorage: (key: string) => {
        if (key === AppStorageKeys.TEMP_DIALOG_STATE) {
          return this.tempStateRaw;
        }
        if (key === AppStorageKeys.PICKED_LOCATION_STR) {
          return this.pickedRaw;
        }
        return '';
      },
      onClearDraftStorage: () => {
        this.clearCount += 1;
      },
      onOpenDialog: (initData?: InitDialogData) => {
        this.openCount += 1;
        this.lastDialogData = initData;
      },
      onSafeToast: (_message: string) => {
        this.toastCount += 1;
      },
      onSanitizeError: (_error: Object) => {
        this.sanitizeCount += 1;
        return 'sanitized';
      }
    });
  }
}

function buildTempStateRaw(name: string, dayOffset: number): string {
  return JSON.stringify({
    name: name,
    note: 'note',
    duration: 60,
    isAnchor: false,
    fixedTime: '09:00',
    dayOffset: dayOffset,
    isSchedule: true,
    lat: 30.1,
    lng: 120.2
  });
}

export default function indexPageShowHelperTest() {
  describe('unit_test_case_generator_autofill_IndexPageShowHelper', () => {
    it('normal: handle_page_show_should_restore_temp_draft_when_picked_absent', 0, () => {
      // Arrange
      const probe = new PageShowProbe(buildTempStateRaw('temp_name', 2), '');
      // Act
      probe.run(new PageShowVmMock(false, false));
      // Assert
      expect(probe.startCount).assertEqual(1);
      expect(probe.refreshCount).assertEqual(1);
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(1);
      expect((probe.lastDialogData as InitDialogData).name).assertEqual('temp_name');
    });

    it('boundary: handle_page_show_should_skip_recovery_when_both_drafts_empty', 0, () => {
      // Arrange
      const probe = new PageShowProbe('', '');
      // Act
      probe.run(new PageShowVmMock(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(0);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(0);
    });

    it('invalid: handle_page_show_should_clear_and_toast_when_temp_draft_broken', 0, () => {
      // Arrange
      const probe = new PageShowProbe('broken_json', '');
      // Act
      probe.run(new PageShowVmMock(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(1);
    });

    it('conflict: handle_page_show_should_clear_and_toast_when_picked_draft_invalid', 0, () => {
      // Arrange
      const probe = new PageShowProbe(buildTempStateRaw('temp_name', 1), 'invalid_picked');
      // Act
      probe.run(new PageShowVmMock(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(1);
    });

    it('regression: handle_page_show_should_sanitize_reload_errors_without_breaking_recovery', 0, async (done: Function) => {
      // Arrange
      const probe = new PageShowProbe(buildTempStateRaw('recover_after_error', 3), '');
      // Act
      probe.run(new PageShowVmMock(true, true));
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(probe.sanitizeCount).assertEqual(2);
      expect(probe.openCount).assertEqual(1);
      done();
    });

    it('combined: handle_page_show_should_merge_temp_and_picked_payload', 0, () => {
      // Arrange
      const picked = JSON.stringify({
        lat: 22.6,
        lng: 114.1,
        address: 'picked_address'
      });
      const probe = new PageShowProbe(buildTempStateRaw('old_name', 4), picked);
      // Act
      probe.run(new PageShowVmMock(false, false));
      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(1);
      expect((probe.lastDialogData as InitDialogData).name).assertEqual('picked_address');
      expect((probe.lastDialogData as InitDialogData).dayOffset).assertEqual(4);
    });

    it('boundary: handle_page_show_should_clear_orphan_picked_without_restore', 0, () => {
      // Arrange
      const picked = JSON.stringify({
        lat: 39.9,
        lng: 116.4,
        address: 'picked_only'
      });
      const probe = new PageShowProbe('', picked);

      // Act
      probe.run(new PageShowVmMock(false, false));

      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(0);
      expect(probe.toastCount).assertEqual(0);
    });

    it('combined: handle_page_show_should_use_coordinate_fallback_when_picked_address_blank', 0, () => {
      // Arrange
      const picked = JSON.stringify({
        lat: 31.2304,
        lng: 121.4737,
        address: '   '
      });
      const probe = new PageShowProbe(buildTempStateRaw('old_name', 5), picked);

      // Act
      probe.run(new PageShowVmMock(false, false));

      // Assert
      expect(probe.clearCount).assertEqual(1);
      expect(probe.openCount).assertEqual(1);
      expect((probe.lastDialogData as InitDialogData).name.indexOf('31.23040') >= 0).assertTrue();
      expect((probe.lastDialogData as InitDialogData).name.indexOf('121.47370') >= 0).assertTrue();
      expect((probe.lastDialogData as InitDialogData).dayOffset).assertEqual(5);
    });
  });
}
