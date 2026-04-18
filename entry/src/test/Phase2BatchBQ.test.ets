import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AuthApiResponse, AuthSessionPayload, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { AuthGateway } from '../main/ets/infrastructure/auth/AuthGateway';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';
import { ArrivalReminderCoordinator } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { ArrivalLiveActivityBridge } from '../main/ets/common/utils/ArrivalLiveActivityBridge';
import { NotificationGateway } from '../main/ets/infrastructure/adapters/NotificationGateway';
import { AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';
import { AppConfig } from '../main/ets/common/utils/AppConfig';

interface TxStoreBQ {
  beginCount: number;
  commitCount: number;
  rollbackCount: number;
  beginTransaction: () => void;
  commit: () => void;
  rollBack: () => void;
}

interface ParsedPlanBQ {
  plan: {
    title: string;
    startDate: number;
    status: number;
    enableAutoAmapRoute: number;
  };
  events: TravelPlanItem[];
}

class HooksBQ {
  private readonly list: Object[] = [];
  public keep(owner: Object, key: string): void {
    this.list.push({ owner, key, value: Reflect.get(owner, key) as Object });
  }
  public set(owner: Object, key: string, value: Object): void {
    Reflect.set(owner, key, value);
  }
  public restoreAll(): void {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const item = this.list[i] as Record<string, Object>;
      Reflect.set(item['owner'], String(item['key']), item['value']);
    }
  }
}

function createStoreBQ(): TxStoreBQ {
  const store: TxStoreBQ = {
    beginCount: 0,
    commitCount: 0,
    rollbackCount: 0,
    beginTransaction: (): void => { store.beginCount += 1; },
    commit: (): void => { store.commitCount += 1; },
    rollBack: (): void => { store.rollbackCount += 1; }
  };
  return store;
}

function buildParsedPlanBQ(): ParsedPlanBQ {
  return {
    plan: { title: 'P', startDate: 1710000000000, status: 1, enableAutoAmapRoute: 1 },
    events: [{
      name: 'A', note: '', duration: 60, type: 'FLOW', preTravelMinutes: -1, sortOrder: 0, status: 1, lockStatus: 0,
      fixedStartTime: '', dayOffset: 0, itemType: 0, priority: 0, transportMode: 2, travelMode: 2, isTravelManual: 0,
      source: 0, delFlag: 0, groupId: 0, address: '', aiReasoning: '', latitude: 31.2, longitude: 121.5,
      actualStartTime: 0, actualEndTime: 0, completionStatus: 0
    }]
  };
}

function buildSessionBQ(expireAt: number): UserSession {
  const s = new UserSession();
  s.accountId = 'acc_bq';
  s.userId = 'uid_bq';
  s.isGuest = false;
  s.loginMethod = 'HUAWEI';
  s.accessToken = 'token_bq';
  s.refreshToken = 'refresh_bq';
  s.expireAt = expireAt;
  s.sessionId = 'sid_bq';
  return s;
}

function createStartableEventBQ(id: number): EventEntity {
  const e = new EventEntity();
  e.id = id;
  e.name = `event_${id}`;
  e.plan_id = 11;
  e.status = 1;
  e.completion_status = EventEntity.STATE_PENDING;
  e.latitude = 31.2;
  e.longitude = 121.5;
  e.fixed_start_time = '';
  e.dynamic_start_time = Date.now() + 1000;
  return e;
}

export default function phase2BatchBQTest() {
  describe('phase2BatchBQ_plan_avatar_session', () => {
    it('normal: import_should_use_default_resolve_deps_chain', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      const store = createStoreBQ();
      let inserted = 0;
      hooks.keep(Object(PlanSerializer), 'deserializePlan');
      hooks.keep(Object(PlanSerializer), 'normalizeImportEvent');
      hooks.keep(Object(RdbHelper), 'getInstance');
      hooks.keep(Object(PlanRepositoryImpl), 'createPlan');
      hooks.keep(Object(PlanRepositoryImpl), 'updateAutoAmapRoute');
      hooks.keep(Object(PlanRepositoryImpl), 'updatePlanStatus');
      hooks.keep(Object(EventRepositoryImpl), 'insertEvent');
      hooks.set(Object(PlanSerializer), 'deserializePlan', ((_raw: string): ParsedPlanBQ => buildParsedPlanBQ()) as Object);
      hooks.set(Object(PlanSerializer), 'normalizeImportEvent', ((item: TravelPlanItem): TravelPlanItem => item) as Object);
      hooks.set(Object(RdbHelper), 'getInstance', (() => ({ getRdbStore: (): Object => store as Object })) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'createPlan', (async (): Promise<number> => 9001) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'updateAutoAmapRoute', (async (): Promise<void> => {}) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'updatePlanStatus', (async (): Promise<void> => {}) as Object);
      hooks.set(Object(EventRepositoryImpl), 'insertEvent', (async (): Promise<number> => {
        inserted += 1;
        return inserted;
      }) as Object);
      PlanImportExportService.setDepsForTest(null);

      // Act
      const newPlanId = await PlanImportExportService.importPlanFromJson('{}');

      // Assert
      expect(newPlanId).assertEqual(9001);
      expect(store.beginCount).assertEqual(1);
      expect(store.commitCount).assertEqual(1);
      expect(inserted).assertEqual(1);
      hooks.restoreAll();
    });

    it('boundary: import_should_rollback_when_default_create_plan_returns_zero', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      const store = createStoreBQ();
      hooks.keep(Object(PlanSerializer), 'deserializePlan');
      hooks.keep(Object(PlanSerializer), 'normalizeImportEvent');
      hooks.keep(Object(RdbHelper), 'getInstance');
      hooks.keep(Object(PlanRepositoryImpl), 'createPlan');
      hooks.set(Object(PlanSerializer), 'deserializePlan', ((_raw: string): ParsedPlanBQ => buildParsedPlanBQ()) as Object);
      hooks.set(Object(PlanSerializer), 'normalizeImportEvent', ((item: TravelPlanItem): TravelPlanItem => item) as Object);
      hooks.set(Object(RdbHelper), 'getInstance', (() => ({ getRdbStore: (): Object => store as Object })) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'createPlan', (async (): Promise<number> => 0) as Object);
      PlanImportExportService.setDepsForTest(null);

      // Act
      let message = '';
      try {
        await PlanImportExportService.importPlanFromJson('{}');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('create_plan_failed');
      expect(store.rollbackCount).assertEqual(1);
      hooks.restoreAll();
    });

    it('invalid: import_should_throw_db_not_ready_when_default_store_is_null', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(PlanSerializer), 'deserializePlan');
      hooks.keep(Object(RdbHelper), 'getInstance');
      hooks.set(Object(PlanSerializer), 'deserializePlan', ((_raw: string): ParsedPlanBQ => buildParsedPlanBQ()) as Object);
      hooks.set(Object(RdbHelper), 'getInstance', (() => ({ getRdbStore: (): Object | null => null })) as Object);
      PlanImportExportService.setDepsForTest(null);

      // Act
      let message = '';
      try {
        await PlanImportExportService.importPlanFromJson('{}');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('db_not_ready');
      hooks.restoreAll();
    });

    it('normal: avatar_api_default_deps_should_sync_when_gateway_success', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AuthSessionStore), 'getAccessToken');
      hooks.keep(Object(AvatarUploadApi), 'readFileAsDataUrl');
      hooks.keep(Object(AuthGateway), 'updateAvatar');
      hooks.set(Object(AuthSessionStore), 'getAccessToken', (() => 'token_default_bq') as Object);
      hooks.set(Object(AvatarUploadApi), 'readFileAsDataUrl', ((_file: string, _mime: string): string => 'data:image/jpeg;base64,AA==') as Object);
      hooks.set(Object(AuthGateway), 'updateAvatar', (async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
        const data = new UpdateAvatarResult();
        data.avatarUrl = 'https://example.com/bq.jpg';
        const resp = new AuthApiResponse<UpdateAvatarResult>(data);
        resp.code = 0;
        return resp;
      }) as Object);
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar.jpg';

      // Act
      const result = await new AvatarUploadApi().uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('SYNCED');
      expect(String(result.remoteUrl || '')).assertEqual('https://example.com/bq.jpg');
      hooks.restoreAll();
    });

    it('boundary: avatar_api_default_deps_should_return_local_only_on_non_zero_code', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AuthSessionStore), 'getAccessToken');
      hooks.keep(Object(AvatarUploadApi), 'readFileAsDataUrl');
      hooks.keep(Object(AuthGateway), 'updateAvatar');
      hooks.set(Object(AuthSessionStore), 'getAccessToken', (() => 'token_default_bq') as Object);
      hooks.set(Object(AvatarUploadApi), 'readFileAsDataUrl', ((_file: string, _mime: string): string => 'data:image/jpeg;base64,AA==') as Object);
      hooks.set(Object(AuthGateway), 'updateAvatar', (async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
        const resp = new AuthApiResponse<UpdateAvatarResult>(new UpdateAvatarResult());
        resp.code = 401;
        return resp;
      }) as Object);
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar.jpg';

      // Act
      const result = await new AvatarUploadApi().uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('401');
      hooks.restoreAll();
    });

    it('invalid: avatar_api_default_deps_should_return_upload_exception_when_encode_failed', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AuthSessionStore), 'getAccessToken');
      hooks.keep(Object(AvatarUploadApi), 'readFileAsDataUrl');
      hooks.set(Object(AuthSessionStore), 'getAccessToken', (() => 'token_default_bq') as Object);
      hooks.set(Object(AvatarUploadApi), 'readFileAsDataUrl', ((_file: string, _mime: string): string => {
        throw new Error('encode_failed_bq');
      }) as Object);
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar.jpg';

      // Act
      const result = await new AvatarUploadApi().uploadAvatar(input);

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('UPLOAD_EXCEPTION');
      hooks.restoreAll();
    });

    it('normal: session_manager_should_delegate_save_and_memory_flags', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      let savedAccountId = '';
      let markCalled = 0;
      let clearCalled = 0;
      hooks.keep(Object(AuthSessionStore), 'saveSessionPersisted');
      hooks.keep(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogout');
      hooks.keep(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogout');
      hooks.keep(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogout');
      hooks.set(Object(AuthSessionStore), 'saveSessionPersisted', (async (_ctx: common.Context, payload: AuthSessionPayload): Promise<void> => {
        savedAccountId = payload.accountId;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogout', (() => { markCalled += 1; }) as Object);
      hooks.set(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogout', (() => { clearCalled += 1; }) as Object);
      hooks.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogout', (() => true) as Object);
      const manager = SessionManager.getInstance();

      // Act
      await manager.saveSessionPersisted({} as common.Context, buildSessionBQ(Date.now() + 30_000));
      manager.markSilentLoginBlockedAfterLogout();
      const blocked = manager.isSilentLoginBlockedAfterLogout();
      manager.clearSilentLoginBlockedAfterLogout();

      // Assert
      expect(savedAccountId).assertEqual('acc_bq');
      expect(markCalled).assertEqual(1);
      expect(clearCalled).assertEqual(1);
      expect(blocked).assertTrue();
      hooks.restoreAll();
    });

    it('boundary: session_manager_should_delegate_guest_and_persisted_block_flags', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      let markPersisted = 0;
      let clearPersisted = 0;
      hooks.keep(Object(AuthSessionStore), 'markGuestChosenPersisted');
      hooks.keep(Object(AuthSessionStore), 'hasGuestChosenPersisted');
      hooks.keep(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted');
      hooks.keep(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogoutPersisted');
      hooks.keep(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted');
      hooks.set(Object(AuthSessionStore), 'markGuestChosenPersisted', (async (): Promise<void> => {}) as Object);
      hooks.set(Object(AuthSessionStore), 'hasGuestChosenPersisted', (async (): Promise<boolean> => true) as Object);
      hooks.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted', (async (): Promise<void> => { markPersisted += 1; }) as Object);
      hooks.set(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogoutPersisted', (async (): Promise<void> => { clearPersisted += 1; }) as Object);
      hooks.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted', (async (): Promise<boolean> => false) as Object);
      const manager = SessionManager.getInstance();

      // Act
      await manager.markGuestChosen({} as common.Context);
      const guestChosen = await manager.hasGuestChosen({} as common.Context);
      await manager.markSilentLoginBlockedAfterLogoutPersisted({} as common.Context);
      await manager.clearSilentLoginBlockedAfterLogoutPersisted({} as common.Context);
      const blocked = await manager.isSilentLoginBlockedAfterLogoutPersisted({} as common.Context);

      // Assert
      expect(guestChosen).assertTrue();
      expect(markPersisted).assertEqual(1);
      expect(clearPersisted).assertEqual(1);
      expect(blocked).assertFalse();
      hooks.restoreAll();
    });

    it('conflict: session_manager_should_propagate_persisted_clear_failure', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AuthSessionStore), 'clearSessionPersisted');
      hooks.set(Object(AuthSessionStore), 'clearSessionPersisted', (async (): Promise<void> => {
        throw new Error('clear_failed_bq');
      }) as Object);

      // Act
      let message = '';
      try {
        await SessionManager.getInstance().clearSessionPersisted({} as common.Context);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('clear_failed_bq');
      hooks.restoreAll();
    });

    it('combined: coordinator_is_terminal_status_should_cover_normal_boundary_invalid', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const fn = Reflect.get(coordinator as Object, 'isTerminalStatus') as (status: PlanStatus) => boolean;

      // Act
      const completed = fn.call(coordinator, PlanStatus.COMPLETED);
      const cancelled = fn.call(coordinator, PlanStatus.CANCELLED);
      const ready = fn.call(coordinator, PlanStatus.READY);

      // Assert
      expect(completed).assertTrue();
      expect(cancelled).assertTrue();
      expect(ready).assertFalse();
    });
  });

  describe('phase2BatchBQ_arrival_engine_amap', () => {
    it('normal: engine_apply_dirty_plans_should_merge_active_snapshot', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(PlanRepositoryImpl), 'getPlanById');
      hooks.set(Object(PlanRepositoryImpl), 'getPlanById', (async (planId: number): Promise<Object | undefined> => {
        if (planId === 1) {
          return { id: 1, delFlag: 0, status: 0 };
        }
        return undefined;
      }) as Object);
      const engine = ArrivalReminderEngine.getInstance() as Object;
      const active = new Set<number>([2]);
      const dirty = new Set<number>([1, 2]);
      const fn = Reflect.get(engine, 'applyDirtyPlansToActiveSnapshot') as
        (activePlanIds: Set<number>, dirtyPlanIds: Set<number>) => Promise<void>;

      // Act
      await fn.call(engine, active, dirty);

      // Assert
      expect(active.has(1)).assertTrue();
      expect(active.has(2)).assertFalse();
      hooks.restoreAll();
    });

    it('boundary: engine_build_cache_should_count_and_filter_candidates', 0, () => {
      // Arrange
      const engine = ArrivalReminderEngine.getInstance() as Object;
      const now = Date.now();
      const plan = { id: 10, startDate: now };
      const events = buildParsedPlanBQ().events;
      const fn = Reflect.get(engine, 'buildPlanCandidateCache') as (plan: Object, events: TravelPlanItem[], now: number) => Object;

      // Act
      const cache = fn.call(engine, plan as Object, events, now) as Record<string, Object>;

      // Assert
      expect(Number(cache['scheduleCount'])).assertEqual(1);
      expect(Number(cache['pendingCount'])).assertEqual(1);
      expect(Number(cache['eligibleCount']) >= 0).assertTrue();
    });

    it('normal: engine_ensure_storage_defaults_should_call_store_and_live_init', 0, () => {
      // Arrange
      const hooks = new HooksBQ();
      let ensureCount = 0;
      let initCount = 0;
      hooks.keep(Object(ArrivalReminderStore), 'ensureDefaults');
      hooks.keep(Object(ArrivalLiveActivityBridge), 'init');
      hooks.set(Object(ArrivalReminderStore), 'ensureDefaults', (() => { ensureCount += 1; }) as Object);
      hooks.set(Object(ArrivalLiveActivityBridge), 'init', (() => { initCount += 1; }) as Object);
      const engine = ArrivalReminderEngine.getInstance() as Object;
      const fn = Reflect.get(engine, 'ensureStorageDefaults') as () => void;

      // Act
      fn.call(engine);

      // Assert
      expect(ensureCount).assertEqual(1);
      expect(initCount).assertEqual(1);
      hooks.restoreAll();
    });

    it('invalid: engine_ensure_clients_should_return_false_without_context', 0, () => {
      // Arrange
      const engine = ArrivalReminderEngine.getInstance() as Object;
      Reflect.set(engine, 'context', null);
      const fn = Reflect.get(engine, 'ensureClients') as () => boolean;

      // Act
      const ok = fn.call(engine);

      // Assert
      expect(ok).assertFalse();
    });

    it('combined: engine_private_helpers_should_cover_ready_pick_fire_and_parse', 0, () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(ArrivalReminderStore), 'nextSeq');
      hooks.keep(Object(ArrivalReminderStore), 'writePayload');
      hooks.keep(Object(NotificationGateway), 'updateScheduleNotification');
      hooks.set(Object(ArrivalReminderStore), 'nextSeq', (() => 7) as Object);
      let writeEventId = -1;
      hooks.set(Object(ArrivalReminderStore), 'writePayload', ((payload: Record<string, Object>): void => {
        writeEventId = Number(payload['eventId']);
      }) as Object);
      hooks.set(Object(NotificationGateway), 'updateScheduleNotification', (async (): Promise<void> => {}) as Object);

      const engine = ArrivalReminderEngine.getInstance() as Object;
      const event = createStartableEventBQ(41);
      Reflect.set(engine, 'eventPlanIdMap', new Map<number, number>([[41, 77]]));
      Reflect.set(engine, 'eventOrderMap', new Map<number, number>([[41, 0]]));
      Reflect.set(engine, 'eventTimeDeltaMap', new Map<number, number>([[41, 0]]));
      Reflect.set(engine, 'monitoredEvents', [event]);
      Reflect.set(engine, 'lastReminderByEvent', new Map<number, number>());

      const makeCustomId = Reflect.get(engine, 'makeCustomId') as (event: EventEntity) => string;
      const parseEventId = Reflect.get(engine, 'parseEventId') as (raw: string) => number;
      const pickBest = Reflect.get(engine, 'pickBestCandidate') as (ids: number[], location: Object, now: number) => EventEntity | null;
      const fire = Reflect.get(engine, 'fireReminder') as (event: EventEntity, location: Object, reason: string) => void;
      const eligible = Reflect.get(engine, 'getEligibleEvents') as () => EventEntity[];
      const coord = Reflect.get(engine, 'isValidCoordinate') as (lat: number, lng: number) => boolean;

      // Act
      const customId = makeCustomId.call(engine, event);
      const eventId = parseEventId.call(engine, customId);
      const invalidId = parseEventId.call(engine, 'bad');
      const picked = pickBest.call(engine, [41], { latitude: 31.2, longitude: 121.5 } as Object, Date.now());
      fire.call(engine, event, { latitude: 31.2, longitude: 121.5 } as Object, 'bq');
      const eligibleList = eligible.call(engine);
      const validCoord = coord.call(engine, 31.2, 121.5);
      const invalidCoord = coord.call(engine, 0, 0);

      // Assert
      expect(customId).assertEqual('77:41');
      expect(eventId).assertEqual(41);
      expect(invalidId).assertEqual(-1);
      expect(picked?.id ?? -1).assertEqual(41);
      expect(writeEventId).assertEqual(41);
      expect(eligibleList.length).assertEqual(1);
      expect(validCoord).assertTrue();
      expect(invalidCoord).assertFalse();
      hooks.restoreAll();
    });

    it('invalid: engine_evaluate_candidates_should_clear_pending_when_locked', 0, () => {
      // Arrange
      const engine = ArrivalReminderEngine.getInstance() as Object;
      Reflect.set(engine, 'lastLocation', { latitude: 31.2, longitude: 121.5 });
      Reflect.set(engine, 'pendingCandidateIds', new Set<number>([1]));
      Reflect.set(engine, 'reminderLockUntilTs', Date.now() + 60_000);
      const evaluate = Reflect.get(engine, 'evaluateCandidates') as (reason: string) => void;

      // Act
      evaluate.call(engine, 'lock_case');

      // Assert
      const pending = Reflect.get(engine, 'pendingCandidateIds') as Set<number>;
      expect(pending.size).assertEqual(0);
    });

    it('normal: amap_private_should_cover_count_extract_and_web_search', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AmapService), 'toPoiSearchItem');
      hooks.keep(Object(AppConfig), 'validateAmapWebConfig');
      hooks.keep(Object(HttpRequestHelper), 'request');
      hooks.set(Object(AmapService), 'toPoiSearchItem', ((_poi: Object): PoiSearchItem | null => new PoiSearchItem('A', 'B', 31.2, 121.5, 10)) as Object);
      hooks.set(Object(AppConfig), 'validateAmapWebConfig', (() => {}) as Object);
      hooks.set(Object(HttpRequestHelper), 'request', (async (): Promise<Object> => ({
        responseCode: 200,
        result: '{"status":"1","pois":[{"name":"K","address":"A","location":"121.5,31.2","distance":"12"}]}'
      })) as Object);
      const api = AmapService as Object;
      const countFn = Reflect.get(api, 'resolvePoiListCount') as (listObj: Object) => number;
      const extractFn = Reflect.get(api, 'extractPoiItems') as (result: Object | undefined) => PoiSearchItem[];
      const webFn = Reflect.get(api, 'searchPoiByWebApi') as
        (keyword: string, centerLat: number, centerLng: number, limit: number, nearbyOnly: boolean) => Promise<PoiSearchItem[]>;
      const resultObj = { getPois: (): Object => ({ length: 2, get: (_idx: number): Object => ({}) }) };

      // Act
      const count = countFn.call(api, { length: 3 } as Object);
      const extracted = extractFn.call(api, resultObj as Object);
      const webItems = await webFn.call(api, 'k', 31.2, 121.5, 5, true);

      // Assert
      expect(count).assertEqual(3);
      expect(extracted.length).assertEqual(2);
      expect(webItems.length).assertEqual(1);
      hooks.restoreAll();
    });

    it('regression: amap_private_should_cover_fallback_merge_and_generic_list', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AmapService), 'searchPoiByWebApi');
      hooks.set(Object(AmapService), 'searchPoiByWebApi', (async (_k: string, _lat: number, _lng: number, _l: number, nearbyOnly: boolean): Promise<PoiSearchItem[]> => {
        if (nearbyOnly) {
          return [new PoiSearchItem('N1', 'A', 31.2, 121.5, 5)];
        }
        return [new PoiSearchItem('N2', 'B', 31.21, 121.51, 6)];
      }) as Object);
      const api = AmapService as Object;
      const fallbackFn = Reflect.get(api, 'searchPoiWithWebFallback') as
        (keyword: string, centerLat: number, centerLng: number, limit: number) => Promise<PoiSearchItem[]>;
      const getSize = Reflect.get(api, 'getListSize') as (listObj: Object | undefined) => number;
      const getItem = Reflect.get(api, 'getListItem') as <T>(listObj: Object | undefined, idx: number) => T | undefined;
      const generic = { size: 2, get: (idx: number): string => (idx === 0 ? 'x' : 'y') };

      // Act
      const items = await fallbackFn.call(api, 'k', 31.2, 121.5, 10);
      const size = getSize.call(api, generic as Object);
      const first = getItem.call(api, generic as Object, 0) as string | undefined;

      // Assert
      expect(items.length).assertEqual(2);
      expect(size).assertEqual(2);
      expect(first ?? '').assertEqual('x');
      hooks.restoreAll();
    });

    it('invalid: amap_sdk_private_methods_should_return_null_when_sdk_unavailable', 0, async () => {
      // Arrange
      const api = AmapService as Object;
      const geoFn = Reflect.get(api, 'getGeocodeBySdkGeoSearch') as (address: string, context: common.Context) => Promise<Object | null>;
      const cityFn = Reflect.get(api, 'getCityCodeBySdkGeoSearch') as (context: common.Context, lat: number, lng: number) => Promise<string | null>;
      const nearFn = Reflect.get(api, 'getRegeoBySdkNearby') as (context: common.Context, lat: number, lng: number) => Promise<string | null>;
      const regeoFn = Reflect.get(api, 'getRegeoBySdkGeoSearch') as (context: common.Context, lat: number, lng: number) => Promise<string | null>;
      const fakeCtx = {} as common.Context;

      // Act
      const geocode = await geoFn.call(api, 'bad', fakeCtx);
      const city = await cityFn.call(api, fakeCtx, 31.2, 121.5);
      const near = await nearFn.call(api, fakeCtx, 31.2, 121.5);
      const regeo = await regeoFn.call(api, fakeCtx, 31.2, 121.5);

      // Assert
      expect(geocode === null).assertTrue();
      expect(city === null).assertTrue();
      expect(near === null).assertTrue();
      expect(regeo === null).assertTrue();
    });
  });
}

