import { describe, expect, it } from '@ohos/hypium';
import { common } from '@kit.AbilityKit';
import { PlanImportExportService, PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
import { ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderCoordinator } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { AmapService } from '../main/ets/infrastructure/services/AmapService';
import { AuthSessionPayload } from '../main/ets/domain/auth/AuthModels';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';

interface AmapServicePrivateBE {
  isSdkMd5AuthError: (error: Object) => boolean;
}

interface PlanStatusSnapshotBE {
  status: PlanStatus;
}

interface ArrivalCoordinatorPrivateBE {
  planStateMachine: FakePlanStateMachineBE;
  canShowByPlanStatus: (planId: number) => boolean;
}

class PlanStatusHolderBE implements PlanStatusSnapshotBE {
  status: PlanStatus = PlanStatus.READY;
}

class FakePlanStateMachineBE {
  currentStatus: PlanStatus = PlanStatus.READY;

  getPlanStatus(_planId: string): PlanStatusHolderBE {
    const holder = new PlanStatusHolderBE();
    holder.status = this.currentStatus;
    return holder;
  }
}

class LocationSnapshotBE {
  latitude: number = 0;
  longitude: number = 0;
  accuracy: number = 0;
  speed: number = 0;
}

class ErrorPayloadBE {
  errorCode: number = 0;
  message: string = '';
}

class SessionStoreHooksBE {
  private readonly originSave: Object;
  private readonly originLoadSessionPersisted: Object;

  constructor() {
    this.originSave = Reflect.get(Object(AuthSessionStore), 'save') as Object;
    this.originLoadSessionPersisted = Reflect.get(Object(AuthSessionStore), 'loadSessionPersisted') as Object;
  }

  restore(): void {
    Reflect.set(Object(AuthSessionStore), 'save', this.originSave);
    Reflect.set(Object(AuthSessionStore), 'loadSessionPersisted', this.originLoadSessionPersisted);
  }
}

function createExpiredPayloadBE(): AuthSessionPayload {
  const payload = new AuthSessionPayload();
  payload.accountId = 'expired_be';
  payload.expireAt = Date.now() - 1000;
  return payload;
}

export default function phase2BatchBETest() {
  describe('phase2BatchBE_safe_suite', () => {
    it('normal: arrival_engine_should_return_last_known_location_snapshot_when_present', 0, () => {
      // Arrange
      Reflect.set(Object(ArrivalReminderEngine), 'instance', null);
      const engine = ArrivalReminderEngine.getInstance();
      const snapshot = new LocationSnapshotBE();
      snapshot.latitude = 31.2;
      snapshot.longitude = 121.4;
      snapshot.accuracy = 20;
      snapshot.speed = 2;
      Reflect.set(engine as Object, 'lastLocation', snapshot as Object);
      // Act
      const result = engine.getLastKnownLocation();
      // Assert
      expect(result !== null).assertTrue();
      expect(result?.latitude ?? 0).assertEqual(31.2);
      expect(result?.longitude ?? 0).assertEqual(121.4);
    });

    it('boundary: import_cancel_token_should_block_before_parse_stage', 0, async () => {
      // Arrange
      const token = new PlanJsonImportCancelToken();
      token.cancel();
      let message = '';
      // Act
      try {
        await PlanImportExportService.importPlanFromJson('{"bad":"payload"}', token);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('import_cancelled:before_parse');
    });

    it('invalid: amap_service_should_return_false_for_unrelated_auth_error', 0, () => {
      // Arrange
      const privateApi = AmapService as Object as AmapServicePrivateBE;
      const payload = new ErrorPayloadBE();
      payload.message = 'timeout';
      // Act
      const matched = privateApi.isSdkMd5AuthError(payload as Object);
      // Assert
      expect(matched).assertFalse();
    });

    it('conflict: arrival_coordinator_should_reject_completed_plan_status_for_display', 0, () => {
      // Arrange
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const coordinator = ArrivalReminderCoordinator.getInstance() as Object as ArrivalCoordinatorPrivateBE;
      const machine = new FakePlanStateMachineBE();
      machine.currentStatus = PlanStatus.COMPLETED;
      coordinator.planStateMachine = machine;
      // Act
      const allowed = coordinator.canShowByPlanStatus(1);
      // Assert
      expect(allowed).assertFalse();
    });

    it('regression: session_manager_should_return_null_when_persisted_payload_expired', 0, async () => {
      // Arrange
      const hooks = new SessionStoreHooksBE();
      Reflect.set(Object(AuthSessionStore), 'save', (_payload: AuthSessionPayload): void => {});
      Reflect.set(
        Object(AuthSessionStore),
        'loadSessionPersisted',
        async (_context: common.Context): Promise<AuthSessionPayload | null> => createExpiredPayloadBE()
      );
      const manager = SessionManager.getInstance();
      // Act
      const restored = await manager.restoreSessionPersisted({} as common.Context);
      // Assert
      expect(restored === null).assertTrue();
      hooks.restore();
    });

    it('combined: amap_service_should_match_md5_auth_error_by_code_and_keyword', 0, () => {
      // Arrange
      const privateApi = AmapService as Object as AmapServicePrivateBE;
      const codePayload = new ErrorPayloadBE();
      codePayload.errorCode = 1008;
      const keywordPayload = new ErrorPayloadBE();
      keywordPayload.message = 'MD5 not match';
      // Act
      const matchedByCode = privateApi.isSdkMd5AuthError(codePayload as Object);
      const matchedByKeyword = privateApi.isSdkMd5AuthError(keywordPayload as Object);
      // Assert
      expect(matchedByCode).assertTrue();
      expect(matchedByKeyword).assertTrue();
    });
  });
}
