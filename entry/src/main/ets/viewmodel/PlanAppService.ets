import { notificationManager } from '@kit.NotificationKit';
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlanRepositoryImpl, PlanItem } from '../infrastructure/persistence/PlanRepositoryImpl';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { ArrivalReminderEngine } from '../infrastructure/services/ArrivalReminderEngine';
import { TimelineViewModel } from './TimelineViewModel';

export interface ArrivalPromptState {
  notifyPrompted: boolean;
  locationPrompted: boolean;
}

export interface PlanRepository {
  createPlan(title: string, startDate: number): Promise<number>;
  purgeOldTrash(): Promise<number>;
  getPlanList(): Promise<PlanItem[]>;
  getArchivedPlans(): Promise<PlanItem[]>;
  getTrashPlans(): Promise<PlanItem[]>;
  updatePlanStatus(id: number, status: number): Promise<void>;
  softDeletePlan(id: number): Promise<void>;
  restorePlan(id: number): Promise<void>;
  hardDeletePlan(id: number): Promise<void>;
}

class DaoPlanRepository implements PlanRepository {
  public async createPlan(title: string, startDate: number): Promise<number> {
    return PlanRepositoryImpl.createPlan(title, startDate);
  }

  public async purgeOldTrash(): Promise<number> {
    return PlanRepositoryImpl.purgeOldTrash();
  }

  public async getPlanList(): Promise<PlanItem[]> {
    return PlanRepositoryImpl.getPlanList();
  }

  public async getArchivedPlans(): Promise<PlanItem[]> {
    return PlanRepositoryImpl.getArchivedPlans();
  }

  public async getTrashPlans(): Promise<PlanItem[]> {
    return PlanRepositoryImpl.getTrashPlans();
  }

  public async updatePlanStatus(id: number, status: number): Promise<void> {
    await PlanRepositoryImpl.updatePlanStatus(id, status);
  }

  public async softDeletePlan(id: number): Promise<void> {
    await PlanRepositoryImpl.softDeletePlan(id);
  }

  public async restorePlan(id: number): Promise<void> {
    await PlanRepositoryImpl.restorePlan(id);
  }

  public async hardDeletePlan(id: number): Promise<void> {
    await PlanRepositoryImpl.hardDeletePlan(id);
  }
}

export class PlanAppService {
  private static instance: PlanAppService | null = null;
  private static testRepo: PlanRepository | null = null;
  private static readonly defaultRepo: PlanRepository = new DaoPlanRepository();

  public static setPlanRepositoryForTest(repo: PlanRepository | null): void {
    PlanAppService.testRepo = repo;
  }

  private static getPlanRepository(): PlanRepository {
    return PlanAppService.testRepo ?? PlanAppService.defaultRepo;
  }

  public static getInstance(): PlanAppService {
    if (!PlanAppService.instance) {
      PlanAppService.instance = new PlanAppService();
    }
    return PlanAppService.instance;
  }

  public async createPlan(title: string, startDate: number): Promise<number> {
    return PlanAppService.getPlanRepository().createPlan(title, startDate);
  }

  public async loadVisiblePlans(): Promise<PlanItem[]> {
    const repo = PlanAppService.getPlanRepository();
    await repo.purgeOldTrash();
    const all = await repo.getPlanList();
    return all.filter((item: PlanItem) => item.status !== 2);
  }

  public async loadArchivedPlans(): Promise<PlanItem[]> {
    const repo = PlanAppService.getPlanRepository();
    await repo.purgeOldTrash();
    return repo.getArchivedPlans();
  }

  public async loadTrashPlans(): Promise<PlanItem[]> {
    const repo = PlanAppService.getPlanRepository();
    await repo.purgeOldTrash();
    return repo.getTrashPlans();
  }

  public async archivePlan(planId: number): Promise<void> {
    await PlanAppService.getPlanRepository().updatePlanStatus(planId, 2);
  }

  public async activatePlan(planId: number): Promise<void> {
    await PlanAppService.getPlanRepository().updatePlanStatus(planId, 0);
  }

  public async softDeletePlan(planId: number): Promise<void> {
    await PlanAppService.getPlanRepository().softDeletePlan(planId);
  }

  public async restorePlan(planId: number): Promise<void> {
    await PlanAppService.getPlanRepository().restorePlan(planId);
  }

  public async hardDeletePlan(planId: number): Promise<void> {
    await PlanAppService.getPlanRepository().hardDeletePlan(planId);
  }

  public startArrivalEngine(planId: number, vm: TimelineViewModel, hostContext: Context): void {
    try {
      ArrivalReminderEngine.getInstance().start(planId, vm, hostContext);
    } catch (error) {
      hilog.warn(0x0000, 'PlanAppService', `[ARRIVAL][engine_start_failed] reason=${JSON.stringify(error)}`);
    }
  }

  public stopArrivalEngine(): void {
    ArrivalReminderEngine.getInstance().stop();
  }

  public async requestArrivalCheckNow(reason: string = 'manual_refresh'): Promise<void> {
    await ArrivalReminderEngine.getInstance().requestImmediateDetection(reason);
  }

  public async getArrivalPromptState(hostContext: common.UIAbilityContext): Promise<ArrivalPromptState> {
    const pref = PreferenceManager.getInstance();
    await pref.init(hostContext);
    return {
      notifyPrompted: await pref.getValue(PreferenceManager.KEY_ARRIVAL_NOTIFY_PROMPTED, false) === true,
      locationPrompted: await pref.getValue(PreferenceManager.KEY_ARRIVAL_LOCATION_PROMPTED, false) === true
    };
  }

  public async markNotifyPrompted(hostContext: common.UIAbilityContext): Promise<void> {
    const pref = PreferenceManager.getInstance();
    await pref.init(hostContext);
    await pref.setValue(PreferenceManager.KEY_ARRIVAL_NOTIFY_PROMPTED, true);
  }

  public async markLocationPrompted(hostContext: common.UIAbilityContext): Promise<void> {
    const pref = PreferenceManager.getInstance();
    await pref.init(hostContext);
    await pref.setValue(PreferenceManager.KEY_ARRIVAL_LOCATION_PROMPTED, true);
  }

  public async isNotificationEnabled(): Promise<boolean> {
    try {
      return notificationManager.isNotificationEnabled();
    } catch (error) {
      hilog.warn(0x0000, 'PlanAppService', `[ARRIVAL][notify_enabled_check_failed] reason=${JSON.stringify(error)}`);
      return false;
    }
  }

  public async requestEnableNotification(hostContext: common.UIAbilityContext): Promise<void> {
    try {
      await notificationManager.requestEnableNotification(hostContext);
    } catch (error) {
      const reason = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.warn(0x0000, 'PlanAppService', `[ARRIVAL][notify_request_failed] reason=${reason}`);
      throw new Error(reason);
    }
  }

  public async isLocationPermissionGranted(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      const tokenID = bundleInfo.appInfo.accessTokenId;
      const checkStatus = await atManager.checkAccessToken(tokenID, 'ohos.permission.LOCATION');
      return checkStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (error) {
      hilog.warn(0x0000, 'PlanAppService', `[ARRIVAL][location_check_failed] reason=${JSON.stringify(error)}`);
      return false;
    }
  }

  public async requestLocationPermissions(hostContext: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const results = await atManager.requestPermissionsFromUser(hostContext, [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ]);
      return results.authResults.some((result: number) => result === 0);
    } catch (error) {
      hilog.warn(0x0000, 'PlanAppService', `[ARRIVAL][location_request_failed] reason=${JSON.stringify(error)}`);
      return false;
    }
  }
}
