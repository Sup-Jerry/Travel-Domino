import { describe, expect, it } from '@ohos/hypium';
import { PlanImportExportService } from '../main/ets/infrastructure/services/PlanImportExportService';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { AvatarUploadApi, AvatarUploadApiOptions } from '../main/ets/infrastructure/avatar/AvatarUploadApi';
import { AvatarUploadInput } from '../main/ets/domain/auth/AvatarModels';
import { AuthApiResponse, AuthSessionPayload, UpdateAvatarResult } from '../main/ets/domain/auth/AuthModels';
import { SessionManager } from '../main/ets/infrastructure/auth/SessionManager';
import { AuthSessionStore } from '../main/ets/infrastructure/auth/AuthSessionStore';
import { UserSession } from '../main/ets/domain/auth/AuthTypes';
import { AmapService, AmapPoiSearchNode, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';

interface TxStoreLikeBQ {
  beginTransaction(): void;
  commit(): void;
  rollBack(): void;
}

class HookEntryBQ {
  owner: Object;
  key: string;
  value: Object | undefined;

  constructor(owner: Object, key: string, value: Object | undefined) {
    this.owner = owner;
    this.key = key;
    this.value = value;
  }
}

class HooksBQ {
  private readonly entries: HookEntryBQ[] = [];

  keep(owner: Object, key: string): void {
    this.entries.push(new HookEntryBQ(owner, key, Reflect.get(owner, key) as Object | undefined));
  }

  set(owner: Object, key: string, value: Object): void {
    Reflect.set(owner, key, value);
  }

  restoreAll(): void {
    for (let i = this.entries.length - 1; i >= 0; i--) {
      const entry = this.entries[i];
      Reflect.set(entry.owner, entry.key, entry.value);
    }
  }
}

class TxStoreMockBQ implements TxStoreLikeBQ {
  beginCount: number = 0;
  commitCount: number = 0;
  rollbackCount: number = 0;

  beginTransaction(): void {
    this.beginCount += 1;
  }

  commit(): void {
    this.commitCount += 1;
  }

  rollBack(): void {
    this.rollbackCount += 1;
  }
}

class ParsedPlanMetaBQ {
  title: string = 'plan_bq';
  startDate: number = 1710000000000;
  status: number = 1;
  enableAutoAmapRoute: number = 1;
}

class ParsedPlanResultBQ {
  plan: ParsedPlanMetaBQ = new ParsedPlanMetaBQ();
  events: TravelPlanItem[] = [];
}

class RdbHelperInstanceMockBQ {
  private readonly store: TxStoreLikeBQ | null;

  constructor(store: TxStoreLikeBQ | null) {
    this.store = store;
  }

  getRdbStore(): TxStoreLikeBQ | null {
    return this.store;
  }
}

class AvatarApiOptionsMockBQ implements AvatarUploadApiOptions {
  token: string = 'token_bq';
  responseCode: number = 0;
  shouldEncodeThrow: boolean = false;
  remoteUrl: string = 'https://example.com/bq.jpg';

  getAccessToken = (): string => {
    return this.token;
  };

  encodeFileToDataUrl = (_fileUriText: string, _mimeType: string): string => {
    if (this.shouldEncodeThrow) {
      throw new Error('encode_failed_bq');
    }
    return 'data:image/jpeg;base64,AA==';
  };

  updateAvatar = async (
    _accessToken: string,
    _imageDataUrl: string,
    _mimeType: string
  ): Promise<AuthApiResponse<UpdateAvatarResult>> => {
    const data = new UpdateAvatarResult();
    data.avatarUrl = this.remoteUrl;
    const response = new AuthApiResponse<UpdateAvatarResult>(data);
    response.code = this.responseCode;
    return response;
  };
}

class AmapPoiNodeMockBQ implements AmapPoiSearchNode {
  id?: string = '';
  name?: string = '';
  address?: string = '';
  location?: string = '';
  distance?: string = '';
}

function createAvatarInputBQ(): AvatarUploadInput {
  const input = new AvatarUploadInput();
  input.fileUri = 'file://avatar.jpg';
  input.mimeType = 'image/jpeg';
  return input;
}

function createSessionBQ(expireAt: number): UserSession {
  const session = new UserSession();
  session.accountId = 'acc_bq';
  session.userId = 'uid_bq';
  session.isGuest = false;
  session.loginMethod = 'HUAWEI';
  session.accessToken = 'token_bq';
  session.refreshToken = 'refresh_bq';
  session.expireAt = expireAt;
  session.sessionId = 'sid_bq';
  return session;
}

function createPayloadBQ(expireAt: number): AuthSessionPayload {
  const payload = new AuthSessionPayload();
  payload.accountId = 'acc_bq';
  payload.userId = 'uid_bq';
  payload.isGuest = false;
  payload.loginMethod = 'HUAWEI';
  payload.accessToken = 'token_bq';
  payload.refreshToken = 'refresh_bq';
  payload.expireAt = expireAt;
  payload.sessionId = 'sid_bq';
  return payload;
}

export default function phase2BatchBQTest() {
  describe('phase2BatchBQ_plan_import', () => {
    it('normal: import_should_commit_when_create_plan_success', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      const store = new TxStoreMockBQ();
      let createCalls = 0;
      hooks.keep(Object(PlanSerializer), 'deserializePlan');
      hooks.keep(Object(RdbHelper), 'getInstance');
      hooks.keep(Object(PlanRepositoryImpl), 'createPlan');
      hooks.keep(Object(PlanRepositoryImpl), 'updateAutoAmapRoute');
      hooks.keep(Object(PlanRepositoryImpl), 'updatePlanStatus');
      hooks.keep(Object(EventRepositoryImpl), 'insertEvent');
      hooks.set(Object(PlanSerializer), 'deserializePlan', ((_raw: string): ParsedPlanResultBQ => new ParsedPlanResultBQ()) as Object);
      hooks.set(Object(RdbHelper), 'getInstance', (() => new RdbHelperInstanceMockBQ(store)) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'createPlan', (async (): Promise<number> => {
        createCalls += 1;
        return 9001;
      }) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'updateAutoAmapRoute', (async (): Promise<void> => {}) as Object);
      hooks.set(Object(PlanRepositoryImpl), 'updatePlanStatus', (async (): Promise<void> => {}) as Object);
      hooks.set(Object(EventRepositoryImpl), 'insertEvent', (async (): Promise<number> => 1) as Object);
      PlanImportExportService.setDepsForTest(null);

      // Act
      const newPlanId = await PlanImportExportService.importPlanFromJson('{}');

      // Assert
      expect(newPlanId).assertEqual(9001);
      expect(store.beginCount).assertEqual(1);
      expect(store.commitCount).assertEqual(1);
      expect(createCalls).assertEqual(1);
      hooks.restoreAll();
      PlanImportExportService.setDepsForTest(null);
    });

    it('boundary: import_should_rollback_when_create_plan_returns_zero', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      const store = new TxStoreMockBQ();
      hooks.keep(Object(PlanSerializer), 'deserializePlan');
      hooks.keep(Object(RdbHelper), 'getInstance');
      hooks.keep(Object(PlanRepositoryImpl), 'createPlan');
      hooks.set(Object(PlanSerializer), 'deserializePlan', ((_raw: string): ParsedPlanResultBQ => new ParsedPlanResultBQ()) as Object);
      hooks.set(Object(RdbHelper), 'getInstance', (() => new RdbHelperInstanceMockBQ(store)) as Object);
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
      PlanImportExportService.setDepsForTest(null);
    });

    it('invalid: import_should_throw_db_not_ready_when_store_missing', 0, async () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(PlanSerializer), 'deserializePlan');
      hooks.keep(Object(RdbHelper), 'getInstance');
      hooks.set(Object(PlanSerializer), 'deserializePlan', ((_raw: string): ParsedPlanResultBQ => new ParsedPlanResultBQ()) as Object);
      hooks.set(Object(RdbHelper), 'getInstance', (() => new RdbHelperInstanceMockBQ(null)) as Object);
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
      PlanImportExportService.setDepsForTest(null);
    });
  });

  describe('phase2BatchBQ_avatar_upload', () => {
    it('normal: avatar_upload_should_sync_when_gateway_success', 0, async () => {
      // Arrange
      const options = new AvatarApiOptionsMockBQ();
      const api = new AvatarUploadApi(options);

      // Act
      const result = await api.uploadAvatar(createAvatarInputBQ());

      // Assert
      expect(String(result.status)).assertEqual('SYNCED');
      expect(String(result.remoteUrl || '')).assertEqual('https://example.com/bq.jpg');
    });

    it('boundary: avatar_upload_should_return_local_only_when_gateway_non_zero', 0, async () => {
      // Arrange
      const options = new AvatarApiOptionsMockBQ();
      options.responseCode = 401;
      const api = new AvatarUploadApi(options);

      // Act
      const result = await api.uploadAvatar(createAvatarInputBQ());

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('401');
    });

    it('invalid: avatar_upload_should_return_upload_exception_when_encode_failed', 0, async () => {
      // Arrange
      const options = new AvatarApiOptionsMockBQ();
      options.shouldEncodeThrow = true;
      const api = new AvatarUploadApi(options);

      // Act
      const result = await api.uploadAvatar(createAvatarInputBQ());

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('UPLOAD_EXCEPTION');
    });

    it('invalid: avatar_upload_should_return_no_session_when_token_missing', 0, async () => {
      // Arrange
      const options = new AvatarApiOptionsMockBQ();
      options.token = '';
      const api = new AvatarUploadApi(options);

      // Act
      const result = await api.uploadAvatar(createAvatarInputBQ());

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('NO_SESSION');
    });

    it('regression: avatar_upload_should_keep_no_session_when_token_resolver_returns_empty', 0, async () => {
      // Arrange
      const options = new AvatarApiOptionsMockBQ();
      options.token = '';
      const api = new AvatarUploadApi(options);

      // Act
      const result = await api.uploadAvatar(createAvatarInputBQ());

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('NO_SESSION');
      expect(String(result.remoteUrl || '')).assertEqual('');
    });

    it('conflict: avatar_upload_should_prefer_gateway_error_over_remote_url_on_non_zero_code', 0, async () => {
      // Arrange
      const options = new AvatarApiOptionsMockBQ();
      options.responseCode = 409;
      options.remoteUrl = 'https://example.com/should-not-use.jpg';
      const api = new AvatarUploadApi(options);

      // Act
      const result = await api.uploadAvatar(createAvatarInputBQ());

      // Assert
      expect(String(result.status)).assertEqual('LOCAL_ONLY');
      expect(String(result.errorCode || '')).assertEqual('409');
      expect(String(result.remoteUrl || '')).assertEqual('');
    });
  });

  describe('phase2BatchBQ_session_manager', () => {
    it('normal: session_manager_should_delegate_save_load_and_clear', 0, () => {
      // Arrange
      const hooks = new HooksBQ();
      let saveCount = 0;
      let clearCount = 0;
      let savedAccountId = '';
      hooks.keep(Object(AuthSessionStore), 'save');
      hooks.keep(Object(AuthSessionStore), 'load');
      hooks.keep(Object(AuthSessionStore), 'clear');
      hooks.set(Object(AuthSessionStore), 'save', ((payload: AuthSessionPayload): void => {
        saveCount += 1;
        savedAccountId = payload.accountId;
      }) as Object);
      hooks.set(Object(AuthSessionStore), 'load', (() => createPayloadBQ(Date.now() + 60_000)) as Object);
      hooks.set(Object(AuthSessionStore), 'clear', (() => {
        clearCount += 1;
      }) as Object);
      const manager = SessionManager.getInstance();

      // Act
      manager.save(createSessionBQ(Date.now() + 60_000));
      const restored = manager.load();
      const accountId = manager.getCurrentAccountId();
      const loggedIn = manager.isLoggedIn();
      manager.clear();

      // Assert
      expect(saveCount).assertEqual(1);
      expect(savedAccountId).assertEqual('acc_bq');
      expect(restored?.accountId || '').assertEqual('acc_bq');
      expect(accountId).assertEqual('acc_bq');
      expect(loggedIn).assertTrue();
      expect(clearCount).assertEqual(1);
      hooks.restoreAll();
    });

    it('boundary: session_manager_should_treat_expired_payload_as_logged_out', 0, () => {
      // Arrange
      const hooks = new HooksBQ();
      hooks.keep(Object(AuthSessionStore), 'load');
      hooks.set(Object(AuthSessionStore), 'load', (() => createPayloadBQ(Date.now() - 1)) as Object);
      const manager = SessionManager.getInstance();

      // Act
      const restored = manager.load();
      const accountId = manager.getCurrentAccountId();
      const loggedIn = manager.isLoggedIn();

      // Assert
      expect(restored === null).assertTrue();
      expect(accountId).assertEqual('');
      expect(loggedIn).assertFalse();
      hooks.restoreAll();
    });
  });

  describe('phase2BatchBQ_amap_public_helpers', () => {
    it('normal: fallback_rule_should_depend_on_nearby_count', 0, () => {
      // Arrange
      // Act
      const fallbackWhenLow = AmapService.shouldFallbackToNationwide(1);
      const fallbackWhenEnough = AmapService.shouldFallbackToNationwide(5);

      // Assert
      expect(fallbackWhenLow).assertTrue();
      expect(fallbackWhenEnough).assertFalse();
    });

    it('boundary: parse_poi_response_should_return_items_for_valid_payload', 0, () => {
      // Arrange
      const payload = '{"status":"1","pois":[{"name":"K","address":"A","location":"121.5,31.2","distance":"12"}]}' ;

      // Act
      const items = AmapService.parsePoiResponse(payload);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('K');
    });

    it('combined: normalize_and_merge_should_remove_invalid_and_duplicate_items', 0, () => {
      // Arrange
      const invalidNode = new AmapPoiNodeMockBQ();
      invalidNode.name = 'bad';
      invalidNode.location = '';
      const validNode = new AmapPoiNodeMockBQ();
      validNode.name = 'N1';
      validNode.address = 'A1';
      validNode.location = '121.500000,31.200000';
      validNode.distance = '8';
      const nodes: AmapPoiSearchNode[] = [invalidNode, validNode];
      const primary = AmapService.normalizePoiNodes(nodes);
      const duplicate = new PoiSearchItem('N1', 'A1', 31.2, 121.5, 8);
      const secondary: PoiSearchItem[] = [duplicate, new PoiSearchItem('N2', 'A2', 31.21, 121.51, 10)];

      // Act
      const merged = AmapService.mergePoiResults(primary, secondary, 10);

      // Assert
      expect(primary.length).assertEqual(1);
      expect(merged.length).assertEqual(2);
      expect(merged[0].name).assertEqual('N1');
      expect(merged[1].name).assertEqual('N2');
    });
  });
}
