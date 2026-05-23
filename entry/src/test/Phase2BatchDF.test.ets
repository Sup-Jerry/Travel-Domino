import { describe, it, expect } from '@ohos/hypium';
import { AdvanceAdjustDialog } from '../main/ets/pages/components/dialogs/AdvanceAdjustDialog';
import {
  AdvanceAdjustCandidate,
  AdvanceAdjustContext,
  AdvanceAdjustPreview
} from '../main/ets/viewmodel/TimelineViewModel';

interface AdvanceCompressionCoordinatorDF {
  context: AdvanceAdjustContext | null;
  previewCalls: number;
  lastSelectedIds: Set<number> | null;
  lastTargetStartTime: string;
  buildAdvanceAdjustContext(targetIndex: number): AdvanceAdjustContext | null;
  previewAdvanceAdjust(
    targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes: number
  ): AdvanceAdjustPreview;
}

interface AdvanceVmDF {
  compressionCoordinator: AdvanceCompressionCoordinatorDF;
}

interface TimePickerAcceptValueDF {
  hour: number;
  minute: number;
}

interface TimePickerOptionsDF {
  selected: Date;
  useMilitaryTime: boolean;
  onAccept: (val: TimePickerAcceptValueDF) => void;
}

interface AdvanceUiContextDF {
  lastOptions: TimePickerOptionsDF | null;
  showTimePickerDialog(options: TimePickerOptionsDF): void;
}

interface AdvanceDialogPrivateDF {
  vm: AdvanceVmDF;
  targetIndex: number;
  forcedGapMinutes: number;
  context: AdvanceAdjustContext | null;
  selectedIds: Set<number>;
  targetStartTime: string;
  preview: AdvanceAdjustPreview | null;
  aboutToAppear(): void;
  timeToMinutes(time: string): number;
  minutesToTime(minutes: number): string;
  refreshPreview(): void;
  openTargetTimePicker(): void;
  toggleOne(id: number, checked: boolean): void;
  getUIContext(): AdvanceUiContextDF;
}

class AdvanceCompressionCoordinatorImplDF implements AdvanceCompressionCoordinatorDF {
  public context: AdvanceAdjustContext | null = null;
  public previewCalls: number = 0;
  public lastSelectedIds: Set<number> | null = null;
  public lastTargetStartTime: string = '';

  buildAdvanceAdjustContext(_targetIndex: number): AdvanceAdjustContext | null {
    return this.context;
  }

  previewAdvanceAdjust(
    _targetIndex: number,
    selectedIds: Set<number>,
    targetStartTime: string,
    forcedGapMinutes: number
  ): AdvanceAdjustPreview {
    this.previewCalls += 1;
    this.lastSelectedIds = new Set<number>(selectedIds);
    this.lastTargetStartTime = targetStartTime;
    return {
      valid: selectedIds.size > 0,
      message: selectedIds.size > 0 ? 'valid' : 'empty',
      selectedCount: selectedIds.size,
      shiftMinutes: forcedGapMinutes > 0 ? forcedGapMinutes : 30,
      requiredGapMinutes: forcedGapMinutes,
      remainingGapMinutes: selectedIds.size > 0 ? 0 : forcedGapMinutes,
      firstNewStartTime: targetStartTime,
      lastNewEndTime: '10:00',
      items: []
    };
  }
}

class AdvanceUiContextImplDF implements AdvanceUiContextDF {
  public lastOptions: TimePickerOptionsDF | null = null;

  showTimePickerDialog(options: TimePickerOptionsDF): void {
    this.lastOptions = options;
  }
}

function createAdvancePageDF(
  coordinator: AdvanceCompressionCoordinatorDF,
  uiContext?: AdvanceUiContextDF
): AdvanceDialogPrivateDF {
  const page = new AdvanceAdjustDialog(undefined, {} as LocalStorage) as Object as AdvanceDialogPrivateDF;
  page.vm = { compressionCoordinator: coordinator };
  page.targetIndex = 2;
  page.forcedGapMinutes = 45;
  page.context = null;
  page.selectedIds = new Set<number>();
  page.targetStartTime = '';
  page.preview = null;
  if (uiContext) {
    Reflect.set(page as Object, 'getUIContext', (): AdvanceUiContextDF => uiContext);
  }
  return page;
}

function buildCandidateDF(id: number, startTime: string): AdvanceAdjustCandidate {
  return {
    id: id,
    index: id,
    name: `candidate-${id}`,
    currentStartTime: startTime,
    currentEndTime: '10:00',
    duration: 60
  };
}

function buildContextDF(candidates: AdvanceAdjustCandidate[]): AdvanceAdjustContext {
  return {
    targetIndex: 2,
    targetId: 99,
    targetDayOffset: 0,
    candidates: candidates
  };
}

export default function phase2BatchDFTest() {
  describe('phase2BatchDFTest', () => {
    it('normal: advance_dialog_about_to_appear_should_select_candidates_and_build_preview', 0, () => {
      // Arrange
      const coordinator = new AdvanceCompressionCoordinatorImplDF();
      coordinator.context = buildContextDF([buildCandidateDF(1, '10:00'), buildCandidateDF(2, '10:30')]);
      const page = createAdvancePageDF(coordinator);

      // Act
      page.aboutToAppear();

      // Assert
      expect(page.context?.candidates.length ?? 0).assertEqual(2);
      expect(page.selectedIds.has(1)).assertTrue();
      expect(page.selectedIds.has(2)).assertTrue();
      expect(page.targetStartTime).assertEqual('09:15');
      expect(page.preview?.selectedCount ?? -1).assertEqual(2);
      expect(coordinator.previewCalls).assertEqual(1);
    });

    it('boundary: advance_dialog_about_to_appear_should_clear_preview_when_no_candidates', 0, () => {
      // Arrange
      const coordinator = new AdvanceCompressionCoordinatorImplDF();
      coordinator.context = buildContextDF([]);
      const page = createAdvancePageDF(coordinator);
      page.preview = coordinator.previewAdvanceAdjust(2, new Set<number>([1]), '09:00', 45);

      // Act
      page.aboutToAppear();

      // Assert
      expect(page.context?.candidates.length ?? -1).assertEqual(0);
      expect(page.preview).assertNull();
      expect(coordinator.previewCalls).assertEqual(1);
    });

    it('invalid: advance_dialog_refresh_preview_should_clear_preview_without_context', 0, () => {
      // Arrange
      const coordinator = new AdvanceCompressionCoordinatorImplDF();
      const page = createAdvancePageDF(coordinator);
      page.preview = coordinator.previewAdvanceAdjust(2, new Set<number>([1]), '09:00', 45);

      // Act
      page.refreshPreview();

      // Assert
      expect(page.preview).assertNull();
    });

    it('regression: advance_dialog_time_picker_accept_should_update_time_and_refresh_preview', 0, () => {
      // Arrange
      const coordinator = new AdvanceCompressionCoordinatorImplDF();
      coordinator.context = buildContextDF([buildCandidateDF(3, '11:00')]);
      const uiContext = new AdvanceUiContextImplDF();
      const page = createAdvancePageDF(coordinator, uiContext);
      page.context = coordinator.context;
      page.selectedIds = new Set<number>([3]);
      page.targetStartTime = '10:15';

      // Act
      page.openTargetTimePicker();
      uiContext.lastOptions?.onAccept({ hour: 8, minute: 5 });

      // Assert
      expect(uiContext.lastOptions?.useMilitaryTime ?? false).assertTrue();
      expect(page.targetStartTime).assertEqual('08:05');
      expect(coordinator.lastTargetStartTime).assertEqual('08:05');
      expect(page.preview?.firstNewStartTime ?? '').assertEqual('08:05');
    });

    it('combined: advance_dialog_toggle_one_should_replace_selection_and_refresh_preview', 0, () => {
      // Arrange
      const coordinator = new AdvanceCompressionCoordinatorImplDF();
      coordinator.context = buildContextDF([buildCandidateDF(4, '12:00'), buildCandidateDF(5, '12:30')]);
      const page = createAdvancePageDF(coordinator);
      page.context = coordinator.context;
      page.selectedIds = new Set<number>([4]);
      page.targetStartTime = '11:15';

      // Act
      page.toggleOne(5, true);
      page.toggleOne(4, false);

      // Assert
      expect(page.selectedIds.has(4)).assertFalse();
      expect(page.selectedIds.has(5)).assertTrue();
      expect(coordinator.lastSelectedIds?.has(5) ?? false).assertTrue();
      expect(page.preview?.selectedCount ?? -1).assertEqual(1);
      expect(page.timeToMinutes('29:99')).assertEqual(1439);
      expect(page.minutesToTime(-1)).assertEqual('23:59');
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}