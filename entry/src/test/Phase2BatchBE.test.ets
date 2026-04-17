import { describe, it, expect } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import fileIo from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import util from '@ohos.util';
import { PlanImportExportService, PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { ArrivalReminderEngine, ArrivalReminderPayload } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { AvatarUploadApi } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AuthApiResponse, AuthSessionPayload, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';

interface MockStoreBE {
  beginTransaction: () => void;
  commit: () => void;
  rollBack: () => void;
}

interface PlanTransitionEventBE {
  planId: string;
  toStatus: PlanStatus;
}

interface PlanStatusSnapshotBE {
  status: PlanStatus;
}

class TxStoreBE {
  beginCount: number = 0;
  commitCount: number = 0;
  rollbackCount: number = 0;
  rollbackThrows: boolean = false;

  public beginTransaction(): void {
    this.beginCount += 1;
  }

  public commit(): void {
    this.commitCount += 1;
  }

  public rollBack(): void {
    this.rollbackCount += 1;
    if (this.rollbackThrows) {
      throw new Error('rollback_failed_be');
    }
  }
}

class FakePlanStateMachineBE {
  status: PlanStatus = PlanStatus.READY;
  private listener: ((event: PlanTransitionEventBE) => void) | null = null;

  public subscribePlanTransition(_planId: string, listener: (event: PlanTransitionEventBE) => void): () => void {
    this.listener = listener;
    return (): void => {
      this.listener = null;
    };
  }

  public getPlanStatus(_planId: string): PlanStatusSnapshotBE {
    return { status: this.status };
  }

  public emit(planId: string, toStatus: PlanStatus): void {
    this.listener?.({ planId: planId, toStatus: toStatus });
  }
}

class SessionStoreHooksBE {
  private readonly originSave: Object;
  private readonly originLoad: Object;
  private readonly originSaveSessionPersisted: Object;
  private readonly originLoadSessionPersisted: Object;
  private readonly originClearSessionPersisted: Object;
  private readonly originMarkGuestChosenPersisted: Object;
  private readonly originHasGuestChosenPersisted: Object;
  private readonly originMarkSilentBlocked: Object;
  private readonly originIsSilentBlocked: Object;
  private readonly originClearSilentBlocked: Object;
  private readonly originMarkSilentBlockedPersisted: Object;
  private readonly originClearSilentBlockedPersisted: Object;
  private readonly originIsSilentBlockedPersisted: Object;

  constructor() {
    this.originSave = Reflect.get(Object(AuthSessionStore), 'save') as Object;
    this.originLoad = Reflect.get(Object(AuthSessionStore), 'load') as Object;
    this.originSaveSessionPersisted = Reflect.get(Object(AuthSessionStore), 'saveSessionPersisted') as Object;
    this.originLoadSessionPersisted = Reflect.get(Object(AuthSessionStore), 'loadSessionPersisted') as Object;
    this.originClearSessionPersisted = Reflect.get(Object(AuthSessionStore), 'clearSessionPersisted') as Object;
    this.originMarkGuestChosenPersisted = Reflect.get(Object(AuthSessionStore), 'markGuestChosenPersisted') as Object;
    this.originHasGuestChosenPersisted = Reflect.get(Object(AuthSessionStore), 'hasGuestChosenPersisted') as Object;
    this.originMarkSilentBlocked = Reflect.get(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogout') as Object;
    this.originIsSilentBlocked = Reflect.get(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogout') as Object;
    this.originClearSilentBlocked = Reflect.get(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogout') as Object;
    this.originMarkSilentBlockedPersisted = Reflect.get(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted') as Object;
    this.originClearSilentBlockedPersisted = Reflect.get(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogoutPersisted') as Object;
    this.originIsSilentBlockedPersisted = Reflect.get(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted') as Object;
  }

  public restore(): void {
    Reflect.set(Object(AuthSessionStore), 'save', this.originSave);
    Reflect.set(Object(AuthSessionStore), 'load', this.originLoad);
    Reflect.set(Object(AuthSessionStore), 'saveSessionPersisted', this.originSaveSessionPersisted);
    Reflect.set(Object(AuthSessionStore), 'loadSessionPersisted', this.originLoadSessionPersisted);
    Reflect.set(Object(AuthSessionStore), 'clearSessionPersisted', this.originClearSessionPersisted);
    Reflect.set(Object(AuthSessionStore), 'markGuestChosenPersisted', this.originMarkGuestChosenPersisted);
    Reflect.set(Object(AuthSessionStore), 'hasGuestChosenPersisted', this.originHasGuestChosenPersisted);
    Reflect.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogout', this.originMarkSilentBlocked);
    Reflect.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogout', this.originIsSilentBlocked);
    Reflect.set(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogout', this.originClearSilentBlocked);
    Reflect.set(Object(AuthSessionStore), 'markSilentLoginBlockedAfterLogoutPersisted', this.originMarkSilentBlockedPersisted);
    Reflect.set(Object(AuthSessionStore), 'clearSilentLoginBlockedAfterLogoutPersisted', this.originClearSilentBlockedPersisted);
    Reflect.set(Object(AuthSessionStore), 'isSilentLoginBlockedAfterLogoutPersisted', this.originIsSilentBlockedPersisted);
  }
}

function buildEventBE(name: string, sortOrder: number): TravelPlanItem {
  return {
    name: name,
    note: '',
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: -1,
    sortOrder: sortOrder,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '',
    dayOffset: 0,
    itemType: 0,
    priority: 0,
    transportMode: 2,
    travelMode: 2,
    isTravelManual: 0,
    source: 0,
    delFlag: 0,
    groupId: 0,
    address: '',
    aiReasoning: '',
    latitude: 31.2,
    longitude: 121.4,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0
  };
}

function buildPayloadBE(planId: number, eventId: number): ArrivalReminderPayload {
  return {
    seq: 1,
    planId: planId,
    eventId: eventId,
    placeName: 'be-place',
    distanceMeters: 88,
    triggerAt: Date.now()
  };
}

function buildStartableEventBE(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  event.name = `event-${id}`;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  return event;
}

export default function phase2BatchBETest() {
  describe('phase2BatchBETest_plan_import_export', () => {
    it('normal: import_should_continue_compensation_when_rollback_throws', 0, async (done: () => void) => {
      // Arrange
      const tx = new TxStoreBE();
      tx.rollbackThrows = true;
      const deleted: number[] = [];
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStoreBE => tx,
        createPlan: async (): Promise<number> => 9101,
        updateAutoAmapRoute: async (): Promise<void> => {},
        updatePlanStatus: async (): Promise<void> => {},
        insertEvent: async (): Promise<number> => {
          throw new Error('insert_failed_be');
        },
        hardDeletePlan: async (id: number): Promise<void> => {
          deleted.push(id);
        }
      });
      const raw = PlanSerializer.serializePlan({ title: 'be', startDate: Date.now(), status: 1, enableAutoAmapRoute: 1 }, [buildEventBE('a', 0)]);
      // Act
      let message = '';
      try {
        await PlanImportExportService.importPlanFromJson(raw);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }
      // Assert
      expect(message).assertEqual('insert_failed_be');
      expect(tx.beginCount).assertEqual(1);
      expect(tx.rollbackCount).assertEqual(1);
      expect(deleted.length).assertEqual(1);
      expect(deleted[0]).assertEqual(9101);
      done();
    });

    it('boundary: import_cancel_token_should_block_before_parse_stage', 0, async (done: () => void) => {
      // Arrange
      const token = new PlanJsonImportCancelToken();
      token.cancel();
      // Act
      let message = '';
      try {
        await PlanImportExportService.importPlanFromJson('{"bad":"payload"}', token);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('import_cancelled:before_parse');
      done();
    });

    it('invalid: import_should_wrap_non_error_throw_as_import_failed', 0, async (done: () => void) => {
      // Arrange
      const tx = new TxStoreBE();
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStoreBE => tx,
        createPlan: async (): Promise<number> => 9102,
        updateAutoAmapRoute: async (): Promise<void> => {},
        updatePlanStatus: async (): Promise<void> => {},
        insertEvent: async (): Promise<number> => {
          throw ({ bad: 1 } as Object) as Error;
        },
        hardDeletePlan: async (): Promise<void> => {}
      });
      const raw = PlanSerializer.serializePlan({ title: 'be2', startDate: Date.now(), status: 1, enableAutoAmapRoute: 1 }, [buildEventBE('a', 0)]);
      // Act
      let message = '';
      try {
        await PlanImportExportService.importPlanFromJson(raw);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }
      // Assert
      expect(message.startsWith('import_failed:')).assertTrue();
      expect(tx.rollbackCount).assertEqual(1);
      done();
    });
  });

  describe('phase2BatchBETest_arrival_engine', () => {
    it('normal: get_last_known_location_should_return_snapshot_when_location_exists', 0, () => {
      // Arrange
      Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
      const engine = ArrivalReminderEngine.getInstance();
      Reflect.set(engine as Object, 'lastLocation', { latitude: 31.2, longitude: 121.4, accuracy: 20, speed: 2 } as Object);
      // Act
      const snapshot = engine.getLastKnownLocation();
      // Assert
      expect(snapshot !== null).assertTrue();
      expect(snapshot?.latitude || 0).assertEqual(31.2);
      expect(snapshot?.longitude || 0).assertEqual(121.4);
    });

    it('boundary: to_geo_fence_array_should_support_for_each_only_list', 0, () => {
      // Arrange
      const engine = ArrivalReminderEngine.getInstance();
      const listObj = {
        forEach: (cb: (value: Object) => void): void => {
          cb({ getCustomId: (): string => '1:1', getStatus: (): number => 1 } as Object);
        }
      } as Object;
      // Act
      const values = Reflect.get(engine as Object, 'toGeoFenceArray').call(engine, listObj) as Object[];
      // Assert
      expect(values.length).assertEqual(1);
    });

    it('invalid: ensure_reminder_consistency_should_end_when_current_event_missing', 0, () => {
      // Arrange
      const engine = ArrivalReminderEngine.getInstance();
      let clearEventId = -1;
      let endedEventId = -1;
      const originClear = Reflect.get(engine as Object, 'clearReminderPayloadIfMatches') as Object;
      const originPublish = Reflect.get(engine as Object, 'publishLiveActivityState') as Object;
      Reflect.set(engine as Object, 'clearReminderPayloadIfMatches', (eventId: number): void => { clearEventId = eventId; });
      Reflect.set(engine as Object, 'publishLiveActivityState', (eventId: number, status: string): void => {
        if (status === 'ENDED') {
          endedEventId = eventId;
        }
      });
      Reflect.set(engine as Object, 'lastReminderEventId', 12001);
      Reflect.set(engine as Object, 'monitoredEvents', []);
      // Act
      Reflect.get(engine as Object, 'ensureReminderConsistency').call(engine);
      // Assert
      expect(endedEventId).assertEqual(12001);
      expect(clearEventId).assertEqual(12001);
      expect(Number(Reflect.get(engine as Object, 'lastReminderEventId'))).assertEqual(-1);
      Reflect.set(engine as Object, 'clearReminderPayloadIfMatches', originClear);
      Reflect.set(engine as Object, 'publishLiveActivityState', originPublish);
    });
  });

  describe('phase2BatchBETest_avatar_upload_api', () => {
    it('normal: upload_avatar_should_return_local_only_when_gateway_code_non_zero', 0, async (done: () => void) => {
      // Arrange
      const uploader = new AvatarUploadApi({
        getAccessToken: (): string => 'token_be',
        encodeFileToDataUrl: (): string => 'data:image/jpeg;base64,AA==',
        updateAvatar: async (): Promise<AuthApiResponse<UpdateAvatarResult>> => {
          const response = new AuthApiResponse<UpdateAvatarResult>(new UpdateAvatarResult());
          response.code = 401;
          return response;
        },
        now: (): number => 100
      });
      const input = new AvatarUploadInput();
      input.fileUri = 'file://avatar.jpg';
      // Act
      const result = await uploader.uploadAvatar(input);
      // Assert
      expect(result.status).assertEqual('LOCAL_ONLY');
      expect(result.errorCode || '').assertEqual('401');
      expect(result.requestId).assertEqual('avatar_req_100');
      done();
    });

    it('boundary: read_file_as_data_url_should_return_data_url_when_file_read_success', 0, () => {
      // Arrange
      const originStatSync = Reflect.get(fileIo as Object, 'statSync') as Object;
      const originOpenSync = Reflect.get(fileIo as Object, 'openSync') as Object;
      const originReadSync = Reflect.get(fileIo as Object, 'readSync') as Object;
      const originCloseSync = Reflect.get(fileIo as Object, 'closeSync') as Object;
      const originFileUri = Reflect.get(fileUri as Object, 'FileUri') as Object;
      const originBase64Helper = Reflect.get(util as Object, 'Base64Helper') as Object;

      class FileUriMock {
        path: string;
        constructor(_raw: string) {
          this.path = '/tmp/avatar mock.jpg';
        }
      }
      class Base64HelperMock {
        public encodeToStringSync(_content: Uint8Array, _type: Object): string {
          return 'YmU=';
        }
      }

      Reflect.set(fileIo as Object, 'statSync', (_path: string): Object => ({ size: 4 } as Object));
      Reflect.set(fileIo as Object, 'openSync', (_path: string, _mode: number): Object => ({ fd: 1 } as Object));
      Reflect.set(fileIo as Object, 'readSync', (_fd: number, buffer: ArrayBuffer): number => {
        const arr = new Uint8Array(buffer);
        arr[0] = 98;
        arr[1] = 101;
        return 2;
      });
      Reflect.set(fileIo as Object, 'closeSync', (_file: Object): void => {});
      Reflect.set(fileUri as Object, 'FileUri', FileUriMock as Object);
      Reflect.set(util as Object, 'Base64Helper', Base64HelperMock as Object);

      // Act
      const dataUrl = AvatarUploadApi.readFileAsDataUrl('file://tmp/avatar%20mock.jpg', 'image/png');

      // Assert
      expect(dataUrl).assertEqual('data:image/png;base64,YmU=');

      Reflect.set(fileIo as Object, 'statSync', originStatSync);
      Reflect.set(fileIo as Object, 'openSync', originOpenSync);
      Reflect.set(fileIo as Object, 'readSync', originReadSync);
      Reflect.set(fileIo as Object, 'closeSync', originCloseSync);
      Reflect.set(fileUri as Object, 'FileUri', originFileUri);
      Reflect.set(util as Object, 'Base64Helper', originBase64Helper);
    });

    it('invalid: read_file_as_data_url_should_throw_when_read_size_invalid', 0, () => {
      // Arrange
      const originStatSync = Reflect.get(fileIo as Object, 'statSync') as Object;
      const originOpenSync = Reflect.get(fileIo as Object, 'openSync') as Object;
      const originReadSync = Reflect.get(fileIo as Object, 'readSync') as Object;
      const originCloseSync = Reflect.get(fileIo as Object, 'closeSync') as Object;

      Reflect.set(fileIo as Object, 'statSync', (_path: string): Object => ({ size: 8 } as Object));
      Reflect.set(fileIo as Object, 'openSync', (_path: string, _mode: number): Object => ({ fd: 1 } as Object));
      Reflect.set(fileIo as Object, 'readSync', (_fd: number, _buffer: ArrayBuffer): number => 0);
      Reflect.set(fileIo as Object, 'closeSync', (_file: Object): void => {});

      // Act
      let message = '';
      try {
        AvatarUploadApi.readFileAsDataUrl('C:/avatar.jpg', 'image/jpeg');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }

      // Assert
      expect(message).assertEqual('avatar_file_read_empty');

      Reflect.set(fileIo as Object, 'statSync', originStatSync);
      Reflect.set(fileIo as Object, 'openSync', originOpenSync);
      Reflect.set(fileIo as Object, 'readSync', originReadSync);
      Reflect.set(fileIo as Object, 'closeSync', originCloseSync);
    });
  });

  describe('phase2BatchBETest_arrival_coordinator', () => {
    it('normal: subscribe_plan_should_clear_payload_on_terminal_transition', 0, () => {
      // Arrange
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineBE();
      Reflect.set(coordinator as Object, 'planStateMachine', machine);

      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      const originClear = Reflect.get(ArrivalReminderStore, 'clearPayload') as Object;
      let clearedPlanId = -1;
      Reflect.set(ArrivalReminderStore, 'readPayload', (_planId?: number): ArrivalReminderPayload | null => buildPayloadBE(701, 7001));
      Reflect.set(ArrivalReminderStore, 'clearPayload', (planId: number): void => {
        clearedPlanId = planId;
      });

      let ackEventId = -1;
      let ackAction = '';
      const originAck = Reflect.get(coordinator as Object, 'acknowledge') as Object;
      Reflect.set(coordinator as Object, 'acknowledge', (eventId: number, action: string): void => {
        ackEventId = eventId;
        ackAction = action;
      });

      // Act
      const unsubscribe = coordinator.subscribePlan('*', {
        isDialogOpen: (): boolean => true,
        pollIntervalMs: 1000
      });
      machine.emit('701', PlanStatus.COMPLETED);
      unsubscribe();

      // Assert
      expect(ackEventId).assertEqual(7001);
      expect(ackAction).assertEqual('dismiss');
      expect(clearedPlanId).assertEqual(701);

      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      Reflect.set(ArrivalReminderStore, 'clearPayload', originClear);
      Reflect.set(coordinator as Object, 'acknowledge', originAck);
    });

    it('boundary: can_show_by_plan_status_should_allow_in_progress', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineBE();
      machine.status = PlanStatus.IN_PROGRESS;
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      // Act
      const result = Reflect.get(coordinator as Object, 'canShowByPlanStatus').call(coordinator, 1) as boolean;
      // Assert
      expect(result).assertTrue();
    });

    it('invalid: can_show_by_plan_status_should_reject_completed', 0, () => {
      // Arrange
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachineBE();
      machine.status = PlanStatus.COMPLETED;
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      // Act
      const result = Reflect.get(coordinator as Object, 'canShowByPlanStatus').call(coordinator, 1) as boolean;
      // Assert
      expect(result).assertEqual(false);
    });
  });

  describe('phase2BatchBETest_amap_service_private_branches', () => {
    it('normal: sdk_md5_auth_error_should_match_error_code_1008', 0, () => {
      // Arrange
      // Act
      const matched = Reflect.get(AmapService as Object, 'isSdkMd5AuthError').call(AmapService, { errorCode: 1008 } as Object) as boolean;
      // Assert
      expect(matched).assertTrue();
    });

    it('boundary: sdk_md5_auth_error_should_match_md5_keyword', 0, () => {
      // Arrange
      // Act
      const matched = Reflect.get(AmapService as Object, 'isSdkMd5AuthError').call(AmapService, { message: 'MD5 not match' } as Object) as boolean;
      // Assert
      expect(matched).assertTrue();
    });

    it('invalid: sdk_md5_auth_error_should_return_false_for_unrelated_error', 0, () => {
      // Arrange
      // Act
      const matched = Reflect.get(AmapService as Object, 'isSdkMd5AuthError').call(AmapService, { message: 'timeout' } as Object) as boolean;
      // Assert
      expect(matched).assertEqual(false);
    });

    it('normal: poi_cache_should_return_written_entry_before_ttl', 0, () => {
      // Arrange
      const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
      cache.clear();
      const key = Reflect.get(AmapService as Object, 'buildPoiCacheKey').call(AmapService, 'Museum', 31.2, 121.4, 5) as string;
      const items = [new PoiSearchItem('A', 'addr', 31.2, 121.4, 100)];
      Reflect.get(AmapService as Object, 'writePoiCache').call(AmapService, key, items);
      // Act
      const hit = Reflect.get(AmapService as Object, 'readPoiCache').call(AmapService, key) as PoiSearchItem[] | null;
      // Assert
      expect((hit?.length || 0)).assertEqual(1);
    });

    it('boundary: poi_cache_should_expire_entry_when_ts_over_ttl', 0, () => {
      // Arrange
      const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
      cache.clear();
      const key = 'expired-key';
      cache.set(key, { ts: 1, items: [new PoiSearchItem('B', 'addr', 31.2, 121.4, 120)] } as Object);
      // Act
      const hit = Reflect.get(AmapService as Object, 'readPoiCache').call(AmapService, key) as PoiSearchItem[] | null;
      // Assert
      expect(hit === null).assertTrue();
      expect(cache.has(key)).assertEqual(false);
    });

    it('invalid: poi_cache_should_return_null_when_key_missing', 0, () => {
      // Arrange
      const cache = Reflect.get(AmapService as Object, 'poiSearchCache') as Map<string, Object>;
      cache.clear();
      // Act
      const hit = Reflect.get(AmapService as Object, 'readPoiCache').call(AmapService, 'missing-key') as PoiSearchItem[] | null;
      // Assert
      expect(hit === null).assertTrue();
    });
  });

  describe('phase2BatchBETest_session_manager', () => {
    it('normal: save_session_persisted_should_forward_payload_to_store', 0, async (done: () => void) => {
      // Arrange
      const hooks = new SessionStoreHooksBE();
      let capturedAccountId = '';
      let capturedExpireAt = 0;
      Reflect.set(Object(AuthSessionStore), 'saveSessionPersisted', async (_context: common.Context, payload: AuthSessionPayload): Promise<void> => {
        capturedAccountId = payload.accountId;
        capturedExpireAt = payload.expireAt;
      });

      const manager = SessionManager.getInstance();
      const session = new UserSession();
      session.accountId = 'acc-be';
      session.userId = 'u-be';
      session.accessToken = 'token-be';
      session.expireAt = Date.now() + 30_000;

      // Act
      await manager.saveSessionPersisted({} as common.Context, session);

      // Assert
      expect(capturedAccountId).assertEqual('acc-be');
      expect(capturedExpireAt > Date.now()).assertTrue();
      hooks.restore();
      done();
    });

    it('boundary: restore_session_persisted_should_save_runtime_session_on_valid_payload', 0, async (done: () => void) => {
      // Arrange
      const hooks = new SessionStoreHooksBE();
      let saveCalled = 0;
      Reflect.set(Object(AuthSessionStore), 'save', (_payload: AuthSessionPayload): void => {
        saveCalled += 1;
      });
      Reflect.set(Object(AuthSessionStore), 'loadSessionPersisted', async (_context: common.Context): Promise<AuthSessionPayload | null> => {
        const payload = new AuthSessionPayload();
        payload.accountId = 'acc-restore';
        payload.userId = 'u-restore';
        payload.accessToken = 'token-restore';
        payload.refreshToken = 'refresh-restore';
        payload.expireAt = Date.now() + 60_000;
        return payload;
      });
      const manager = SessionManager.getInstance();

      // Act
      const restored = await manager.restoreSessionPersisted({} as common.Context);

      // Assert
      expect(restored !== null).assertTrue();
      expect(restored?.accountId || '').assertEqual('acc-restore');
      expect(saveCalled).assertEqual(1);
      hooks.restore();
      done();
    });

    it('invalid: restore_session_persisted_should_return_null_when_payload_expired', 0, async (done: () => void) => {
      // Arrange
      const hooks = new SessionStoreHooksBE();
      let saveCalled = 0;
      Reflect.set(Object(AuthSessionStore), 'save', (_payload: AuthSessionPayload): void => {
        saveCalled += 1;
      });
      Reflect.set(Object(AuthSessionStore), 'loadSessionPersisted', async (_context: common.Context): Promise<AuthSessionPayload | null> => {
        const payload = new AuthSessionPayload();
        payload.accountId = 'expired';
        payload.expireAt = Date.now() - 1000;
        return payload;
      });
      const manager = SessionManager.getInstance();

      // Act
      const restored = await manager.restoreSessionPersisted({} as common.Context);

      // Assert
      expect(restored === null).assertTrue();
      expect(saveCalled).assertEqual(0);
      hooks.restore();
      done();
    });
  });
}
