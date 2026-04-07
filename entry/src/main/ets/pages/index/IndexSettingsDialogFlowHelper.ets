import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { IndexPageActionsHelper } from './IndexPageActionsHelper';

export interface IndexSettingsDialogFlowContext {
  vm: TimelineViewModel;
  planTitle: string;
  getUIContext: () => UIContext;
  safeShowToast: (message: string) => void;
  setPlanTitle: (title: string) => void;
  requestPlanDateUpdate: (dateMs: number) => void;
  setDialogController: (controller: CustomDialogController | null) => void;
  setSettingsDialogController: (controller: CustomDialogController | null) => void;
}

export class IndexSettingsDialogFlowHelper {
  static open(context: IndexSettingsDialogFlowContext): void {
    const settingsController = IndexPageActionsHelper.openSettingsDialog({
      vm: context.vm,
      getUIContext: (): UIContext => context.getUIContext(),
      safeShowToast: (message: string): void => context.safeShowToast(message),
      openRenameDialog: (): void => {
        const renameController = IndexPageActionsHelper.openRenameDialog({
          vm: context.vm,
          planTitle: context.planTitle,
          setPlanTitle: (title: string): void => context.setPlanTitle(title)
        });
        context.setDialogController(renameController);
        renameController.open();
      },
      openDatePicker: (): void => {
        IndexPageActionsHelper.openDatePicker({
          vm: context.vm,
          getUIContext: (): UIContext => context.getUIContext(),
          requestPlanDateUpdate: (dateMs: number): void => context.requestPlanDateUpdate(dateMs)
        });
      }
    });
    context.setSettingsDialogController(settingsController);
    settingsController.open();
  }
}
