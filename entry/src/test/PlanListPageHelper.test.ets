import { describe, it, expect } from '@ohos/hypium';
import { DateUtil } from '../main/ets/common/utils/DateUtil';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { CompactPlanSerializer } from '../main/ets/domain/serializers/CompactPlanSerializer';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  buildPlanListShareEventItems,
  canPlanListRepromptPermission,
  createPlanListPageForTest,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime,
  sortPlanListShareEvents
} from '../main/ets/pages/PlanListPage';

interface PlanListPaletteTest {
  textPrimary: Object;
  pageBg: Object;
}

interface PlanListPagePrivateTest {
  planList: PlanItem[];
  isRefreshing: boolean;
  isArrivalDialogOpen: boolean;
  effectiveTheme: string;
  exportJsonText: string;
  lastNotifyPermissionPromptAt: number;
  lastLocationPermissionPromptAt: number;
  getThemePalette(): PlanListPaletteTest;
  canRepromptPermission(now: number, lastPromptAt: number, hasPromptedBefore: boolean): boolean;
  convertToShareEvents(events: TravelPlanItem[]): Object[];
  sortEventsForShare(events: TravelPlanItem[]): TravelPlanItem[];
  startGlobalArrivalEngine(): void;
  bindArrivalReminderSubscription(): void;
  consumeNotificationNavRoute(): void;
  loadPlans(): Promise<void>;
  handlePullRefresh(): Promise<void>;
  exportPlanAsJson(item: PlanItem): Promise<void>;
  importPlanFromJson(jsonText: string, cancelToken: Object): Promise<void>;
  executeArchive(planId: number): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
  handleHardDelete(item: PlanItem): void;
  onPageShow(): void;
  aboutToDisappear(): void;
  ensureArrivalPermissionPromptOnFirstEntry(): Promise<void>;
  ensureNotificationPermissionPrompt(context: Object): Promise<void>;
  ensureLocationPermissionPrompt(context: Object): Promise<void>;
  showArrivalReminderOnHome(payload: Object, title: string): void;
  initialRender(): void;
}

class PlanListRouteParamsTest {
  planId: number = 0;
  title: string = '';
  isNewPlan: boolean = false;
  reminderEventId: number = -1;
  forceCompanionMode: boolean = false;
}

class PlanListRouteOptionsTest {
  url: string = '';
  params: PlanListRouteParamsTest = new PlanListRouteParamsTest();
}

class PlanListRouterMockTest {
  pushedUrls: string[] = [];
  replacedUrls: string[] = [];
  pushedOptions: PlanListRouteOptionsTest[] = [];
  shouldThrowOnPush: boolean = false;

  pushUrl(options: PlanListRouteOptionsTest): void {
    if (this.shouldThrowOnPush) {
      throw new Error('push_failed');
    }
    this.pushedUrls.push(options.url);
    this.pushedOptions.push(options);
  }

  replaceUrl(options: PlanListRouteOptionsTest): Promise<void> {
    this.replacedUrls.push(options.url);
    return Promise.resolve();
  }
}

class PlanListAlertButtonTest {
  value: string = '';
  action: () => void = () => {};
}

class PlanListAlertOptionsTest {
  title: string = '';
  message: string = '';
  autoCancel: boolean = true;
  primaryButton: PlanListAlertButtonTest = new PlanListAlertButtonTest();
  secondaryButton: PlanListAlertButtonTest = new PlanListAlertButtonTest();
}

class PlanListHostContextMockTest {
}

class PlanListUiContextMockTest {
  router: PlanListRouterMockTest = new PlanListRouterMockTest();
  alertCount: number = 0;
  lastAlert: PlanListAlertOptionsTest | null = null;

  getRouter(): PlanListRouterMockTest {
    return this.router;
  }

  getHostContext(): PlanListHostContextMockTest {
    return new PlanListHostContextMockTest();
  }

  showAlertDialog(options: PlanListAlertOptionsTest): void {
    this.alertCount += 1;
    this.lastAlert = options;
  }
}

class PlanListNotificationPayloadTest {
  planId: number = 0;
  eventId: number = 0;
  forceCompanionMode: boolean = false;
}

class PlanListPromptStateTest {
  notifyPrompted: boolean = false;
  locationPrompted: boolean = false;
}

class PlanListSessionMockTest {
  accountId: string = 'acc_plan_list';
}

class PlanListArrivalPayloadMockTest {
  seq: number = 0;
  planId: number = 0;
  eventId: number = 0;
  placeName: string = '';
  distanceMeters: number = 0;
  triggerAt: number = 0;
}

class PlanListAuthFacadeMockTest {
  bindCount: number = 0;
  session: Object | null = new PlanListSessionMockTest();

  bindContext(_context: Object): void {
    this.bindCount += 1;
  }

  getCurrentSession(): Object | null {
    return this.session;
  }
}

class PlanListPlanServiceMockTest {
  visiblePlans: PlanItem[] = [];
  archiveIds: number[] = [];
  softDeleteIds: number[] = [];
  hardDeleteIds: number[] = [];
  arrivalCheckReasons: string[] = [];
  stopArrivalEngineCount: number = 0;
  startArrivalEngineCount: number = 0;
  notifyEnabled: boolean = true;
  locationGranted: boolean = true;
  notifyRequestReject: Object | null = null;
  locationRequestThrow: Object | null = null;
  locationRequestResult: boolean = true;

  async loadVisiblePlans(): Promise<PlanItem[]> {
    return this.visiblePlans;
  }

  async archivePlan(planId: number): Promise<void> {
    this.archiveIds.push(planId);
  }

  async softDeletePlan(planId: number): Promise<void> {
    this.softDeleteIds.push(planId);
  }

  async hardDeletePlan(planId: number): Promise<void> {
    this.hardDeleteIds.push(planId);
  }

  async requestArrivalCheckNow(reason: string): Promise<void> {
    this.arrivalCheckReasons.push(reason);
  }

  startArrivalEngine(_planId: number, _vm: Object, _hostContext: Object): void {
    this.startArrivalEngineCount += 1;
  }

  stopArrivalEngine(): void {
    this.stopArrivalEngineCount += 1;
  }

  async getArrivalPromptState(_context: Object): Promise<PlanListPromptStateTest> {
    return new PlanListPromptStateTest();
  }

  notifyPromptedMarkCount: number = 0;
  locationPromptedMarkCount: number = 0;

  async markNotifyPrompted(_context: Object): Promise<void> {
    this.notifyPromptedMarkCount += 1;
  }

  async markLocationPrompted(_context: Object): Promise<void> {
    this.locationPromptedMarkCount += 1;
  }

  async isNotificationEnabled(): Promise<boolean> {
    return this.notifyEnabled;
  }

  async isLocationPermissionGranted(): Promise<boolean> {
    return this.locationGranted;
  }

  async requestEnableNotification(_context: Object): Promise<void> {
    if (this.notifyRequestReject) {
      throw (this.notifyRequestReject as Error);
    }
  }

  async requestLocationPermissions(_context: Object): Promise<boolean> {
    if (this.locationRequestThrow) {
      throw (this.locationRequestThrow as Error);
    }
    return this.locationRequestResult;
  }
}

class PlanListArrivalCoordinatorMockTest {
  consumeCount: number = 0;
  lastConsumeOptions: Object | null = null;
  ackEventIds: number[] = [];
  ackActions: string[] = [];
  subscribePlanCount: number = 0;
  lastSubscribeKey: string = '';
  lastSubscribeOptions: Object | null = null;
  unsubscribeCount: number = 0;

  consumeOnHome(options: Object): void {
    this.consumeCount += 1;
    this.lastConsumeOptions = options;
  }

  acknowledge(eventId: number, action: string): void {
    this.ackEventIds.push(eventId);
    this.ackActions.push(action);
  }

  subscribePlan(planKey: string, options: Object): () => void {
    this.subscribePlanCount += 1;
    this.lastSubscribeKey = planKey;
    this.lastSubscribeOptions = options;
    return (): void => {
      this.unsubscribeCount += 1;
    };
  }
}

class PlanListStaticPatchTest {
  private readonly target: Object;
  private readonly key: string;
  private readonly original: Object;

  constructor(target: Object, key: string, replacement: Object) {
    this.target = target;
    this.key = key;
    this.original = Reflect.get(target, key) as Object;
    Reflect.set(this.target, this.key, replacement);
  }

  restore(): void {
    Reflect.set(this.target, this.key, this.original);
  }
}

interface PlanListParsedPayloadTest {
  plan: PlanListParsedPlanMetaTest;
  events: TravelPlanItem[];
}

class PlanListParsedPlanMetaTest {
  title: string = '';
  startDate: number = 0;
  status: number = 0;
  enableAutoAmapRoute: boolean = false;
}

function buildShareEvent(): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.fixedStartTime = '09:30';
  item.computedStartTime = '10:00';
  item.priority = 0;
  item.lockStatus = 0;
  item.type = 'NORMAL';
  return item;
}

function buildPlanListPlanForTest(id: number, title: string): PlanItem {
  const item = {} as PlanItem;
  item.id = id;
  item.title = title;
  item.startDate = 1710000000000;
  item.createdAt = 1710000000000;
  return item;
}

function buildParsedPlanForExportTest(eventCount: number): PlanListParsedPayloadTest {
  const events: TravelPlanItem[] = [];
  for (let index = 0; index < eventCount; index += 1) {
    const item = buildShareEvent();
    item.name = `event_${index}`;
    item.dayOffset = Math.floor(index / 3);
    item.sortOrder = index;
    item.duration = 30 + (index % 4) * 15;
    item.fixedStartTime = '09:00';
    events.push(item);
  }
  const plan = new PlanListParsedPlanMetaTest();
  plan.title = 'share_plan_test';
  plan.startDate = 1711000000000;
  plan.status = 1;
  plan.enableAutoAmapRoute = true;
  const payload = {} as PlanListParsedPayloadTest;
  payload.plan = plan;
  payload.events = events;
  return payload;
}

export default function planListPageHelperTest() {
  describe('unit_test_case_generator_autofill_PlanListPageHelper', () => {
    it('normal: plan_list_share_start_should_extract_valid_time', 0, () => {
      // Arrange
      const event = buildShareEvent();
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('09:30');
    });

    it('boundary: plan_list_reprompt_should_allow_when_cooldown_exactly_met', 0, () => {
      // Arrange
      const now = 2000;
      const lastPromptAt = 1000;
      const cooldownMs = 1000;
      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, true, cooldownMs);
      // Assert
      expect(allowed).assertTrue();
    });

    it('invalid: plan_list_share_start_should_fallback_when_time_invalid', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.fixedStartTime = 'abc';
      event.computedStartTime = '';
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('--:--');
    });

    it('conflict: plan_list_share_icon_should_prioritize_star_over_anchor', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.priority = 1;
      event.lockStatus = 1;
      event.type = 'ANCHOR';
      // Act
      const icon = resolvePlanListShareIcon(event);
      // Assert
      expect(icon).assertEqual('⭐');
    });

    it('regression: td-20260412-plan_list_share_category_anchor_should_keep_fixed_label', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.type = 'ANCHOR';
      // Act
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(category).assertEqual('固定行程');
    });

    it('combined: plan_list_share_end_should_fallback_when_start_invalid_even_with_duration', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.fixedStartTime = '';
      event.computedStartTime = 'invalid';
      // Act
      const end = resolvePlanListShareEndTime(event, 90);
      // Assert
      expect(end).assertEqual('--:--');
    });

    it('boundary: plan_list_share_end_should_fallback_when_duration_is_invalid_number', 0, () => {
      // Arrange
      const event = buildShareEvent();
      const originCalculateEndTime = Reflect.get(DateUtil as Object, 'calculateEndTime') as Object;
      Reflect.set(DateUtil as Object, 'calculateEndTime', (_startTime: string, _duration: number): string => {
        return 'invalid_end_time';
      });

      // Act
      const end = resolvePlanListShareEndTime(event, Number.NaN);
      Reflect.set(DateUtil as Object, 'calculateEndTime', originCalculateEndTime);

      // Assert
      expect(end).assertEqual('--:--');
    });
  });

  describe('unit_test_case_generator_autofill_PlanListPageHelperBranches', () => {
    it('normal: plan_list_share_events_should_sort_by_day_offset_then_sort_order', 0, () => {
      // Arrange
      const first = buildShareEvent();
      first.name = 'first';
      first.dayOffset = 2;
      first.sortOrder = 1;
      const second = buildShareEvent();
      second.name = 'second';
      second.dayOffset = 1;
      second.sortOrder = 5;
      const third = buildShareEvent();
      third.name = 'third';
      third.dayOffset = 1;
      third.sortOrder = 1;
      // Act
      const sorted = sortPlanListShareEvents([first, second, third]);
      // Assert
      expect(sorted[0].name).assertEqual('third');
      expect(sorted[1].name).assertEqual('second');
      expect(sorted[2].name).assertEqual('first');
    });

    it('boundary: plan_list_share_item_should_floor_duration_to_single_decimal_hour', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.duration = 66;
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].duration).assertEqual(1.1);
    });

    it('invalid: plan_list_share_item_should_fallback_name_and_location_when_blank', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.name = '  ';
      event.address = ' ';
      event.duration = 0;
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].name).assertEqual('未命名地点');
      expect(items[0].location).assertEqual('待补充地点');
      expect(items[0].duration).assertEqual(0.5);
    });

    it('conflict: plan_list_share_icon_should_still_prefer_star_when_anchor_and_priority_conflict', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.priority = 1;
      event.lockStatus = 1;
      event.type = 'ANCHOR';
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].icon).assertEqual('⭐');
    });

    it('regression: td-20260418-plan_list_share_item_should_clamp_negative_day_offset_to_zero', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.dayOffset = -9;
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].dayOffset).assertEqual(0);
    });

    it('combined: plan_list_share_items_should_apply_sort_and_time_resolution_together', 0, () => {
      // Arrange
      const early = buildShareEvent();
      early.name = 'early';
      early.dayOffset = 0;
      early.sortOrder = 1;
      early.fixedStartTime = '08:00';
      early.duration = 30;
      const late = buildShareEvent();
      late.name = 'late';
      late.dayOffset = 0;
      late.sortOrder = 2;
      late.fixedStartTime = '09:30';
      late.duration = 90;
      // Act
      const items = buildPlanListShareEventItems([late, early]);
      // Assert
      expect(items[0].name).assertEqual('early');
      expect(items[0].startTime).assertEqual('08:00');
      expect(items[0].endTime).assertEqual('08:30');
      expect(items[1].name).assertEqual('late');
      expect(items[1].endTime).assertEqual('11:00');
    });

    it('boundary: plan_list_reprompt_should_allow_first_prompt_even_when_cooldown_not_met', 0, () => {
      // Arrange
      const now = 1000;
      const lastPromptAt = 2000;
      const cooldownMs = 10 * 60 * 1000;
      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, false, cooldownMs);
      // Assert
      expect(allowed).assertTrue();
    });

    it('invalid: plan_list_reprompt_should_reject_future_last_prompt_when_already_prompted', 0, () => {
      // Arrange
      const now = 1000;
      const lastPromptAt = 2000;
      const cooldownMs = 10 * 60 * 1000;

      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, true, cooldownMs);

      // Assert
      expect(allowed).assertFalse();
    });

    it('boundary: plan_list_share_start_should_use_computed_time_when_fixed_time_missing', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.fixedStartTime = '';
      event.computedStartTime = '18:45';
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('18:45');
    });

    it('regression: plan_list_share_sort_should_not_mutate_source_order', 0, () => {
      // Arrange
      const first = buildShareEvent();
      first.name = 'first';
      first.dayOffset = 2;
      first.sortOrder = 1;
      const second = buildShareEvent();
      second.name = 'second';
      second.dayOffset = 0;
      second.sortOrder = 1;
      const source: TravelPlanItem[] = [first, second];
      // Act
      const sorted = sortPlanListShareEvents(source);
      // Assert
      expect(sorted[0].name).assertEqual('second');
      expect(source[0].name).assertEqual('first');
    });

    it('combined: plan_list_share_item_should_floor_fractional_duration_and_day_offset', 0, () => {
      // Arrange
      const event = buildShareEvent();
      event.name = 'fractional';
      event.dayOffset = 2.8;
      event.duration = 95.9;
      event.fixedStartTime = '07:10';
      // Act
      const items = buildPlanListShareEventItems([event]);
      // Assert
      expect(items[0].dayOffset).assertEqual(2);
      expect(items[0].duration).assertEqual(1.6);
      expect(items[0].endTime).assertEqual('08:45');
    });

    it('normal: plan_list_instance_should_convert_sort_and_palette_without_service_dependency', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const early = buildShareEvent();
      const late = buildShareEvent();
      early.name = 'early';
      early.dayOffset = 0;
      early.sortOrder = 1;
      late.name = 'late';
      late.dayOffset = 1;
      late.sortOrder = 0;
      page.effectiveTheme = 'dark';

      // Act
      const sorted = page.sortEventsForShare([late, early]);
      const shareItems = page.convertToShareEvents([late, early]);
      const canPrompt = page.canRepromptPermission(2000, 1000, true);
      const palette = page.getThemePalette();

      // Assert
      expect(sorted[0].name).assertEqual('early');
      expect(shareItems.length).assertEqual(2);
      expect(canPrompt).assertFalse();
      expect(palette.textPrimary !== undefined).assertTrue();
    });

    it('boundary: plan_list_instance_should_consume_empty_and_invalid_notification_payload_safely', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);

      // Act
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '');
      page.consumeNotificationNavRoute();
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, '{bad_json');
      page.consumeNotificationNavRoute();
      const cleared = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? 'x';

      // Assert
      expect(uiContext.router.pushedUrls.length).assertEqual(0);
      expect(cleared).assertEqual('');
    });

    it('regression: plan_list_instance_should_route_notification_to_existing_plan_and_clear_payload', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const payload = new PlanListNotificationPayloadTest();
      payload.planId = 42;
      payload.eventId = 7;
      payload.forceCompanionMode = true;
      page.planList = [buildPlanListPlanForTest(42, 'route plan')];
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, JSON.stringify(payload));

      // Act
      page.consumeNotificationNavRoute();
      const cleared = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? 'x';

      // Assert
      expect(uiContext.router.pushedUrls.length).assertEqual(1);
      expect(uiContext.router.pushedUrls[0]).assertEqual('pages/Index');
      expect(cleared).assertEqual('');
    });

    it('combined: plan_list_instance_should_render_list_and_open_hard_delete_alert', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const plan = buildPlanListPlanForTest(77, 'render plan');
      page.planList = [plan];
      page.isRefreshing = false;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      let threw = false;

      // Act
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      page.handleHardDelete(plan);

      // Assert
      expect(threw).assertFalse();
      expect(uiContext.alertCount).assertEqual(1);
      expect(uiContext.lastAlert !== null).assertTrue();
    });

    it('normal: plan_list_instance_load_and_execute_mutations_should_use_injected_plan_service', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const service = new PlanListPlanServiceMockTest();
      service.visiblePlans = [buildPlanListPlanForTest(91, 'loaded')];
      Reflect.set(page as Object, 'planService', service as Object);

      // Act
      await page.loadPlans();
      await page.executeArchive(91);
      await page.executeSoftDelete(91);

      // Assert
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].title).assertEqual('loaded');
      expect(service.archiveIds.length).assertEqual(1);
      expect(service.softDeleteIds.length).assertEqual(1);
    });

    it('boundary: plan_list_instance_pull_refresh_should_ignore_reentrant_refresh', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const service = new PlanListPlanServiceMockTest();
      const coordinator = new PlanListArrivalCoordinatorMockTest();
      page.isRefreshing = true;
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);

      // Act
      await page.handlePullRefresh();

      // Assert
      expect(service.arrivalCheckReasons.length).assertEqual(0);
      expect(coordinator.consumeCount).assertEqual(0);
      expect(page.isRefreshing).assertTrue();
    });

    it('combined: plan_list_instance_pull_refresh_should_reload_check_arrival_and_reset_flag', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const service = new PlanListPlanServiceMockTest();
      const coordinator = new PlanListArrivalCoordinatorMockTest();
      service.visiblePlans = [buildPlanListPlanForTest(92, 'refresh')];
      page.isRefreshing = false;
      page.planList = [];
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);

      // Act
      await page.handlePullRefresh();

      // Assert
      expect(page.isRefreshing).assertFalse();
      expect(page.planList.length).assertEqual(1);
      expect(service.arrivalCheckReasons.length).assertEqual(1);
      expect(coordinator.consumeCount).assertEqual(1);
    });

    it('combined: plan_list_pull_refresh_callbacks_should_resolve_title_and_forward_show_home', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const service = new PlanListPlanServiceMockTest();
      const coordinator = new PlanListArrivalCoordinatorMockTest();
      const payload = new PlanListArrivalPayloadMockTest();
      const shownTitles: string[] = [];
      payload.planId = 222;
      payload.eventId = 12;
      payload.placeName = 'West Lake';
      service.visiblePlans = [buildPlanListPlanForTest(222, 'refresh_title_plan')];
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);
      Reflect.set(page as Object, 'showArrivalReminderOnHome', (_payload: Object, title: string): void => {
        shownTitles.push(title);
      });

      // Act
      await page.handlePullRefresh();
      const options = coordinator.lastConsumeOptions as Record<string, Object>;
      const resolvePlanTitle = Reflect.get(options, 'resolvePlanTitle') as (planId: number) => string;
      const onShow = Reflect.get(options, 'onShow') as (payload: Object, title: string) => void;
      const knownTitle = resolvePlanTitle(222);
      const unknownTitle = resolvePlanTitle(999);
      onShow(payload as Object, knownTitle);

      // Assert
      expect(knownTitle).assertEqual('refresh_title_plan');
      expect(unknownTitle).assertEqual('行程详情');
      expect(shownTitles.length).assertEqual(1);
      expect(shownTitles[0]).assertEqual('refresh_title_plan');
    });

    it('combined: plan_list_pull_refresh_should_pass_dialog_flag_and_fallback_title_to_arrival_coordinator', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const service = new PlanListPlanServiceMockTest();
      const coordinator = new PlanListArrivalCoordinatorMockTest();
      const payload = new PlanListArrivalPayloadMockTest();
      const shownTitles: string[] = [];
      page.isArrivalDialogOpen = true;
      payload.planId = 0;
      payload.eventId = 21;
      payload.placeName = 'Unknown Place';
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);
      Reflect.set(page as Object, 'showArrivalReminderOnHome', (_payload: Object, title: string): void => {
        shownTitles.push(title);
      });

      // Act
      await page.handlePullRefresh();
      const options = coordinator.lastConsumeOptions as Record<string, Object>;
      const isDialogOpen = Reflect.get(options, 'isDialogOpen') as boolean;
      const resolvePlanTitle = Reflect.get(options, 'resolvePlanTitle') as (planId: number) => string;
      const onShow = Reflect.get(options, 'onShow') as (payload: Object, title: string) => void;
      const fallbackTitle = resolvePlanTitle(404);
      onShow(payload as Object, fallbackTitle);

      // Assert
      expect(isDialogOpen).assertTrue();
      expect(fallbackTitle).assertEqual('行程详情');
      expect(shownTitles.length).assertEqual(1);
      expect(shownTitles[0]).assertEqual('行程详情');
    });

    it('combined: plan_list_instance_should_redirect_login_or_start_home_flow_based_on_session', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const authFacade = new PlanListAuthFacadeMockTest();
      const service = new PlanListPlanServiceMockTest();
      let bindCount = 0;
      let consumeCount = 0;
      let promptCount = 0;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'authFacade', authFacade as Object);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'loadPlans', async (): Promise<void> => {
        bindCount += 1;
      });
      Reflect.set(page as Object, 'bindArrivalReminderSubscription', (): void => {
        bindCount += 1;
      });
      Reflect.set(page as Object, 'consumeNotificationNavRoute', (): void => {
        consumeCount += 1;
      });
      Reflect.set(page as Object, 'ensureArrivalPermissionPromptOnFirstEntry', async (): Promise<void> => {
        promptCount += 1;
      });

      // Act
      authFacade.session = null;
      page.onPageShow();
      await Promise.resolve();
      const readySession = new PlanListSessionMockTest();
      readySession.accountId = 'acc_ready';
      authFacade.session = readySession;
      page.onPageShow();
      await Promise.resolve();

      // Assert
      expect(uiContext.router.replacedUrls.length).assertEqual(1);
      expect(uiContext.router.replacedUrls[0]).assertEqual('pages/LoginPage');
      expect(service.startArrivalEngineCount).assertEqual(1);
      expect(bindCount).assertEqual(2);
      expect(consumeCount).assertEqual(1);
      expect(promptCount).assertEqual(1);
      expect(authFacade.bindCount).assertEqual(2);
    });

    it('combined: plan_list_instance_should_cleanup_on_disappear_and_run_hard_delete_confirm_action', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      const plan = buildPlanListPlanForTest(108, 'hard_delete_plan');
      let unsubscribed = 0;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'loadPlans', async (): Promise<void> => {});
      Reflect.set(page as Object, 'arrivalReminderUnsubscribe', (): void => {
        unsubscribed += 1;
      });

      // Act
      page.aboutToDisappear();
      page.handleHardDelete(plan);
      await (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();

      // Assert
      expect(unsubscribed).assertEqual(1);
      expect(service.stopArrivalEngineCount).assertEqual(1);
      expect(service.hardDeleteIds.length).assertEqual(1);
      expect(service.hardDeleteIds[0]).assertEqual(108);
    });

    it('combined: plan_list_arrival_dialog_actions_should_acknowledge_and_route', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const coordinator = new PlanListArrivalCoordinatorMockTest();
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);
      const payload = new PlanListArrivalPayloadMockTest();
      payload.seq = 1;
      payload.planId = 66;
      payload.eventId = 9;
      payload.placeName = 'West Lake';
      payload.distanceMeters = 0;
      payload.triggerAt = 100;

      // Act
      page.showArrivalReminderOnHome(payload as Object, 'Arrival Plan');
      (uiContext.lastAlert as PlanListAlertOptionsTest).primaryButton.action();
      page.showArrivalReminderOnHome(payload as Object, 'Arrival Plan');
      (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();
      await Promise.resolve();

      // Assert
      expect(uiContext.alertCount).assertEqual(2);
      expect(coordinator.ackEventIds.length).assertEqual(2);
      expect(coordinator.ackActions[0]).assertEqual('dismiss');
      expect(coordinator.ackActions[1]).assertEqual('open_page');
      expect(uiContext.router.pushedUrls.length).assertEqual(1);
      expect(uiContext.router.pushedUrls[0]).assertEqual('pages/Index');
    });

    it('combined: plan_list_permission_prompts_should_cover_notification_and_location_secondary_actions', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      const toastMessages: string[] = [];
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });

      // Act
      service.notifyEnabled = false;
      await page.ensureNotificationPermissionPrompt(new Object());
      await (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();
      service.notifyRequestReject = new Error('notify_failed');
      await page.ensureNotificationPermissionPrompt(new Object());
      await (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();

      service.locationGranted = false;
      service.locationRequestResult = true;
      await page.ensureLocationPermissionPrompt(new Object());
      await (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();
      service.locationRequestResult = false;
      await page.ensureLocationPermissionPrompt(new Object());
      await (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();
      service.locationRequestThrow = new Error('location_failed');
      await page.ensureLocationPermissionPrompt(new Object());
      await (uiContext.lastAlert as PlanListAlertOptionsTest).secondaryButton.action();

      // Assert
      expect(uiContext.alertCount).assertEqual(5);
      expect(toastMessages.includes('已发起通知授权请求')).assertTrue();
      expect(toastMessages.includes('拉起通知授权失败，请在系统设置中手动开启')).assertTrue();
      expect(toastMessages.includes('定位权限已授权')).assertTrue();
      expect(toastMessages.includes('未获得定位权限，到达提醒可能无法触发')).assertTrue();
      expect(toastMessages.includes('定位授权失败，请到系统设置手动开启')).assertTrue();
    });
    it('combined: plan_list_permission_prompts_should_cover_primary_noop_and_enabled_granted_early_return', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);

      // Act
      service.notifyEnabled = true;
      await page.ensureNotificationPermissionPrompt(new Object());
      service.notifyEnabled = false;
      await page.ensureNotificationPermissionPrompt(new Object());
      (uiContext.lastAlert as PlanListAlertOptionsTest).primaryButton.action();
      service.locationGranted = true;
      await page.ensureLocationPermissionPrompt(new Object());
      service.locationGranted = false;
      await page.ensureLocationPermissionPrompt(new Object());
      (uiContext.lastAlert as PlanListAlertOptionsTest).primaryButton.action();

      // Assert
      expect(uiContext.alertCount).assertEqual(2);
      expect(service.notifyEnabled).assertFalse();
      expect(service.locationGranted).assertFalse();
    });

    it('boundary: plan_list_private_start_and_bind_should_swallow_engine_error_and_replace_subscription', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      const coordinator = new PlanListArrivalCoordinatorMockTest();
      let previousUnsubscribed = 0;
      const shownTitles: string[] = [];
      page.planList = [buildPlanListPlanForTest(301, 'bound_title')];
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'arrivalCoordinator', coordinator as Object);
      Reflect.set(page as Object, 'showArrivalReminderOnHome', (_payload: Object, title: string): void => {
        shownTitles.push(title);
      });
      Reflect.set(page as Object, 'arrivalReminderUnsubscribe', (): void => {
        previousUnsubscribed += 1;
      });
      Reflect.set(service as Object, 'startArrivalEngine', (): void => {
        throw new Error('engine_failed');
      });

      // Act
      page.startGlobalArrivalEngine();
      page.bindArrivalReminderSubscription();
      const options = coordinator.lastSubscribeOptions as Record<string, Object>;
      const isDialogOpen = Reflect.get(options, 'isDialogOpen') as () => boolean;
      const resolvePlanTitle = Reflect.get(options, 'resolvePlanTitle') as (planId: number) => string;
      const onShowHome = Reflect.get(options, 'onShowHome') as (payload: Object, title: string) => void;
      page.isArrivalDialogOpen = true;
      onShowHome(new PlanListArrivalPayloadMockTest() as Object, resolvePlanTitle(301));

      // Assert
      expect(previousUnsubscribed).assertEqual(1);
      expect(coordinator.subscribePlanCount).assertEqual(1);
      expect(coordinator.lastSubscribeKey).assertEqual('*');
      expect(isDialogOpen()).assertTrue();
      expect(resolvePlanTitle(301)).assertEqual('bound_title');
      expect(resolvePlanTitle(999)).assertEqual('行程详情');
      expect(shownTitles.length).assertEqual(1);
      expect(shownTitles[0]).assertEqual('bound_title');
    });

    it('regression: plan_list_first_entry_prompt_should_mark_and_dispatch_missing_permissions_once', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      const promptState = new PlanListPromptStateTest();
      let notifyPromptCount = 0;
      let locationPromptCount = 0;
      page.lastNotifyPermissionPromptAt = 0;
      page.lastLocationPermissionPromptAt = 0;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(service as Object, 'getArrivalPromptState', async (_context: Object): Promise<PlanListPromptStateTest> => {
        return promptState;
      });
      Reflect.set(page as Object, 'ensureNotificationPermissionPrompt', async (_context: Object): Promise<void> => {
        notifyPromptCount += 1;
      });
      Reflect.set(page as Object, 'ensureLocationPermissionPrompt', async (_context: Object): Promise<void> => {
        locationPromptCount += 1;
      });
      service.notifyEnabled = false;
      service.locationGranted = false;

      // Act
      await page.ensureArrivalPermissionPromptOnFirstEntry();

      // Assert
      expect(service.notifyPromptedMarkCount).assertEqual(1);
      expect(service.locationPromptedMarkCount).assertEqual(1);
      expect(notifyPromptCount).assertEqual(1);
      expect(locationPromptCount).assertEqual(1);
      expect(page.lastNotifyPermissionPromptAt > 0).assertTrue();
      expect(page.lastLocationPermissionPromptAt > 0).assertTrue();
    });

    it('boundary: plan_list_first_entry_prompt_should_skip_mark_and_dialog_when_reprompt_cooldown_not_met', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      const promptState = new PlanListPromptStateTest();
      promptState.notifyPrompted = true;
      promptState.locationPrompted = true;
      const now = Date.now();
      page.lastNotifyPermissionPromptAt = now;
      page.lastLocationPermissionPromptAt = now;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(service as Object, 'getArrivalPromptState', async (_context: Object): Promise<PlanListPromptStateTest> => {
        return promptState;
      });
      service.notifyEnabled = false;
      service.locationGranted = false;

      // Act
      await page.ensureArrivalPermissionPromptOnFirstEntry();

      // Assert
      expect(service.notifyPromptedMarkCount).assertEqual(0);
      expect(service.locationPromptedMarkCount).assertEqual(0);
      expect(uiContext.alertCount).assertEqual(0);
      expect(page.lastNotifyPermissionPromptAt).assertEqual(now);
      expect(page.lastLocationPermissionPromptAt).assertEqual(now);
    });

    it('combined: plan_list_first_entry_prompt_should_reprompt_without_re_marking_after_cooldown', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const service = new PlanListPlanServiceMockTest();
      const promptState = new PlanListPromptStateTest();
      promptState.notifyPrompted = true;
      promptState.locationPrompted = true;
      let notifyPromptCount = 0;
      let locationPromptCount = 0;
      page.lastNotifyPermissionPromptAt = 1;
      page.lastLocationPermissionPromptAt = 1;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(service as Object, 'getArrivalPromptState', async (_context: Object): Promise<PlanListPromptStateTest> => {
        return promptState;
      });
      Reflect.set(page as Object, 'ensureNotificationPermissionPrompt', async (_context: Object): Promise<void> => {
        notifyPromptCount += 1;
      });
      Reflect.set(page as Object, 'ensureLocationPermissionPrompt', async (_context: Object): Promise<void> => {
        locationPromptCount += 1;
      });
      service.notifyEnabled = false;
      service.locationGranted = false;

      // Act
      await page.ensureArrivalPermissionPromptOnFirstEntry();

      // Assert
      expect(service.notifyPromptedMarkCount).assertEqual(0);
      expect(service.locationPromptedMarkCount).assertEqual(0);
      expect(notifyPromptCount).assertEqual(1);
      expect(locationPromptCount).assertEqual(1);
      expect(page.lastNotifyPermissionPromptAt > 1).assertTrue();
      expect(page.lastLocationPermissionPromptAt > 1).assertTrue();
    });

    it('normal: plan_list_export_should_truncate_share_events_and_open_dialog', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const toastMessages: string[] = [];
      let opened = false;
      let openedTotalEvents = 0;
      let openedTotalDays = 0;
      const exportPatch = new PlanListStaticPatchTest(
        PlanImportExportService as Object,
        'exportPlanToJson',
        (async (_planId: number): Promise<string> => 'json_plan_list_test') as Object
      );
      const parsePatch = new PlanListStaticPatchTest(
        PlanSerializer as Object,
        'deserializePlan',
        ((_json: string): PlanListParsedPayloadTest => buildParsedPlanForExportTest(55)) as Object
      );
      const compressPatch = new PlanListStaticPatchTest(
        CompactPlanSerializer as Object,
        'compressForShare',
        ((_meta: Object, events: TravelPlanItem[]): string => `compressed-${events.length}`) as Object
      );
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });
      Reflect.set(page as Object, 'openExportDialog', (payload: Object): void => {
        opened = true;
        openedTotalEvents = Number(Reflect.get(payload, 'totalEvents'));
        openedTotalDays = Number(Reflect.get(payload, 'totalDays'));
      });

      // Act
      await page.exportPlanAsJson(buildPlanListPlanForTest(3001, 'share_target'));
      compressPatch.restore();
      parsePatch.restore();
      exportPatch.restore();

      // Assert
      expect(page.exportJsonText).assertEqual('compressed-50');
      expect(opened).assertTrue();
      expect(openedTotalEvents).assertEqual(50);
      expect(openedTotalDays).assertEqual(17);
      expect(toastMessages.length).assertEqual(1);
    });

    it('boundary: plan_list_export_should_keep_all_events_without_truncation_when_limit_not_exceeded', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const toastMessages: string[] = [];
      let openedTotalEvents = 0;
      const exportPatch = new PlanListStaticPatchTest(
        PlanImportExportService as Object,
        'exportPlanToJson',
        (async (_planId: number): Promise<string> => 'json_plan_list_not_truncated') as Object
      );
      const parsePatch = new PlanListStaticPatchTest(
        PlanSerializer as Object,
        'deserializePlan',
        ((_json: string): PlanListParsedPayloadTest => buildParsedPlanForExportTest(50)) as Object
      );
      const compressPatch = new PlanListStaticPatchTest(
        CompactPlanSerializer as Object,
        'compressForShare',
        ((_meta: Object, events: TravelPlanItem[]): string => `compressed-${events.length}`) as Object
      );
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });
      Reflect.set(page as Object, 'openExportDialog', (payload: Object): void => {
        openedTotalEvents = Number(Reflect.get(payload, 'totalEvents'));
      });

      // Act
      await page.exportPlanAsJson(buildPlanListPlanForTest(3003, 'share_full'));
      compressPatch.restore();
      parsePatch.restore();
      exportPatch.restore();

      // Assert
      expect(page.exportJsonText).assertEqual('compressed-50');
      expect(openedTotalEvents).assertEqual(50);
      expect(toastMessages.length).assertEqual(0);
    });

    it('invalid: plan_list_export_should_fallback_to_toast_when_service_throws', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const toastMessages: string[] = [];
      const exportPatch = new PlanListStaticPatchTest(
        PlanImportExportService as Object,
        'exportPlanToJson',
        (async (_planId: number): Promise<string> => {
          throw new Error('export_failed');
        }) as Object
      );
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });

      // Act
      await page.exportPlanAsJson(buildPlanListPlanForTest(3002, 'share_fail'));
      exportPatch.restore();

      // Assert
      expect(toastMessages.length).assertEqual(1);
    });

    it('combined: plan_list_import_should_handle_cancel_and_reload_successfully', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const service = new PlanListPlanServiceMockTest();
      const toastMessages: string[] = [];
      service.visiblePlans = [buildPlanListPlanForTest(401, 'imported_plan')];
      Reflect.set(page as Object, 'planService', service as Object);
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });
      const importPatch = new PlanListStaticPatchTest(
        PlanImportExportService as Object,
        'importPlanFromJson',
        (async (jsonText: string, _cancelToken: Object): Promise<number> => {
          if (jsonText === 'cancel') {
            throw new Error('import_cancelled');
          }
          return 401;
        }) as Object
      );

      // Act
      await page.importPlanFromJson('cancel', new Object());
      await page.importPlanFromJson('success', new Object());
      importPatch.restore();

      // Assert
      expect(toastMessages.length).assertEqual(2);
      expect(page.planList.length).assertEqual(1);
      expect(page.planList[0].id).assertEqual(401);
    });

    it('invalid: plan_list_import_should_show_generic_failure_toast_when_reason_is_not_cancelled', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const toastMessages: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });
      const importPatch = new PlanListStaticPatchTest(
        PlanImportExportService as Object,
        'importPlanFromJson',
        (async (_jsonText: string, _cancelToken: Object): Promise<number> => {
          throw new Error('import_bad_payload');
        }) as Object
      );

      // Act
      await page.importPlanFromJson('bad_payload', new Object());
      importPatch.restore();

      // Assert
      expect(toastMessages.length).assertEqual(1);
      expect(toastMessages[0]).assertEqual('导入失败：数据格式不合法或内容超限');
    });

    it('invalid: plan_list_import_should_stringify_non_error_failure_reason', 0, async () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const toastMessages: string[] = [];
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessages.push(message);
      });
      const importPatch = new PlanListStaticPatchTest(
        PlanImportExportService as Object,
        'importPlanFromJson',
        (async (_jsonText: string, _cancelToken: Object): Promise<number> => {
          return Promise.reject('plain_failure');
        }) as Object
      );

      // Act
      await page.importPlanFromJson('plain_failure_payload', new Object());
      importPatch.restore();

      // Assert
      expect(toastMessages.length).assertEqual(1);
      expect(toastMessages[0].length > 0).assertTrue();
    });

    it('invalid: plan_list_notification_route_should_fallback_title_and_swallow_router_error', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const payload = new PlanListNotificationPayloadTest();
      payload.planId = 88;
      payload.eventId = 0;
      payload.forceCompanionMode = false;
      uiContext.router.shouldThrowOnPush = true;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, JSON.stringify(payload));

      // Act
      page.consumeNotificationNavRoute();
      const cleared = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? 'x';

      // Assert
      expect(cleared).assertEqual('');
      expect(uiContext.router.pushedUrls.length).assertEqual(0);
      expect(uiContext.router.pushedOptions.length).assertEqual(0);
    });

    it('boundary: plan_list_notification_route_should_clear_invalid_plan_id_without_navigation', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateTest;
      const uiContext = new PlanListUiContextMockTest();
      const payload = new PlanListNotificationPayloadTest();
      payload.planId = 0;
      payload.eventId = 12;
      payload.forceCompanionMode = true;
      Reflect.set(page as Object, 'getUIContext', (): PlanListUiContextMockTest => uiContext);
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD, JSON.stringify(payload));

      // Act
      page.consumeNotificationNavRoute();
      const cleared = AppStorage.get<string>(AppStorageKeys.NOTIFICATION_NAV_PAYLOAD) ?? 'x';

      // Assert
      expect(cleared).assertEqual('');
      expect(uiContext.router.pushedUrls.length).assertEqual(0);
      expect(uiContext.router.pushedOptions.length).assertEqual(0);
    });
  });
}
