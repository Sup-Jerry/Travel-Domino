import { describe, it, expect } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { PlanItem } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
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
  effectiveTheme: string;
  getThemePalette(): PlanListPaletteTest;
  canRepromptPermission(now: number, lastPromptAt: number, hasPromptedBefore: boolean): boolean;
  convertToShareEvents(events: TravelPlanItem[]): Object[];
  sortEventsForShare(events: TravelPlanItem[]): TravelPlanItem[];
  consumeNotificationNavRoute(): void;
  loadPlans(): Promise<void>;
  handlePullRefresh(): Promise<void>;
  executeArchive(planId: number): Promise<void>;
  executeSoftDelete(planId: number): Promise<void>;
  handleHardDelete(item: PlanItem): void;
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

  pushUrl(options: PlanListRouteOptionsTest): void {
    this.pushedUrls.push(options.url);
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

class PlanListPlanServiceMockTest {
  visiblePlans: PlanItem[] = [];
  archiveIds: number[] = [];
  softDeleteIds: number[] = [];
  hardDeleteIds: number[] = [];
  arrivalCheckReasons: string[] = [];
  stopArrivalEngineCount: number = 0;

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

  stopArrivalEngine(): void {
    this.stopArrivalEngineCount += 1;
  }

  async getArrivalPromptState(_context: Object): Promise<PlanListPromptStateTest> {
    return new PlanListPromptStateTest();
  }

  async isNotificationEnabled(): Promise<boolean> {
    return true;
  }

  async isLocationPermissionGranted(): Promise<boolean> {
    return true;
  }
}

class PlanListArrivalCoordinatorMockTest {
  consumeCount: number = 0;

  consumeOnHome(_options: Object): void {
    this.consumeCount += 1;
  }
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
  });
}
