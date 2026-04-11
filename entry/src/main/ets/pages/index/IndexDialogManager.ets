import { DateFilterDialog } from '../components/dialogs/DateFilterDialog';
import { PlanSettingsDialog } from '../components/dialogs/PlanSettingsDialog';
import { RenameDialog } from '../components/dialogs/RenameDialog';
import { WeatherUserPreference } from '../../domain/services/WeatherModels';
import { AiInputDialog } from '../components/dialogs/AiInputDialog';
import { ComposableStrategy } from '../../domain/strategy/TravelStrategyDimensions';
import { SuggestionDialog } from '../components/dialogs/SuggestionDialog';
import { ConflictSelectionDialog } from '../components/dialogs/ConflictSelectionDialog';
import { ConflictCompressDialog } from '../components/dialogs/ConflictCompressDialog';
import { AdvanceAdjustDialog } from '../components/dialogs/AdvanceAdjustDialog';
import { GapResolutionDialog } from '../components/dialogs/GapResolutionDialog';
import { DateConflictDialog } from '../components/dialogs/DateConflictDialog';
import { AddItemDialog } from '../components/dialogs/AddItemDialog';
import { PlanShareDialog } from '../components/dialogs/PlanShareDialog';
import { EventEntity } from '../../model/entity/EventEntity';
import { CompressionMode, TimelineViewModel } from '../../viewmodel/TimelineViewModel';

export interface DateFilterCallbacks {
  onShowAll: () => void;
  onSelectDate: () => void;
  onSelectRange: () => void;
}

export interface DateFilterOpenCallbacks {
  onShowAll: () => void;
  onSelectDate: (dateMs: number) => void;
  onSelectRange: (startMs: number, endMs: number) => void;
}

export interface SettingsCallbacks {
  onRename: () => void;
  onReschedule: () => void;
  onShare: () => void;
  weatherUserPreference: WeatherUserPreference;
  onWeatherPreferenceChange: (preference: WeatherUserPreference) => Promise<void>;
}

export interface AiDialogCallbacks {
  hasAiHistory: boolean;
  currentStrategyMode?: number;
  onConfirm: (text: string, strategy: number, customStrategy?: ComposableStrategy) => Promise<void>;
  onRegenerate: (strategy: number, customStrategy?: ComposableStrategy, keepCurrentMode?: boolean) => Promise<void>;
}

export interface SuggestionDialogCallbacks {
  itemName: string;
  conflictName: string;
  targetTime: string;
  suggestedTime: string;
  detailMsg: string;
  onConfirm: () => void;
  onBack: () => void;
}

export interface ConflictSelectionCallbacks {
  gapMinutes: number;
  onDelayY: () => void;
  onCompressX: () => void;
  onShiftSameDay: () => void;
  onAdvanceAdjust: () => void;
  onSmartAdjust: () => void;
}

export interface ConflictCompressCallbacks {
  vm: TimelineViewModel;
  targetIndex: number;
  targetTime: string;
  targetName: string;
  initialMode: CompressionMode;
  initialSelectedIds: number[];
  onCancel: () => void;
  onConfirm: (selectedIds: number[], mode: CompressionMode) => void;
}

export interface AdvanceAdjustCallbacks {
  vm: TimelineViewModel;
  targetIndex: number;
  targetName: string;
  forcedGapMinutes?: number;
  onCancel: () => void;
  onConfirm: (selectedIds: number[], nextStartTime: string) => void;
}

export interface GapResolutionCallbacks {
  vm: TimelineViewModel;
  currentGap: EventEntity | null;
}

export interface DateConflictCallbacks {
  conflictDateStr: string;
  planStartDateStr: string;
  planStartDate: number;
  onChangeItemDate: () => void;
  onMoveToBacklog: () => void;
  onChangePlanStartDate: () => void;
  onCancel: () => void;
}

export interface AddItemDialogCallbacks {
  initName: string;
  initNote: string;
  initDuration: number;
  initIsAnchor: boolean;
  initFixedTime: string;
  initSuggestedTime: string;
  initIsSchedule: boolean;
  initDayOffset: number;
  initPreTravel: number;
  initPriority: number;
  storageScopePlanId: number;
  planStartDate: number;
  initLat: number;
  initLng: number;
  onDateChangedRecommendTime: (dayOffset: number, currentTime: string) => string;
  onConfirm: (
    name: string,
    duration: number,
    isSchedule: boolean,
    fixedTime?: string,
    dayOffset?: number,
    preTravel?: number,
    isHardLock?: boolean,
    note?: string,
    isMustVisit?: boolean,
    lat?: number,
    lng?: number
  ) => Promise<void>;
}

export interface ShareDialogCallbacks {
  planId: number;
  planTitle: string;
  startDate: number;
  endDate: number;
  totalDays: number;
  totalEvents: number;
  compressedJson: string;
}

export class IndexDialogManager {
  static createDateFilterController(callbacks: DateFilterCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: DateFilterDialog({
        onShowAll: callbacks.onShowAll,
        onSelectDate: callbacks.onSelectDate,
        onSelectRange: callbacks.onSelectRange
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      autoCancel: true
    });
  }

  static openDateFilterDialog(
    uiContext: UIContext,
    planStartDate: number,
    callbacks: DateFilterOpenCallbacks
  ): CustomDialogController {
    const controller = IndexDialogManager.createDateFilterController({
      onShowAll: callbacks.onShowAll,
      onSelectDate: () => {
        IndexDialogManager.openSingleDateFilterPicker(uiContext, planStartDate, callbacks.onSelectDate);
      },
      onSelectRange: () => {
        IndexDialogManager.openRangeDateFilterPicker(uiContext, planStartDate, callbacks.onSelectRange);
      }
    });
    controller.open();
    return controller;
  }

  static createSettingsController(callbacks: SettingsCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: PlanSettingsDialog({
        onRename: callbacks.onRename,
        onReschedule: callbacks.onReschedule,
        onShare: callbacks.onShare,
        weatherUserPreference: callbacks.weatherUserPreference,
        onWeatherPreferenceChange: callbacks.onWeatherPreferenceChange
      }),
      alignment: DialogAlignment.Bottom,
      customStyle: true,
      autoCancel: true
    });
  }

  static createRenameController(initName: string, onConfirm: (name: string) => void): CustomDialogController {
    return new CustomDialogController({
      builder: RenameDialog({
        initName: initName,
        onConfirm: onConfirm
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true
    });
  }

  static createAiDialogController(callbacks: AiDialogCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: AiInputDialog({
        hasAiHistory: callbacks.hasAiHistory,
        currentStrategyMode: callbacks.currentStrategyMode ?? 0,
        onConfirm: callbacks.onConfirm,
        onRegenerate: callbacks.onRegenerate
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
    });
  }

  static createSuggestionController(callbacks: SuggestionDialogCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: SuggestionDialog({
        itemName: callbacks.itemName,
        conflictName: callbacks.conflictName,
        targetTime: callbacks.targetTime,
        suggestedTime: callbacks.suggestedTime,
        detailMsg: callbacks.detailMsg,
        onConfirm: callbacks.onConfirm,
        onBack: callbacks.onBack
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
    });
  }

  static createConflictSelectionController(callbacks: ConflictSelectionCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: ConflictSelectionDialog({
        gapMinutes: callbacks.gapMinutes,
        onDelayY: callbacks.onDelayY,
        onCompressX: callbacks.onCompressX,
        onShiftSameDay: callbacks.onShiftSameDay,
        onAdvanceAdjust: callbacks.onAdvanceAdjust,
        onSmartAdjust: callbacks.onSmartAdjust
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
  }

  static createConflictCompressController(callbacks: ConflictCompressCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: ConflictCompressDialog({
        vm: callbacks.vm,
        targetIndex: callbacks.targetIndex,
        targetTime: callbacks.targetTime,
        targetName: callbacks.targetName,
        initialMode: callbacks.initialMode,
        initialSelectedIds: callbacks.initialSelectedIds,
        onCancel: callbacks.onCancel,
        onConfirm: callbacks.onConfirm
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
  }

  static createAdvanceAdjustController(callbacks: AdvanceAdjustCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: AdvanceAdjustDialog({
        vm: callbacks.vm,
        targetIndex: callbacks.targetIndex,
        targetName: callbacks.targetName,
        forcedGapMinutes: callbacks.forcedGapMinutes ?? 0,
        onCancel: callbacks.onCancel,
        onConfirm: callbacks.onConfirm
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false
    });
  }

  static createGapResolutionController(callbacks: GapResolutionCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: GapResolutionDialog({
        vm: callbacks.vm,
        currentGap: callbacks.currentGap
      }),
      alignment: DialogAlignment.Center,
      offset: { dx: 0, dy: 0 },
      customStyle: true
    });
  }

  static createDateConflictController(callbacks: DateConflictCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: DateConflictDialog({
        conflictDateStr: callbacks.conflictDateStr,
        planStartDateStr: callbacks.planStartDateStr,
        planStartDate: callbacks.planStartDate,
        onChangeItemDate: callbacks.onChangeItemDate,
        onMoveToBacklog: callbacks.onMoveToBacklog,
        onChangePlanStartDate: callbacks.onChangePlanStartDate,
        onCancel: callbacks.onCancel
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center
    });
  }

  static createAddItemController(callbacks: AddItemDialogCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: AddItemDialog({
        initName: callbacks.initName,
        initNote: callbacks.initNote,
        initDuration: callbacks.initDuration,
        initIsAnchor: callbacks.initIsAnchor,
        initFixedTime: callbacks.initFixedTime,
        initSuggestedTime: callbacks.initSuggestedTime,
        initIsSchedule: callbacks.initIsSchedule,
        initDayOffset: callbacks.initDayOffset,
        initPreTravel: callbacks.initPreTravel,
        initPriority: callbacks.initPriority,
        storageScopePlanId: callbacks.storageScopePlanId,
        planStartDate: callbacks.planStartDate,
        initLat: callbacks.initLat,
        initLng: callbacks.initLng,
        onDateChangedRecommendTime: callbacks.onDateChangedRecommendTime,
        onConfirm: callbacks.onConfirm
      }),
      alignment: DialogAlignment.Center,
      offset: { dx: 0, dy: -50 },
      autoCancel: true,
      customStyle: true
    });
  }

  static createShareController(callbacks: ShareDialogCallbacks): CustomDialogController {
    return new CustomDialogController({
      builder: PlanShareDialog({
        planId: callbacks.planId,
        planTitle: callbacks.planTitle,
        startDate: callbacks.startDate,
        endDate: callbacks.endDate,
        totalDays: callbacks.totalDays,
        totalEvents: callbacks.totalEvents,
        compressedJson: callbacks.compressedJson
      }),
      alignment: DialogAlignment.Center
    });
  }

  static openSingleDateFilterPicker(uiContext: UIContext, planStartDate: number, onAccept: (dateMs: number) => void): void {
    setTimeout(() => {
      uiContext.showDatePickerDialog({
        start: new Date(planStartDate || new Date()),
        end: new Date(4102416000000),
        selected: new Date(planStartDate || new Date()),
        onAccept: (value: DatePickerResult) => {
          const selectDate = new Date();
          selectDate.setFullYear(value.year, value.month, value.day);
          selectDate.setHours(0, 0, 0, 0);
          onAccept(selectDate.getTime());
        }
      });
    }, 100);
  }

  static openRangeDateFilterPicker(
    uiContext: UIContext,
    planStartDate: number,
    onAccept: (startMs: number, endMs: number) => void
  ): void {
    setTimeout(() => {
      uiContext.showDatePickerDialog({
        start: new Date(planStartDate || new Date()),
        end: new Date(4102416000000),
        selected: new Date(planStartDate || new Date()),
        onAccept: (startValue: DatePickerResult) => {
          const startDate = new Date();
          startDate.setFullYear(startValue.year, startValue.month, startValue.day);
          startDate.setHours(0, 0, 0, 0);
          setTimeout(() => {
            IndexDialogManager.openRangeEndDatePicker(uiContext, startDate, onAccept);
          }, 300);
        }
      });
    }, 100);
  }

  static openRangeEndDatePicker(
    uiContext: UIContext,
    startDate: Date,
    onAccept: (startMs: number, endMs: number) => void
  ): void {
    uiContext.showDatePickerDialog({
      start: startDate,
      end: new Date(4102416000000),
      selected: startDate,
      onAccept: (endValue: DatePickerResult) => {
        const endDate = new Date();
        endDate.setFullYear(endValue.year, endValue.month, endValue.day);
        endDate.setHours(23, 59, 59, 999);
        onAccept(startDate.getTime(), endDate.getTime());
      }
    });
  }

  static openPlanDatePicker(
    uiContext: UIContext,
    planStartDate: number,
    onAccept: (dateMs: number) => void
  ): void {
    uiContext.showDatePickerDialog({
      start: new Date(946684800000),
      end: new Date(4102416000000),
      selected: new Date(planStartDate || new Date()),
      onAccept: (value: DatePickerResult) => {
        const newDate = new Date();
        newDate.setFullYear(value.year, value.month, value.day);
        newDate.setHours(0, 0, 0, 0);
        onAccept(newDate.getTime());
      }
    });
  }
}
