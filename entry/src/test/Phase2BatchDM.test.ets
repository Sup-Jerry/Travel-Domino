import { describe, it, expect } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { CompactPlanSerializer } from '../main/ets/domain/serializers/CompactPlanSerializer';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { createPlanListPageForTest } from '../main/ets/pages/PlanListPage';

interface PlanListPagePrivateDM {
  planList: PlanItem[];
  isRefreshing: boolean;
  exportJsonText: string;
  isArrivalDialogOpen: boolean;
  lastNotifyPermissionPromptAt: number;
  lastLocationPermissionPromptAt: number;
  planService: PlanServiceMockDM;
  arrivalCoordinator: ArrivalCoordinatorMockDM;
  authFacade: AuthFacadeMockDM;
  onPageShow(): void;
  aboutToDisappear(): void;
  startGlobalArrivalEngine(): void;
  bindArrivalReminderSubscription(): void;
  showArrivalReminderOnHome(payload: ArrivalPayloadDM, title: string): void;
  ensureArrivalPermissionPromptOnFirstEntry(): Promise<void>;
  ensureNotificationPermissionPrompt(hostContext: Object): Promise<void>;
  ensureLocationPermissionPrompt(hostContext: Object): Promise<void>;
  openExportDialog(payload: Object): void;
  openImportDialog(): void;
  exportPlanAsJson(item: PlanItem): Promise<void>;
  importPlanFromJson(jsonText: string, cancelToken: Object): Promise<void>;
  loadPlans(): Promise<void>;
  handleArchive(item: PlanItem): Promise<void>;
  handleSoftDelete(item: PlanItem): Promise<void>;
  executeArchive(planId: number): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
}

class RouteOptionsDM {
  url: string = '';
  params: Object = new Object();
}

class RouterMockDM {
  public pushedUrls: string[] = [];
  public replacedUrls: string[] = [];

  pushUrl(options: RouteOptionsDM): void {
    this.pushedUrls.push(options.url);
  }

  async replaceUrl(options: RouteOptionsDM): Promise<void> {
    this.replacedUrls.push(options.url);
  }
}

class AlertButtonDM {
  value: string = '';
  action: () => void = () => {};
}

class AlertOptionsDM {
  title: string = '';
  message: string = '';
  primaryButton: AlertButtonDM = new AlertButtonDM();
  secondaryButton: AlertButtonDM = new AlertButtonDM();
}

class UiContextMockDM {
  public readonly router: RouterMockDM = new RouterMockDM();
  public readonly hostContext: Object = new Object();
  public alertCount: number = 0;
  public lastAlert: AlertOptionsDM | null = null;

  getRouter(): RouterMockDM {
    return this.router;
  }

  getHostContext(): Object {
    return this.hostContext;
  }

  showAlertDialog(options: AlertOptionsDM): void {
    this.alertCount += 1;
    this.lastAlert = options;
  }
}

class AuthFacadeMockDM {
  public bindCount: number = 0;
  public hasSession: boolean = true;

  bindContext(_context: Object): void {
    this.bindCount += 1;
  }

  getCurrentSession(): Object | null {
    return this.hasSession ? new Object() : null;
  }
}

class ArrivalPayloadDM {
  planId: number = 0;
  eventId: number = 0;
  placeName: string = '';
  distanceMeters: number = 0;
}

class PromptStateDM {
  notifyPrompted: boolean = false;
  locationPrompted: boolean = false;
}

class PlanServiceMockDM {
  public visiblePlans: PlanItem[] = [];
  public startCount: number = 0;
  public stopCount: number = 0;
  public archiveIds: number[] = [];
  public softDeleteIds: number[] = [];
  public notifyEnabled: boolean = true;
  public locationGranted: boolean = true;
  public markNotifyCount: number = 0;
  public markLocationCount: number = 0;
  public requestNotifyCount: number = 0;
  public requestLocationCount: number = 0;
  public failNotifyCheck: boolean = false;
  public failLocationCheck: boolean = false;

  async loadVisiblePlans(): Promise<PlanItem[]> {
    return this.visiblePlans;
  }

  startArrivalEngine(_planId: number, _vm: Object, _context: Object): void {
    this.startCount += 1;
  }

  stopArrivalEngine(): void {
    this.stopCount += 1;
  }

  async getArrivalPromptState(_context: Object): Promise<PromptStateDM> {
    return new PromptStateDM();
  }

  async isNotificationEnabled(): Promise<boolean> {
    if (this.failNotifyCheck) {
      throw new Error('notify_check_failed_dm');
    }
    return this.notifyEnabled;
  }

  async isLocationPermissionGranted(): Promise<boolean> {
    if (this.failLocationCheck) {
      throw new Error('location_check_failed_dm');
    }
    return this.locationGranted;
  }

  async markNotifyPrompted(_context: Object): Promise<void> {
    this.markNotifyCount += 1;
  }

  async markLocationPrompted(_context: Object): Promise<void> {
    this.markLocationCount += 1;
  }

  async requestEnableNotification(_context: Object): Promise<void> {
    this.requestNotifyCount += 1;
  }

  async requestLocationPermissions(_context: Object): Promise<boolean> {
    this.requestLocationCount += 1;
    return true;
  }

  async archivePlan(planId: number): Promise<void> {
    this.archiveIds.push(planId);
  }

  async softDeletePlan(planId: number): Promise<void> {
    this.softDeleteIds.push(planId);
  }
}

class ArrivalCoordinatorMockDM {
  public subscribeCount: number = 0;
  public unsubscribeCount: number = 0;
  public acknowledgeCalls: string[] = [];
  public lastOptions: Object | null = null;

  subscribePlan(_planId: string, options: Object): () => void {
    this.subscribeCount += 1;
    this.lastOptions = options;
    return (): void => {
      this.unsubscribeCount += 1;
    };
  }

  acknowledge(eventId: number, action: string): void {
    this.acknowledgeCalls.push(`${eventId}:${action}`);
  }
}

class PreferenceMockDM {
  public skip: boolean = true;

  async getValue(_key: string, _defaultValue: boolean): Promise<boolean> {
    return this.skip;
  }
}

class StaticPatchDM {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, nextValue: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(target, key, nextValue);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

function createPageDM(service: PlanServiceMockDM, coordinator: ArrivalCoordinatorMockDM, auth: AuthFacadeMockDM, uiContext: UiContextMockDM): PlanListPagePrivateDM {
  const page = createPlanListPageForTest() as PlanListPagePrivateDM;
  Reflect.set(page as Object, 'planService', service as Object);
  Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);
  Reflect.set(page as Object, 'authFacade', auth as Object);
  Reflect.set(page as Object, 'getUIContext', (): UiContextMockDM => uiContext);
  Reflect.set(page as Object, 'safeShowToast', (_message: string): void => {});
  return page;
}

function buildPlanDM(id: number, title: string): PlanItem {
  const item = {} as PlanItem;
  item.id = id;
  item.title = title;
  item.startDate = 1710000000000;
  item.createdAt = 1710000000000;
  item.status = 1;
  return item;
}

function buildTravelEventDM(id: number): TravelPlanItem {
  const event = {} as TravelPlanItem;
  event.id = id;
  event.name = `event-${id}`;
  event.address = `address-${id}`;
  event.dayOffset = id;
  event.sortOrder = id;
  event.fixedStartTime = '09:00';
  event.computedStartTime = '';
  event.duration = 60;
  event.priority = 0;
  event.lockStatus = 0;
  event.type = 'NORMAL';
  return event;
}

function buildParsedPlanDM(eventCount: number): ParsedPlanDM {
  const events: TravelPlanItem[] = [];
  for (let i = 0; i < eventCount; i += 1) {
    events.push(buildTravelEventDM(i));
  }
  return {
    plan: {
      title: 'share plan',
      startDate: 1710000000000,
      status: 1,
      enableAutoAmapRoute: true
    },
    events: events
  };
}

interface ParsedPlanMetaDM {
  title: string;
  startDate: number;
  status: number;
  enableAutoAmapRoute: boolean;
}

interface ParsedPlanDM {
  plan: ParsedPlanMetaDM;
  events: TravelPlanItem[];
}

async function flushMicrotasksDM(): Promise<void> {
  for (let i = 0; i < 20; i += 1) {
    await Promise.resolve();
  }
}

export default function phase2BatchDMTest() {
  describe('phase2BatchDMTest', () => {
    it('normal: plan_list_on_page_show_should_bind_load_and_subscribe_when_session_exists', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const coordinator = new ArrivalCoordinatorMockDM();
      const auth = new AuthFacadeMockDM();
      const uiContext = new UiContextMockDM();
      service.visiblePlans = [buildPlanDM(1, 'Tokyo')];
      const page = createPageDM(service, coordinator, auth, uiContext);
      Reflect.set(page as Object, 'ensureArrivalPermissionPromptOnFirstEntry', async (): Promise<void> => {});

      // Act
      page.onPageShow();
      await flushMicrotasksDM();

      // Assert
      expect(auth.bindCount).assertEqual(1);
      expect(uiContext.router.replacedUrls.length).assertEqual(0);
      expect(page.planList.length).assertEqual(1);
      expect(service.startCount).assertEqual(1);
      expect(coordinator.subscribeCount).assertEqual(1);
    });

    it('boundary: plan_list_on_page_show_should_redirect_guest_without_loading_plans', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const coordinator = new ArrivalCoordinatorMockDM();
      const auth = new AuthFacadeMockDM();
      const uiContext = new UiContextMockDM();
      auth.hasSession = false;
      const page = createPageDM(service, coordinator, auth, uiContext);

      // Act
      page.onPageShow();
      await flushMicrotasksDM();

      // Assert
      expect(uiContext.router.replacedUrls.length).assertEqual(1);
      expect(uiContext.router.replacedUrls[0]).assertEqual('pages/LoginPage');
      expect(service.startCount).assertEqual(0);
      expect(coordinator.subscribeCount).assertEqual(0);
    });

    it('conflict: plan_list_bind_subscription_should_unsubscribe_previous_callback_before_rebinding', 0, () => {
      // Arrange
      const page = createPageDM(new PlanServiceMockDM(), new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), new UiContextMockDM());
      const coordinator = page.arrivalCoordinator;

      // Act
      page.bindArrivalReminderSubscription();
      page.bindArrivalReminderSubscription();

      // Assert
      expect(coordinator.subscribeCount).assertEqual(2);
      expect(coordinator.unsubscribeCount).assertEqual(1);
    });

    it('regression: plan_list_about_to_disappear_should_unsubscribe_and_stop_engine_once', 0, () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const coordinator = new ArrivalCoordinatorMockDM();
      const page = createPageDM(service, coordinator, new AuthFacadeMockDM(), new UiContextMockDM());
      page.bindArrivalReminderSubscription();

      // Act
      page.aboutToDisappear();
      page.aboutToDisappear();

      // Assert
      expect(coordinator.unsubscribeCount).assertEqual(1);
      expect(service.stopCount).assertEqual(2);
    });

    it('normal: plan_list_home_arrival_alert_should_acknowledge_primary_and_secondary_actions', 0, () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const coordinator = new ArrivalCoordinatorMockDM();
      const uiContext = new UiContextMockDM();
      const page = createPageDM(service, coordinator, new AuthFacadeMockDM(), uiContext);
      const payload = new ArrivalPayloadDM();
      payload.planId = 7;
      payload.eventId = 12;
      payload.placeName = 'Gate';
      payload.distanceMeters = 0;

      // Act
      page.showArrivalReminderOnHome(payload, 'Plan A');
      const firstAlert = uiContext.lastAlert as AlertOptionsDM;
      firstAlert.primaryButton.action();
      page.showArrivalReminderOnHome(payload, 'Plan A');
      const secondAlert = uiContext.lastAlert as AlertOptionsDM;
      secondAlert.secondaryButton.action();

      // Assert
      expect(uiContext.alertCount).assertEqual(2);
      expect(page.isArrivalDialogOpen).assertFalse();
      expect(coordinator.acknowledgeCalls[0]).assertEqual('12:dismiss');
      expect(coordinator.acknowledgeCalls[1]).assertEqual('12:open_page');
      expect(uiContext.router.pushedUrls[0]).assertEqual('pages/Index');
    });

    it('combined: plan_list_first_entry_prompt_should_mark_and_open_missing_permission_dialogs', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const uiContext = new UiContextMockDM();
      service.notifyEnabled = false;
      service.locationGranted = false;
      const page = createPageDM(service, new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), uiContext);

      // Act
      await page.ensureArrivalPermissionPromptOnFirstEntry();

      // Assert
      expect(service.markNotifyCount).assertEqual(1);
      expect(service.markLocationCount).assertEqual(1);
      expect(page.lastNotifyPermissionPromptAt > 0).assertTrue();
      expect(page.lastLocationPermissionPromptAt > 0).assertTrue();
      expect(uiContext.alertCount).assertEqual(2);
    });

    it('invalid: plan_list_permission_prompt_should_return_when_state_checks_throw', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const uiContext = new UiContextMockDM();
      service.failNotifyCheck = true;
      service.failLocationCheck = true;
      const page = createPageDM(service, new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), uiContext);

      // Act
      await page.ensureNotificationPermissionPrompt(uiContext.hostContext);
      await page.ensureLocationPermissionPrompt(uiContext.hostContext);

      // Assert
      expect(uiContext.alertCount).assertEqual(0);
    });

    it('combined: plan_list_permission_dialog_actions_should_delegate_to_service_requests', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const uiContext = new UiContextMockDM();
      service.notifyEnabled = false;
      service.locationGranted = false;
      const page = createPageDM(service, new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), uiContext);

      // Act
      await page.ensureNotificationPermissionPrompt(uiContext.hostContext);
      const notifyAlert = uiContext.lastAlert as AlertOptionsDM;
      notifyAlert.secondaryButton.action();
      await flushMicrotasksDM();
      await page.ensureLocationPermissionPrompt(uiContext.hostContext);
      const locationAlert = uiContext.lastAlert as AlertOptionsDM;
      locationAlert.secondaryButton.action();
      await flushMicrotasksDM();

      // Assert
      expect(service.requestNotifyCount).assertEqual(1);
      expect(service.requestLocationCount).assertEqual(1);
    });

    it('normal: plan_list_export_plan_should_compress_share_payload_and_open_dialog', 0, async () => {
      // Arrange
      const page = createPageDM(new PlanServiceMockDM(), new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), new UiContextMockDM());
      let openedPayload: Object | null = null;
      const exportPatch = new StaticPatchDM(PlanImportExportService as Object, 'exportPlanToJson', async (_planId: number): Promise<string> => 'json_dm');
      const parsePatch = new StaticPatchDM(PlanSerializer as Object, 'deserializePlan', (_json: string): ParsedPlanDM => buildParsedPlanDM(55));
      const compressPatch = new StaticPatchDM(CompactPlanSerializer as Object, 'compressForShare', (_meta: Object, events: TravelPlanItem[]): string => `compressed-${events.length}`);
      Reflect.set(page as Object, 'openExportDialog', (payload: Object): void => {
        openedPayload = payload;
      });

      // Act
      await page.exportPlanAsJson(buildPlanDM(9, 'Share'));
      exportPatch.restore();
      parsePatch.restore();
      compressPatch.restore();

      // Assert
      expect(page.exportJsonText).assertEqual('compressed-50');
      expect(openedPayload !== null).assertTrue();
    });

    it('invalid: plan_list_import_plan_should_treat_cancelled_import_as_cancel_flow', 0, async () => {
      // Arrange
      const page = createPageDM(new PlanServiceMockDM(), new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), new UiContextMockDM());
      const patch = new StaticPatchDM(PlanImportExportService as Object, 'importPlanFromJson', async (_json: string, _token: Object): Promise<number> => {
        throw new Error('import_cancelled');
      });

      // Act
      await page.importPlanFromJson('bad', new Object());
      patch.restore();

      // Assert
      expect(page.planList.length).assertEqual(0);
    });

    it('regression: plan_list_import_plan_should_reload_after_successful_import', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      service.visiblePlans = [buildPlanDM(21, 'Imported')];
      const page = createPageDM(service, new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), new UiContextMockDM());
      const patch = new StaticPatchDM(PlanImportExportService as Object, 'importPlanFromJson', async (_json: string, _token: Object): Promise<number> => 21);

      // Act
      await page.importPlanFromJson('good', new Object());
      patch.restore();

      // Assert
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].title).assertEqual('Imported');
    });

    it('combined: plan_list_handle_archive_and_soft_delete_should_execute_when_tips_are_skipped', 0, async () => {
      // Arrange
      const service = new PlanServiceMockDM();
      const page = createPageDM(service, new ArrivalCoordinatorMockDM(), new AuthFacadeMockDM(), new UiContextMockDM());
      const pref = new PreferenceMockDM();
      pref.skip = true;
      const patch = new StaticPatchDM(PreferenceManager as Object, 'getInstance', (): PreferenceMockDM => pref);

      // Act
      await page.handleArchive(buildPlanDM(31, 'Archive'));
      await page.handleSoftDelete(buildPlanDM(32, 'Delete'));
      patch.restore();
      await flushMicrotasksDM();

      // Assert
      expect(service.archiveIds[0]).assertEqual(31);
      expect(service.softDeleteIds[0]).assertEqual(32);
    });
  });
}
