import { describe, it, expect } from '@ohos/hypium';
import { relationalStore } from '@kit.ArkData';
import { CloudDBZoneQuery } from '@hw-agconnect/database-ohos';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { ProfileCacheManager } from '../main/ets/infrastructure/cache/ProfileCacheManager';
import { WeatherCache } from '../main/ets/infrastructure/services/WeatherCache';
import { RdbHelper } from '../main/ets/common/utils/RdbHelper';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanEntity } from '../main/ets/model/entity/PlanEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { WeatherSnapshot } from '../main/ets/domain/services/WeatherModels';

class FakePredicatesAR {
  public readonly tableName: string;
  public readonly clauses: string[] = [];

  constructor(tableName: string) {
    this.tableName = tableName;
  }

  equalTo(column: string, value: Object): FakePredicatesAR {
    this.clauses.push(`eq:${column}:${String(value)}`);
    return this;
  }

  and(): FakePredicatesAR {
    this.clauses.push('and');
    return this;
  }

  greaterThan(column: string, value: Object): FakePredicatesAR {
    this.clauses.push(`gt:${column}:${String(value)}`);
    return this;
  }

  lessThanOrEqualTo(column: string, value: Object): FakePredicatesAR {
    this.clauses.push(`lte:${column}:${String(value)}`);
    return this;
  }

  orderByAsc(column: string): FakePredicatesAR {
    this.clauses.push(`asc:${column}`);
    return this;
  }

  orderByDesc(column: string): FakePredicatesAR {
    this.clauses.push(`desc:${column}`);
    return this;
  }
}

class FakeResultSetAR {
  private readonly rows: Object[];
  private cursor: number = -1;
  private lastColumn: string = '';
  public closeCount: number = 0;

  constructor(rows: Object[]) {
    this.rows = rows;
  }

  goToFirstRow(): boolean {
    if (this.rows.length === 0) {
      this.cursor = -1;
      return false;
    }
    this.cursor = 0;
    return true;
  }

  goToNextRow(): boolean {
    if (this.cursor < 0) {
      this.cursor = 0;
    } else {
      this.cursor += 1;
    }
    return this.cursor < this.rows.length;
  }

  getColumnIndex(name: string): number {
    this.lastColumn = name;
    return 0;
  }

  getLong(_index: number): number {
    return Number(Reflect.get(this.getCurrentRow(), this.lastColumn) ?? 0);
  }

  getDouble(_index: number): number {
    return Number(Reflect.get(this.getCurrentRow(), this.lastColumn) ?? 0);
  }

  getString(_index: number): string {
    const value: Object = Reflect.get(this.getCurrentRow(), this.lastColumn) as Object;
    if (value === null || value === undefined) {
      return '';
    }
    return String(value);
  }

  close(): void {
    this.closeCount += 1;
  }

  private getCurrentRow(): Object {
    if (this.cursor < 0 || this.cursor >= this.rows.length) {
      return new Object();
    }
    return this.rows[this.cursor];
  }
}

interface InsertCallAR {
  tableName: string;
  valueBucket: Object;
}

interface UpdateCallAR {
  valueBucket: Object;
  predicates: Object;
}

interface EventRowAR {
  id: number;
  plan_id: number;
  name: string;
  note: string;
  travel_mode: number;
  duration: number;
  status: number;
  lock_status: number;
  fixed_start_time: string;
  day_offset: number;
  sort_order: number;
  type: number;
  priority: number;
  pre_travel_min: number;
  is_travel_manual: number;
  latitude: number;
  longitude: number;
  source: number;
  address: string;
  ai_reasoning: string;
  group_id: number;
  del_flag: number;
  actual_start_time: number;
  actual_end_time: number;
  completion_status: number;
  weather_condition: string;
  weather_temperature: number;
  weather_text: string;
  weather_fetch_time: number;
}

interface PlanRowAR {
  id: number;
  del_flag: number;
  status: number;
}

interface CloudRowAR {
  accountId: string;
  username: string;
  avatarPath: string;
  avatarVersion: number;
  isInitialized: boolean;
  createdAt: FakeLongValueAR;
  updatedAt: FakeStringLongValueAR;
}

interface ContextAR {
  label: string;
  getApplicationContext: () => Object;
}

interface AppContextAR {
  label: string;
}

interface IdRowAR {
  id: number;
}

interface PlanIdRowAR {
  plan_id: number;
}

interface EventStateRowAR {
  id: number;
  plan_id: number;
  status: number;
  actual_start_time: number;
  actual_end_time: number;
  completion_status: number;
}

interface ActiveEventRowAR {
  id: number;
  plan_id: number;
  name: string;
  actual_start_time: number;
}

class FakeRdbStoreAR {
  public beginCount: number = 0;
  public commitCount: number = 0;
  public rollbackCount: number = 0;
  public insertCalls: Object[] = [];
  public updateCalls: Object[] = [];
  public deleteCalls: Object[] = [];
  public queryCalls: Object[] = [];
  private readonly insertOutcomes: Array<number | Error> = [];
  private readonly updateOutcomes: Array<number | Error> = [];
  private readonly deleteOutcomes: Array<number | Error> = [];
  private readonly queryOutcomes: Array<FakeResultSetAR | Error> = [];

  beginTransaction(): void {
    this.beginCount += 1;
  }

  commit(): void {
    this.commitCount += 1;
  }

  rollBack(): void {
    this.rollbackCount += 1;
  }

  queueInsertResult(id: number): void {
    this.insertOutcomes.push(id);
  }

  queueInsertError(message: string): void {
    this.insertOutcomes.push(new Error(message));
  }

  queueUpdateResult(changedRows: number): void {
    this.updateOutcomes.push(changedRows);
  }

  queueUpdateError(message: string): void {
    this.updateOutcomes.push(new Error(message));
  }

  queueDeleteResult(changedRows: number): void {
    this.deleteOutcomes.push(changedRows);
  }

  queueDeleteError(message: string): void {
    this.deleteOutcomes.push(new Error(message));
  }

  queueQueryRows(rows: Object[]): FakeResultSetAR {
    const set = new FakeResultSetAR(rows);
    this.queryOutcomes.push(set);
    return set;
  }

  queueQueryError(message: string): void {
    this.queryOutcomes.push(new Error(message));
  }

  async insert(tableName: string, valueBucket: Object): Promise<number> {
    const insertCall: InsertCallAR = { tableName: tableName, valueBucket: valueBucket };
    this.insertCalls.push(insertCall);
    const outcome = this.insertOutcomes.length > 0 ? this.insertOutcomes.shift() : 1;
    if (outcome instanceof Error) {
      throw outcome;
    }
    return Number(outcome);
  }

  async update(valueBucket: Object, predicates: Object): Promise<number> {
    const updateCall: UpdateCallAR = { valueBucket: valueBucket, predicates: predicates };
    this.updateCalls.push(updateCall);
    const outcome = this.updateOutcomes.length > 0 ? this.updateOutcomes.shift() : 1;
    if (outcome instanceof Error) {
      throw outcome;
    }
    return Number(outcome);
  }

  async delete(predicates: Object): Promise<number> {
    this.deleteCalls.push(predicates);
    const outcome = this.deleteOutcomes.length > 0 ? this.deleteOutcomes.shift() : 1;
    if (outcome instanceof Error) {
      throw outcome;
    }
    return Number(outcome);
  }

  async query(predicates: Object): Promise<FakeResultSetAR> {
    this.queryCalls.push(predicates);
    const outcome = this.queryOutcomes.length > 0 ? this.queryOutcomes.shift() : new FakeResultSetAR([]);
    if (outcome instanceof Error) {
      throw outcome;
    }
    return outcome!;
  }
}

class FakeRdbHelperAR {
  private readonly store: Object | null;

  constructor(store: Object | null) {
    this.store = store;
  }

  getRdbStore(): Object | null {
    return this.store;
  }
}

class RdbHooksAR {
  private readonly originGetInstance: Object;
  private readonly originPredicates: Object;

  constructor() {
    this.originGetInstance = Reflect.get(RdbHelper, 'getInstance') as Object;
    this.originPredicates = Reflect.get(Reflect.get(globalThis, 'relationalStore') as Object, 'RdbPredicates') as Object;
  }

  bindStore(store: Object | null): void {
    Reflect.set(RdbHelper, 'getInstance', (): Object => new FakeRdbHelperAR(store) as Object);
    Reflect.set(Reflect.get(globalThis, 'relationalStore') as Object, 'RdbPredicates', FakePredicatesAR);
  }

  restore(): void {
    Reflect.set(RdbHelper, 'getInstance', this.originGetInstance);
    Reflect.set(Reflect.get(globalThis, 'relationalStore') as Object, 'RdbPredicates', this.originPredicates);
  }
}

class FakeLongValueAR {
  private readonly value: number;

  constructor(value: number) {
    this.value = value;
  }

  toNumber(): number {
    return this.value;
  }
}

class FakeStringLongValueAR {
  private readonly value: number;

  constructor(value: number) {
    this.value = value;
  }

  toString(): string {
    return String(this.value);
  }
}

class FakeCloudQueryBuilderAR {
  public equalField: string = '';
  public equalValue: Object | null = null;
  public limitValue: number = 0;

  equalTo(field: string, value: Object): FakeCloudQueryBuilderAR {
    this.equalField = field;
    this.equalValue = value;
    return this;
  }

  limit(value: number): FakeCloudQueryBuilderAR {
    this.limitValue = value;
    return this;
  }
}

class FakeCloudSnapshotAR {
  private readonly rows: Object[];

  constructor(rows: Object[]) {
    this.rows = rows;
  }

  getSnapshotObjects(): Object[] {
    return this.rows;
  }
}

class FakeCloudZoneAR {
  public queryCalls: Object[] = [];
  public upsertCalls: Object[] = [];
  private readonly queryOutcomes: Array<FakeCloudSnapshotAR | Error> = [];
  private readonly upsertOutcomes: Array<boolean | Error> = [];

  queueQueryRows(rows: Object[]): void {
    this.queryOutcomes.push(new FakeCloudSnapshotAR(rows));
  }

  queueQueryError(message: string): void {
    this.queryOutcomes.push(new Error(message));
  }

  queueUpsertError(message: string): void {
    this.upsertOutcomes.push(new Error(message));
  }

  async executeQuery(query: Object): Promise<FakeCloudSnapshotAR> {
    this.queryCalls.push(query);
    const outcome = this.queryOutcomes.length > 0 ? this.queryOutcomes.shift() : new FakeCloudSnapshotAR([]);
    if (outcome instanceof Error) {
      throw outcome;
    }
    return outcome!;
  }

  async executeUpsert(record: Object): Promise<void> {
    this.upsertCalls.push(record);
    const outcome = this.upsertOutcomes.length > 0 ? this.upsertOutcomes.shift() : true;
    if (outcome instanceof Error) {
      throw outcome;
    }
  }
}

class CloudQueryHooksAR {
  private readonly originWhere: Object;

  constructor() {
    this.originWhere = Reflect.get(CloudDBZoneQuery as Object, 'where') as Object;
  }

  install(): void {
    Reflect.set(CloudDBZoneQuery as Object, 'where', (_klass: Object): Object => new FakeCloudQueryBuilderAR() as Object);
  }

  restore(): void {
    Reflect.set(CloudDBZoneQuery as Object, 'where', this.originWhere);
  }
}

class FakePreferenceManagerAR {
  public initCount: number = 0;
  public getProfileCalls: number = 0;
  public setProfileCalls: number = 0;
  public clearProfileCalls: number = 0;
  private readonly profileCache: Map<string, string> = new Map<string, string>();

  setRaw(accountId: string, raw: string): void {
    this.profileCache.set(accountId, raw);
  }

  async init(_context: Object): Promise<void> {
    this.initCount += 1;
  }

  async getProfileCacheJson(accountId: string): Promise<string> {
    this.getProfileCalls += 1;
    return this.profileCache.get(accountId) ?? '';
  }

  async setProfileCacheJson(accountId: string, raw: string): Promise<void> {
    this.setProfileCalls += 1;
    this.profileCache.set(accountId, raw);
  }

  async clearProfileCache(accountId: string): Promise<void> {
    this.clearProfileCalls += 1;
    this.profileCache.delete(accountId);
  }
}

class PreferenceHooksAR {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
  }

  setInstance(instance: Object): void {
    Reflect.set(PreferenceManager, 'getInstance', (): Object => instance);
  }

  restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originGetInstance);
  }
}

class DateNowHooksAR {
  private readonly originNow: Object;

  constructor() {
    this.originNow = Reflect.get(Date, 'now') as Object;
  }

  setNow(value: number): void {
    Reflect.set(Date, 'now', (): number => value);
  }

  restore(): void {
    Reflect.set(Date, 'now', this.originNow);
  }
}

class MathRandomHooksAR {
  private readonly originRandom: Object;

  constructor() {
    this.originRandom = Reflect.get(Math, 'random') as Object;
  }

  setRandom(fn: () => number): void {
    Reflect.set(Math, 'random', fn);
  }

  restore(): void {
    Reflect.set(Math, 'random', this.originRandom);
  }
}

class UserProfileSingletonHooksAR {
  private readonly originInstance: Object;

  constructor() {
    this.originInstance = Reflect.get(UserProfileRepositoryImpl as Object, 'instance') as Object;
  }

  reset(): void {
    Reflect.set(UserProfileRepositoryImpl as Object, 'instance', new UserProfileRepositoryImpl() as Object);
  }

  setInstance(instance: Object): void {
    Reflect.set(UserProfileRepositoryImpl as Object, 'instance', instance);
  }

  restore(): void {
    Reflect.set(UserProfileRepositoryImpl as Object, 'instance', this.originInstance);
  }
}

class ProfileCacheSingletonHooksAR {
  private readonly originInstance: Object;

  constructor() {
    this.originInstance = Reflect.get(ProfileCacheManager as Object, 'instance') as Object;
  }

  reset(): void {
    Reflect.set(ProfileCacheManager as Object, 'instance', new ProfileCacheManager() as Object);
  }

  setInstance(instance: Object): void {
    Reflect.set(ProfileCacheManager as Object, 'instance', instance);
  }

  restore(): void {
    Reflect.set(ProfileCacheManager as Object, 'instance', this.originInstance);
  }
}

function clearDirtyPlanIdsAR(): void {
  EventRepositoryImpl.consumeDirtyPlanIds();
}

function createEventRowAR(id: number, planId: number): Object {
  const row: EventRowAR = {
    id: id,
    plan_id: planId,
    name: 'Spot',
    note: 'memo',
    travel_mode: 2,
    duration: 90,
    status: 1,
    lock_status: 1,
    fixed_start_time: '09:00',
    day_offset: 2,
    sort_order: 30,
    type: 0,
    priority: 1,
    pre_travel_min: 15,
    is_travel_manual: 1,
    latitude: 31.23,
    longitude: 121.47,
    source: 2,
    address: 'Bund',
    ai_reasoning: 'reason',
    group_id: 9,
    del_flag: 0,
    actual_start_time: 100,
    actual_end_time: 200,
    completion_status: 1,
    weather_condition: 'SUNNY',
    weather_temperature: 26.5,
    weather_text: 'clear',
    weather_fetch_time: 300
  };
  return row;
}

function createPlanRowAR(id: number, delFlag: number, status: number): Object {
  const row: PlanRowAR = {
    id: id,
    del_flag: delFlag,
    status: status
  };
  return row;
}

function createIdRowAR(id: number): Object {
  const row: IdRowAR = { id: id };
  return row;
}

function createPlanIdRowAR(planId: number): Object {
  const row: PlanIdRowAR = { plan_id: planId };
  return row;
}

function createEventStateRowAR(
  id: number,
  planId: number,
  status: number,
  actualStartTime: number,
  actualEndTime: number,
  completionStatus: number
): Object {
  const row: EventStateRowAR = {
    id: id,
    plan_id: planId,
    status: status,
    actual_start_time: actualStartTime,
    actual_end_time: actualEndTime,
    completion_status: completionStatus
  };
  return row;
}

function createActiveEventRowAR(id: number, planId: number, name: string, actualStartTime: number): Object {
  const row: ActiveEventRowAR = {
    id: id,
    plan_id: planId,
    name: name,
    actual_start_time: actualStartTime
  };
  return row;
}

function createTravelPlanItemAR(name: string, id: number = 0): TravelPlanItem {
  return {
    id: id,
    name: name,
    note: 'note',
    duration: 60,
    type: 'FLOW',
    preTravelMinutes: 12,
    sortOrder: 100,
    status: 1,
    lockStatus: 0,
    fixedStartTime: '09:00',
    dayOffset: 1,
    itemType: 0,
    priority: 1,
    transportMode: 2,
    travelMode: 2,
    isTravelManual: 1,
    source: 2,
    delFlag: 0,
    groupId: 7,
    address: 'addr',
    aiReasoning: 'why',
    latitude: 31.2,
    longitude: 121.5,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0,
    weatherCondition: 'CLOUDY',
    weatherTemperature: 23,
    weatherText: 'mild',
    weatherFetchTime: 11
  };
}

function createProfileAR(accountId: string, username: string = 'Alice'): UserProfileEntity {
  const profile = new UserProfileEntity();
  profile.profileId = accountId;
  profile.accountId = accountId;
  profile.username = username;
  profile.avatarPath = 'app.media.headphoto';
  profile.avatarVersion = 2;
  profile.isInitialized = true;
  profile.createdAt = 111;
  profile.updatedAt = 222;
  return profile;
}

function createCloudRowAR(accountId: string, username: string = 'Alice'): Object {
  const row: CloudRowAR = {
    accountId: ` ${accountId} `,
    username: ` ${username} `,
    avatarPath: ' app.media.headphoto ',
    avatarVersion: 3,
    isInitialized: true,
    createdAt: new FakeLongValueAR(333),
    updatedAt: new FakeStringLongValueAR(444)
  };
  return row;
}

function createWeatherSnapshotAR(locationKey: string = '31.230:121.470:10'): WeatherSnapshot {
  return {
    locationKey: locationKey,
    sourceType: 'PLAN_LOCATION',
    weatherTime: 100,
    fetchTime: 200,
    conditionCode: 'SUNNY',
    conditionText: 'Clear',
    temperatureCelsius: 28
  };
}

function createContextAR(label: string): Object {
  const appCtx: AppContextAR = { label: `${label}_app` };
  const ctx: ContextAR = {
    label: label,
    getApplicationContext: (): Object => appCtx
  };
  return ctx;
}

function getMemoryCacheAR(cache: Object): Map<string, UserProfileEntity> {
  return Reflect.get(cache, 'memoryCache') as Map<string, UserProfileEntity>;
}

export default function phase2BatchARTest() {
  describe('phase2BatchAR_event_repository', () => {
    it('normal: mark_plan_dirty_should_append_valid_plan_id', 0, () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      EventRepositoryImpl.markPlanDirty(11);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual(11);
    });

    it('boundary: mark_plan_dirty_should_keep_unique_ids', 0, () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      EventRepositoryImpl.markPlanDirty(12);
      EventRepositoryImpl.markPlanDirty(12);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      expect(ids.length).assertEqual(1);
      expect(ids[0]).assertEqual(12);
    });

    it('invalid: mark_plan_dirty_should_ignore_non_positive_or_nan', 0, () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      EventRepositoryImpl.markPlanDirty(0);
      EventRepositoryImpl.markPlanDirty(-1);
      EventRepositoryImpl.markPlanDirty(Number.NaN);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      expect(ids.length).assertEqual(0);
    });

    it('normal: consume_dirty_plan_ids_should_return_in_insertion_order', 0, () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      EventRepositoryImpl.markPlanDirty(21);
      EventRepositoryImpl.markPlanDirty(22);
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual(21);
      expect(ids[1]).assertEqual(22);
    });

    it('boundary: consume_dirty_plan_ids_should_return_empty_array_when_pool_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      expect(ids.length).assertEqual(0);
    });

    it('invalid: consume_dirty_plan_ids_should_tolerate_repeat_read_after_clear', 0, () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      EventRepositoryImpl.markPlanDirty(23);
      EventRepositoryImpl.consumeDirtyPlanIds();
      const ids = EventRepositoryImpl.consumeDirtyPlanIds();
      expect(ids.length).assertEqual(0);
    });

    it('normal: insert_event_should_insert_and_mark_plan_dirty', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueInsertResult(101);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const rowId = await EventRepositoryImpl.insertEvent(31, createTravelPlanItemAR('Insert'));
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(rowId).assertEqual(101);
        expect(store.insertCalls.length).assertEqual(1);
        expect(dirty.length).assertEqual(1);
        expect(dirty[0]).assertEqual(31);
        const call = store.insertCalls[0] as Object;
        const bucket = Reflect.get(call, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.PLAN_ID))).assertEqual(31);
        expect(String(Reflect.get(bucket, EventEntity.NAME))).assertEqual('Insert');
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: insert_event_should_fill_default_values_for_optional_fields', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueInsertResult(102);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      const item = createTravelPlanItemAR('Defaults');
      Reflect.set(item as Object, 'note', undefined);
      Reflect.set(item as Object, 'travelMode', undefined);
      Reflect.set(item as Object, 'status', undefined);
      Reflect.set(item as Object, 'fixedStartTime', undefined);
      Reflect.set(item as Object, 'latitude', undefined);
      Reflect.set(item as Object, 'longitude', undefined);
      try {
        await EventRepositoryImpl.insertEvent(32, item);
        const call = store.insertCalls[0] as Object;
        const bucket = Reflect.get(call, 'valueBucket') as Object;
        expect(String(Reflect.get(bucket, EventEntity.NOTE))).assertEqual('');
        expect(Number(Reflect.get(bucket, EventEntity.TRAVEL_MODE))).assertEqual(0);
        expect(Number(Reflect.get(bucket, EventEntity.STATUS))).assertEqual(0);
        expect(Reflect.get(bucket, EventEntity.FIXED_START_TIME) === null).assertTrue();
        expect(Number(Reflect.get(bucket, EventEntity.LATITUDE))).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: insert_event_should_return_minus_one_when_insert_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueInsertError('insert_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const rowId = await EventRepositoryImpl.insertEvent(33, createTravelPlanItemAR('Broken'));
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(rowId).assertEqual(-1);
        expect(dirty.length).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('normal: save_all_events_should_update_insert_and_delete_stale_rows', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueInsertResult(501);
      const resultSet = store.queueQueryRows([
        { id: 101 } as IdRowAR,
        { id: 501 } as IdRowAR,
        { id: 999 } as IdRowAR
      ] as IdRowAR[]);
      store.queueDeleteResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      const first = createTravelPlanItemAR('Persisted', 101);
      const second = createTravelPlanItemAR('New');
      try {
        await EventRepositoryImpl.saveAllEvents(41, [first, second]);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.beginCount).assertEqual(1);
        expect(store.commitCount).assertEqual(1);
        expect(store.rollbackCount).assertEqual(0);
        expect(store.updateCalls.length).assertEqual(1);
        expect(store.insertCalls.length).assertEqual(1);
        expect(store.deleteCalls.length).assertEqual(1);
        expect(resultSet.closeCount).assertEqual(1);
        expect(dirty.length).assertEqual(1);
        expect(dirty[0]).assertEqual(41);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: save_all_events_should_recover_missing_row_with_original_id_bucket', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(0);
      store.queueInsertResult(601);
      store.queueQueryRows([createIdRowAR(601)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.saveAllEvents(42, [createTravelPlanItemAR('Recover', 555)]);
        expect(store.updateCalls.length).assertEqual(1);
        expect(store.insertCalls.length).assertEqual(1);
        const insertCall = store.insertCalls[0] as Object;
        const bucket = Reflect.get(insertCall, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.ID))).assertEqual(555);
        expect(store.commitCount).assertEqual(1);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: save_all_events_should_rollback_and_throw_when_store_update_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateError('save_all_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.saveAllEvents(43, [createTravelPlanItemAR('Throw', 123)]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('save_all_failed_ar');
      expect(store.rollbackCount).assertEqual(1);
      expect(store.commitCount).assertEqual(0);
    });

    it('normal: get_all_events_should_map_rows_into_items', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      const resultSet = store.queueQueryRows([createEventRowAR(71, 7001)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const items = await EventRepositoryImpl.getAllEvents(7001);
        expect(items.length).assertEqual(1);
        expect(items[0].id).assertEqual(71);
        expect(items[0].type).assertEqual('ANCHOR');
        expect(items[0].lockStatus).assertEqual(1);
        expect(items[0].weatherText).assertEqual('clear');
        expect(resultSet.closeCount).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('boundary: get_all_events_should_return_empty_array_when_store_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new RdbHooksAR();
      hooks.bindStore(null);
      try {
        const items = await EventRepositoryImpl.getAllEvents(7002);
        expect(items.length).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: get_all_events_should_return_empty_array_when_query_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryError('query_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const items = await EventRepositoryImpl.getAllEvents(7003);
        expect(items.length).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('normal: update_day_offset_should_write_value_and_mark_resolved_plan', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueQueryRows([createPlanIdRowAR(801)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateDayOffset(81, 3);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        const updateCall = store.updateCalls[0] as Object;
        const bucket = Reflect.get(updateCall, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.DAY_OFFSET))).assertEqual(3);
        expect(dirty[0]).assertEqual(801);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: update_day_offset_should_forward_negative_offsets', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueQueryRows([createPlanIdRowAR(802)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateDayOffset(82, -2);
        const updateCall = store.updateCalls[0] as Object;
        const bucket = Reflect.get(updateCall, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.DAY_OFFSET))).assertEqual(-2);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: update_day_offset_should_throw_when_update_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateError('update_day_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.updateDayOffset(83, 1);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('update_day_failed_ar');
    });

    it('normal: update_timeline_consistency_should_update_each_item_with_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueUpdateResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateTimelineConsistency([
          createTravelPlanItemAR('A', 91),
          createTravelPlanItemAR('B', 92)
        ], 803);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.beginCount).assertEqual(1);
        expect(store.commitCount).assertEqual(1);
        expect(store.updateCalls.length).assertEqual(2);
        expect(dirty[0]).assertEqual(803);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: update_timeline_consistency_should_skip_items_without_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateTimelineConsistency([createTravelPlanItemAR('NoId')], 804);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.beginCount).assertEqual(1);
        expect(store.commitCount).assertEqual(1);
        expect(store.updateCalls.length).assertEqual(0);
        expect(dirty[0]).assertEqual(804);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: update_timeline_consistency_should_rollback_and_swallow_store_error', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateError('timeline_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateTimelineConsistency([createTravelPlanItemAR('Broken', 93)], 805);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.rollbackCount).assertEqual(1);
        expect(store.commitCount).assertEqual(0);
        expect(dirty.length).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('normal: update_single_field_should_update_bucket_and_mark_dirty', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueQueryRows([createPlanIdRowAR(901)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateSingleField(101, EventEntity.STATUS, 1);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        const call = store.updateCalls[0] as Object;
        const bucket = Reflect.get(call, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.STATUS))).assertEqual(1);
        expect(dirty[0]).assertEqual(901);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: update_single_field_should_skip_plan_lookup_when_hint_provided', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateSingleField(102, EventEntity.DAY_OFFSET, 5, 902);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.queryCalls.length).assertEqual(0);
        expect(dirty[0]).assertEqual(902);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: update_single_field_should_throw_when_store_update_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateError('single_field_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.updateSingleField(103, EventEntity.STATUS, 1);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('single_field_failed_ar');
    });

    it('normal: update_fields_should_write_all_pairs_and_mark_dirty', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueQueryRows([createPlanIdRowAR(903)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateFields(104, [
          { column: EventEntity.STATUS, value: 1 },
          { column: EventEntity.DAY_OFFSET, value: 2 }
        ]);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        const call = store.updateCalls[0] as Object;
        const bucket = Reflect.get(call, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.STATUS))).assertEqual(1);
        expect(Number(Reflect.get(bucket, EventEntity.DAY_OFFSET))).assertEqual(2);
        expect(dirty[0]).assertEqual(903);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: update_fields_should_return_early_for_empty_updates', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.updateFields(105, []);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.updateCalls.length).assertEqual(0);
        expect(dirty.length).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: update_fields_should_throw_when_store_update_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateError('fields_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.updateFields(106, [{ column: EventEntity.STATUS, value: 1 }]);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('fields_failed_ar');
    });

    it('normal: apply_runtime_transition_should_start_pending_event', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(201, 9101, 1, 0, 0, EventEntity.STATE_PENDING)]);
      store.queueQueryRows([]);
      store.queueUpdateResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9101,
          eventId: 201,
          transition: 'START',
          timestamp: 1000
        });
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(result.ok).assertTrue();
        expect(result.reason).assertEqual('ok');
        expect(result.startTime).assertEqual(1000);
        expect(store.commitCount).assertEqual(1);
        expect(dirty[0]).assertEqual(9101);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: apply_runtime_transition_should_return_db_unavailable_when_store_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new RdbHooksAR();
      hooks.bindStore(null);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9102,
          eventId: 202,
          transition: 'START',
          timestamp: 1000
        });
        expect(result.ok === false).assertTrue();
        expect(result.reason).assertEqual('db_unavailable');
      } finally {
        hooks.restore();
      }
    });

    it('boundary: apply_runtime_transition_should_return_not_found_when_target_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9103,
          eventId: 203,
          transition: 'START',
          timestamp: 1000
        });
        expect(result.reason).assertEqual('not_found');
        expect(store.rollbackCount).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('boundary: apply_runtime_transition_should_return_not_scheduled_when_status_not_schedule', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(204, 9104, 0, 0, 0, EventEntity.STATE_PENDING)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9104,
          eventId: 204,
          transition: 'START',
          timestamp: 1000
        });
        expect(result.reason).assertEqual('not_scheduled');
      } finally {
        hooks.restore();
      }
    });

    it('invalid: apply_runtime_transition_should_reject_invalid_start_state', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(205, 9105, 1, 99, 0, EventEntity.STATE_PENDING)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9105,
          eventId: 205,
          transition: 'START',
          timestamp: 1000
        });
        expect(result.reason).assertEqual('invalid_start_state');
      } finally {
        hooks.restore();
      }
    });

    it('invalid: apply_runtime_transition_should_reject_when_other_active_exists', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(206, 9106, 1, 0, 0, EventEntity.STATE_PENDING)]);
      store.queueQueryRows([createEventStateRowAR(999, 777, 1, 10, 0, EventEntity.STATE_PENDING)]);
      store.queueQueryRows([createPlanRowAR(777, 0, 1)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9106,
          eventId: 206,
          transition: 'START',
          timestamp: 1000
        });
        expect(result.reason).assertEqual('active_exists');
      } finally {
        hooks.restore();
      }
    });

    it('normal: apply_runtime_transition_should_complete_started_event', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(207, 9107, 1, 11, 0, EventEntity.STATE_PENDING)]);
      store.queueUpdateResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9107,
          eventId: 207,
          transition: 'END',
          timestamp: 1200
        });
        expect(result.ok).assertTrue();
        expect(result.endTime).assertEqual(1200);
        expect(result.completionStatus).assertEqual(EventEntity.STATE_COMPLETED);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: apply_runtime_transition_should_reject_invalid_end_state', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(208, 9108, 1, 0, 0, EventEntity.STATE_PENDING)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9108,
          eventId: 208,
          transition: 'END',
          timestamp: 1300
        });
        expect(result.reason).assertEqual('invalid_end_state');
      } finally {
        hooks.restore();
      }
    });

    it('normal: apply_runtime_transition_should_skip_pending_event', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(209, 9109, 1, 0, 0, EventEntity.STATE_PENDING)]);
      store.queueUpdateResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9109,
          eventId: 209,
          transition: 'SKIP',
          timestamp: 1400
        });
        expect(result.ok).assertTrue();
        expect(result.endTime).assertEqual(1400);
        expect(result.completionStatus).assertEqual(EventEntity.STATE_SKIPPED);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: apply_runtime_transition_should_reject_invalid_skip_state', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(210, 9110, 1, 0, 0, EventEntity.STATE_COMPLETED)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9110,
          eventId: 210,
          transition: 'SKIP',
          timestamp: 1500
        });
        expect(result.reason).assertEqual('invalid_skip_state');
      } finally {
        hooks.restore();
      }
    });

    it('normal: apply_runtime_transition_should_reopen_skipped_event', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(211, 9111, 1, 50, 60, EventEntity.STATE_SKIPPED)]);
      store.queueUpdateResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9111,
          eventId: 211,
          transition: 'REOPEN',
          timestamp: 1600
        });
        expect(result.ok).assertTrue();
        expect(result.startTime).assertEqual(0);
        expect(result.endTime).assertEqual(0);
        expect(result.completionStatus).assertEqual(EventEntity.STATE_PENDING);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: apply_runtime_transition_should_reject_invalid_reopen_state', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createEventStateRowAR(212, 9112, 1, 0, 0, EventEntity.STATE_PENDING)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9112,
          eventId: 212,
          transition: 'REOPEN',
          timestamp: 1700
        });
        expect(result.reason).assertEqual('invalid_reopen_state');
      } finally {
        hooks.restore();
      }
    });

    it('invalid: apply_runtime_transition_should_return_exception_when_query_throws', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryError('runtime_query_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.applyRuntimeTransition({
          planId: 9113,
          eventId: 213,
          transition: 'START',
          timestamp: 1800
        });
        expect(result.reason).assertEqual('exception');
        expect(store.rollbackCount).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('normal: find_global_active_event_should_return_first_usable_active_item', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createActiveEventRowAR(301, 9201, 'ActiveA', 111)]);
      store.queueQueryRows([createPlanRowAR(9201, 0, 1)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.findGlobalActiveEvent();
        expect(result !== null).assertTrue();
        expect(result?.eventId).assertEqual(301);
        expect(result?.name).assertEqual('ActiveA');
      } finally {
        hooks.restore();
      }
    });

    it('boundary: find_global_active_event_should_skip_excluded_and_unusable_plans', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([
        createActiveEventRowAR(302, 9202, 'Excluded', 200),
        createActiveEventRowAR(303, 9203, 'TrashPlan', 190),
        createActiveEventRowAR(304, 9204, 'Winner', 180)
      ]);
      store.queueQueryRows([createPlanRowAR(9203, 1, 0)]);
      store.queueQueryRows([createPlanRowAR(9204, 0, 1)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.findGlobalActiveEvent(302);
        expect(result !== null).assertTrue();
        expect(result?.eventId).assertEqual(304);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: find_global_active_event_should_return_null_when_query_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const store = new FakeRdbStoreAR();
      store.queueQueryError('find_active_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        const result = await EventRepositoryImpl.findGlobalActiveEvent();
        expect(result === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('normal: soft_delete_event_should_set_del_flag_and_mark_dirty', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueQueryRows([createPlanIdRowAR(9301)]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.softDeleteEvent(401);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        const call = store.updateCalls[0] as Object;
        const bucket = Reflect.get(call, 'valueBucket') as Object;
        expect(Number(Reflect.get(bucket, EventEntity.DEL_FLAG))).assertEqual(1);
        expect(dirty[0]).assertEqual(9301);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: soft_delete_event_should_not_mark_dirty_when_plan_lookup_misses', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateResult(1);
      store.queueQueryRows([]);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.softDeleteEvent(402);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.updateCalls.length).assertEqual(1);
        expect(dirty.length).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: soft_delete_event_should_throw_when_update_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueUpdateError('soft_delete_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.softDeleteEvent(403);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('soft_delete_failed_ar');
    });

    it('normal: hard_delete_event_should_delete_row_and_mark_dirty_when_plan_found', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createPlanIdRowAR(9401)]);
      store.queueDeleteResult(1);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.hardDeleteEvent(501);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.deleteCalls.length).assertEqual(1);
        expect(dirty[0]).assertEqual(9401);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: hard_delete_event_should_return_when_store_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const hooks = new RdbHooksAR();
      hooks.bindStore(null);
      try {
        await EventRepositoryImpl.hardDeleteEvent(502);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(dirty.length).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: hard_delete_event_should_throw_when_delete_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueQueryRows([createPlanIdRowAR(9402)]);
      store.queueDeleteError('hard_delete_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.hardDeleteEvent(503);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('hard_delete_failed_ar');
    });

    it('normal: delete_events_by_source_should_delete_and_mark_dirty', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueDeleteResult(2);
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      try {
        await EventRepositoryImpl.deleteEventsBySource(9501, 2);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(store.deleteCalls.length).assertEqual(1);
        expect(dirty[0]).assertEqual(9501);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('boundary: delete_events_by_source_should_return_when_store_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const hooks = new RdbHooksAR();
      hooks.bindStore(null);
      try {
        await EventRepositoryImpl.deleteEventsBySource(9502, 3);
        const dirty = EventRepositoryImpl.consumeDirtyPlanIds();
        expect(dirty.length).assertEqual(0);
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
    });

    it('invalid: delete_events_by_source_should_throw_when_delete_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      clearDirtyPlanIdsAR();
      const store = new FakeRdbStoreAR();
      store.queueDeleteError('delete_by_source_failed_ar');
      const hooks = new RdbHooksAR();
      hooks.bindStore(store as Object);
      let message = '';
      try {
        await EventRepositoryImpl.deleteEventsBySource(9503, 4);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
        clearDirtyPlanIdsAR();
      }
      expect(message).assertEqual('delete_by_source_failed_ar');
    });
  });

  describe('phase2BatchAR_user_profile_repository', () => {
    it('normal: get_instance_should_return_singleton_instance', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileSingletonHooksAR();
      try {
        const first = UserProfileRepositoryImpl.getInstance();
        const second = UserProfileRepositoryImpl.getInstance();
        expect(first === second).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('boundary: get_instance_should_create_new_instance_after_reset', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileSingletonHooksAR();
      try {
        hooks.reset();
        const first = UserProfileRepositoryImpl.getInstance();
        hooks.reset();
        const second = UserProfileRepositoryImpl.getInstance();
        expect(first === second).assertEqual(false);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: get_instance_should_return_polluted_static_instance', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileSingletonHooksAR();
      try {
        const polluted = new UserProfileRepositoryImpl();
        hooks.setInstance(polluted as Object);
        const result = UserProfileRepositoryImpl.getInstance();
        expect(result === polluted).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('normal: build_default_username_should_match_expected_pattern', 0, () => {
      // Arrange
      // Act
      // Assert
      const username = UserProfileRepositoryImpl.buildDefaultUsername();
      expect(/^\u65C5\u884C\u8005\d{4}$/.test(username)).assertTrue();
    });

    it('boundary: build_default_username_should_start_from_1000_when_random_is_zero', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new MathRandomHooksAR();
      hooks.setRandom((): number => 0);
      try {
        const username = UserProfileRepositoryImpl.buildDefaultUsername();
        expect(username).assertEqual('\u65C5\u884C\u80051000');
      } finally {
        hooks.restore();
      }
    });

    it('invalid: build_default_username_should_surface_nan_suffix_when_random_is_nan', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new MathRandomHooksAR();
      hooks.setRandom((): number => Number.NaN);
      try {
        const username = UserProfileRepositoryImpl.buildDefaultUsername();
        expect(username.includes('NaN')).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('normal: bind_context_should_store_context_reference', 0, () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const context = createContextAR('profile_ctx');
      repo.bindContext(context as never);
      expect(Reflect.get(repo as Object, 'context') === context).assertTrue();
    });

    it('boundary: bind_context_should_overwrite_previous_context', 0, () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const first = createContextAR('first');
      const second = createContextAR('second');
      repo.bindContext(first as never);
      repo.bindContext(second as never);
      expect(Reflect.get(repo as Object, 'context') === second).assertTrue();
    });

    it('invalid: bind_context_should_allow_runtime_null_reset', 0, () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      repo.bindContext(null as never);
      expect(Reflect.get(repo as Object, 'context') === null).assertTrue();
    });

    it('normal: get_by_account_id_should_query_cloud_zone_and_map_entity', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      zone.queueQueryRows([createCloudRowAR('acc_1', 'Alice')]);
      const queryHooks = new CloudQueryHooksAR();
      queryHooks.install();
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      try {
        const entity = await repo.getByAccountId(' acc_1 ');
        const query = zone.queryCalls[0] as FakeCloudQueryBuilderAR;
        expect(entity !== null).assertTrue();
        expect(entity?.accountId).assertEqual('acc_1');
        expect(entity?.username).assertEqual('Alice');
        expect(entity?.updatedAt).assertEqual(444);
        expect(query.equalField).assertEqual('accountId');
        expect(String(query.equalValue)).assertEqual('acc_1');
        expect(query.limitValue).assertEqual(1);
      } finally {
        queryHooks.restore();
      }
    });

    it('boundary: get_by_account_id_should_return_null_for_blank_account_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const entity = await repo.getByAccountId('   ');
      expect(entity === null).assertTrue();
    });

    it('boundary: get_by_account_id_should_return_null_when_snapshot_empty', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      zone.queueQueryRows([]);
      const queryHooks = new CloudQueryHooksAR();
      queryHooks.install();
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      try {
        const entity = await repo.getByAccountId('acc_empty');
        expect(entity === null).assertTrue();
      } finally {
        queryHooks.restore();
      }
    });

    it('invalid: get_by_account_id_should_throw_normalized_query_error', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      zone.queueQueryError('profile_query_failed_ar');
      const queryHooks = new CloudQueryHooksAR();
      queryHooks.install();
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      let message = '';
      try {
        await repo.getByAccountId('acc_fail');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        queryHooks.restore();
      }
      expect(message).assertEqual('profile_query_failed_ar');
    });

    it('normal: create_default_profile_should_upsert_and_return_latest_profile', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      zone.queueQueryRows([]);
      zone.queueQueryRows([createCloudRowAR('acc_create', '\u65C5\u884C\u80051000')]);
      const queryHooks = new CloudQueryHooksAR();
      const randomHooks = new MathRandomHooksAR();
      randomHooks.setRandom((): number => 0);
      queryHooks.install();
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      try {
        const profile = await repo.createDefaultProfile(' acc_create ');
        expect(zone.upsertCalls.length).assertEqual(1);
        expect(profile.accountId).assertEqual('acc_create');
        expect(profile.avatarPath).assertEqual('app.media.headphoto');
        expect(profile.isInitialized).assertTrue();
      } finally {
        queryHooks.restore();
        randomHooks.restore();
      }
    });

    it('boundary: create_default_profile_should_return_existing_profile_without_upsert', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      zone.queueQueryRows([createCloudRowAR('acc_exist', 'Exist')]);
      const queryHooks = new CloudQueryHooksAR();
      queryHooks.install();
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      try {
        const profile = await repo.createDefaultProfile('acc_exist');
        expect(profile.username).assertEqual('Exist');
        expect(zone.upsertCalls.length).assertEqual(0);
      } finally {
        queryHooks.restore();
      }
    });

    it('invalid: create_default_profile_should_throw_when_account_id_blank', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      let message = '';
      try {
        await repo.createDefaultProfile('   ');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('account_id_required');
    });

    it('invalid: create_default_profile_should_surface_upsert_error', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      zone.queueQueryRows([]);
      zone.queueUpsertError('profile_upsert_failed_ar');
      const queryHooks = new CloudQueryHooksAR();
      queryHooks.install();
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      let message = '';
      try {
        await repo.createDefaultProfile('acc_upsert_fail');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        queryHooks.restore();
      }
      expect(message).assertEqual('profile_upsert_failed_ar');
    });

    it('normal: update_username_should_upsert_trimmed_username', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      const dateHooks = new DateNowHooksAR();
      dateHooks.setNow(6000);
      Reflect.set(repo as Object, 'createDefaultProfile', async (_accountId: string): Promise<UserProfileEntity> => createProfileAR('acc_name', 'Base'));
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      try {
        const profile = await repo.updateUsername('acc_name', 'Neo');
        expect(zone.upsertCalls.length).assertEqual(1);
        expect(profile.username).assertEqual('Neo');
        expect(profile.updatedAt).assertEqual(6000);
      } finally {
        dateHooks.restore();
      }
    });

    it('boundary: update_username_should_trim_input_whitespace', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      Reflect.set(repo as Object, 'createDefaultProfile', async (_accountId: string): Promise<UserProfileEntity> => createProfileAR('acc_trim', 'Base'));
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      const profile = await repo.updateUsername('acc_trim', '  Trimmed  ');
      expect(profile.username).assertEqual('Trimmed');
    });

    it('invalid: update_username_should_throw_when_username_blank', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      let message = '';
      try {
        await repo.updateUsername('acc_invalid', '   ');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('username_required');
    });

    it('normal: update_avatar_should_upsert_given_path_and_version', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      const dateHooks = new DateNowHooksAR();
      dateHooks.setNow(7000);
      Reflect.set(repo as Object, 'createDefaultProfile', async (_accountId: string): Promise<UserProfileEntity> => createProfileAR('acc_avatar', 'Avatar'));
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      try {
        const profile = await repo.updateAvatar('acc_avatar', ' /tmp/a.png ', 4.9);
        expect(zone.upsertCalls.length).assertEqual(1);
        expect(profile.avatarPath).assertEqual('/tmp/a.png');
        expect(profile.avatarVersion).assertEqual(4);
        expect(profile.updatedAt).assertEqual(7000);
      } finally {
        dateHooks.restore();
      }
    });

    it('boundary: update_avatar_should_increment_version_when_input_invalid', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      const zone = new FakeCloudZoneAR();
      const base = createProfileAR('acc_avatar_boundary', 'Avatar');
      base.avatarVersion = 2;
      Reflect.set(repo as Object, 'createDefaultProfile', async (_accountId: string): Promise<UserProfileEntity> => base);
      Reflect.set(repo as Object, 'ensureCloudDbZone', async (): Promise<Object> => zone as Object);
      const profile = await repo.updateAvatar('acc_avatar_boundary', 'avatar.png', 0);
      expect(profile.avatarVersion).assertEqual(3);
    });

    it('invalid: update_avatar_should_throw_when_account_id_blank', 0, async () => {
      // Arrange
      // Act
      // Assert
      const repo = new UserProfileRepositoryImpl();
      let message = '';
      try {
        await repo.updateAvatar('   ', 'avatar.png', 1);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      expect(message).assertEqual('account_id_required');
    });
  });

  describe('phase2BatchAR_profile_cache_manager', () => {
    it('normal: get_instance_should_return_singleton_for_profile_cache', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ProfileCacheSingletonHooksAR();
      try {
        const first = ProfileCacheManager.getInstance();
        const second = ProfileCacheManager.getInstance();
        expect(first === second).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('boundary: get_instance_should_create_new_profile_cache_after_reset', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ProfileCacheSingletonHooksAR();
      try {
        hooks.reset();
        const first = ProfileCacheManager.getInstance();
        hooks.reset();
        const second = ProfileCacheManager.getInstance();
        expect(first === second).assertEqual(false);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: get_instance_should_return_polluted_profile_cache_singleton', 0, () => {
      // Arrange
      // Act
      // Assert
      const hooks = new ProfileCacheSingletonHooksAR();
      try {
        const polluted = new ProfileCacheManager();
        hooks.setInstance(polluted as Object);
        const result = ProfileCacheManager.getInstance();
        expect(result === polluted).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('normal: bind_context_should_store_profile_cache_context', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const context = createContextAR('cache_ctx');
      cache.bindContext(context as never);
      expect(Reflect.get(cache as Object, 'context') === context).assertTrue();
    });

    it('boundary: bind_context_should_overwrite_previous_profile_cache_context', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const first = createContextAR('cache_first');
      const second = createContextAR('cache_second');
      cache.bindContext(first as never);
      cache.bindContext(second as never);
      expect(Reflect.get(cache as Object, 'context') === second).assertTrue();
    });

    it('invalid: bind_context_should_allow_runtime_null_for_profile_cache', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      cache.bindContext(null as never);
      expect(Reflect.get(cache as Object, 'context') === null).assertTrue();
    });

    it('normal: read_profile_should_return_cloned_memory_profile', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const stored = createProfileAR('acc_mem', 'Memory');
      getMemoryCacheAR(cache as Object).set('acc_mem', stored);
      const result = await cache.readProfile('acc_mem');
      expect(result !== null).assertTrue();
      if (result) {
        result.username = 'Mutated';
      }
      expect(stored.username).assertEqual('Memory');
    });

    it('boundary: read_profile_should_load_from_preference_once_then_use_memory', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      pref.setRaw('acc_pref', JSON.stringify(createProfileAR('acc_pref', 'Persisted')));
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      Reflect.set(cache as Object, 'context', createContextAR('pref_ctx'));
      try {
        const first = await cache.readProfile('acc_pref');
        const second = await cache.readProfile('acc_pref');
        expect(first?.username).assertEqual('Persisted');
        expect(second?.username).assertEqual('Persisted');
        expect(pref.getProfileCalls).assertEqual(1);
        expect(pref.initCount).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: read_profile_should_return_null_for_invalid_cached_json', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      pref.setRaw('acc_bad', '{bad');
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      Reflect.set(cache as Object, 'context', createContextAR('bad_ctx'));
      try {
        const result = await cache.readProfile('acc_bad');
        expect(result === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('conflict: read_profile_should_prefer_memory_copy_over_preference_cache', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      pref.setRaw('acc_conflict', JSON.stringify(createProfileAR('acc_conflict', 'Persisted')));
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      Reflect.set(cache as Object, 'context', createContextAR('conflict_ctx'));
      getMemoryCacheAR(cache as Object).set('acc_conflict', createProfileAR('acc_conflict', 'Memory'));
      try {
        const result = await cache.readProfile('acc_conflict');
        expect(result?.username).assertEqual('Memory');
        expect(pref.getProfileCalls).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('normal: write_profile_should_update_memory_and_preference_store', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      Reflect.set(cache as Object, 'context', createContextAR('write_ctx'));
      try {
        await cache.writeProfile(createProfileAR('acc_write', 'Writer'));
        expect(getMemoryCacheAR(cache as Object).has('acc_write')).assertTrue();
        expect(pref.setProfileCalls).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('boundary: write_profile_should_only_update_memory_when_context_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      try {
        await cache.writeProfile(createProfileAR('acc_mem_only', 'MemOnly'));
        expect(getMemoryCacheAR(cache as Object).has('acc_mem_only')).assertTrue();
        expect(pref.setProfileCalls).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: write_profile_should_ignore_blank_account_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      try {
        await cache.writeProfile(createProfileAR('   ', 'Blank'));
        expect(getMemoryCacheAR(cache as Object).size).assertEqual(0);
        expect(pref.setProfileCalls).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('normal: clear_profile_should_remove_memory_and_preference_copy', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      Reflect.set(cache as Object, 'context', createContextAR('clear_ctx'));
      getMemoryCacheAR(cache as Object).set('acc_clear', createProfileAR('acc_clear', 'Clear'));
      try {
        await cache.clearProfile('acc_clear');
        expect(getMemoryCacheAR(cache as Object).has('acc_clear')).assertEqual(false);
        expect(pref.clearProfileCalls).assertEqual(1);
      } finally {
        hooks.restore();
      }
    });

    it('boundary: clear_profile_should_only_remove_memory_when_context_missing', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      getMemoryCacheAR(cache as Object).set('acc_clear_mem', createProfileAR('acc_clear_mem', 'Clear'));
      try {
        await cache.clearProfile('acc_clear_mem');
        expect(getMemoryCacheAR(cache as Object).has('acc_clear_mem')).assertEqual(false);
        expect(pref.clearProfileCalls).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('invalid: clear_profile_should_ignore_blank_account_id', 0, async () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      const pref = new FakePreferenceManagerAR();
      const hooks = new PreferenceHooksAR();
      hooks.setInstance(pref as Object);
      getMemoryCacheAR(cache as Object).set('acc_keep', createProfileAR('acc_keep', 'Keep'));
      try {
        await cache.clearProfile('   ');
        expect(getMemoryCacheAR(cache as Object).has('acc_keep')).assertTrue();
        expect(pref.clearProfileCalls).assertEqual(0);
      } finally {
        hooks.restore();
      }
    });

    it('normal: clear_all_memory_should_remove_all_cached_profiles', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      getMemoryCacheAR(cache as Object).set('a', createProfileAR('a', 'A'));
      getMemoryCacheAR(cache as Object).set('b', createProfileAR('b', 'B'));
      cache.clearAllMemory();
      expect(getMemoryCacheAR(cache as Object).size).assertEqual(0);
    });

    it('boundary: clear_all_memory_should_be_idempotent', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      getMemoryCacheAR(cache as Object).set('a', createProfileAR('a', 'A'));
      cache.clearAllMemory();
      cache.clearAllMemory();
      expect(getMemoryCacheAR(cache as Object).size).assertEqual(0);
    });

    it('invalid: clear_all_memory_should_tolerate_empty_cache', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new ProfileCacheManager();
      cache.clearAllMemory();
      expect(getMemoryCacheAR(cache as Object).size).assertEqual(0);
    });
  });

  describe('phase2BatchAR_weather_cache', () => {
    it('normal: build_location_key_should_format_coordinates_and_hour_bucket', 0, () => {
      // Arrange
      // Act
      // Assert
      const key = WeatherCache.buildLocationKey(31.23, 121.47, 2 * 60 * 60 * 1000);
      expect(key).assertEqual('31.230:121.470:2');
    });

    it('boundary: build_location_key_should_round_to_three_decimals', 0, () => {
      // Arrange
      // Act
      // Assert
      const key = WeatherCache.buildLocationKey(31.2304, 121.4706, 3 * 60 * 60 * 1000);
      expect(key).assertEqual('31.230:121.471:3');
    });

    it('invalid: build_location_key_should_fallback_to_zero_for_nan_coordinates', 0, () => {
      // Arrange
      // Act
      // Assert
      const key = WeatherCache.buildLocationKey(Number.NaN, Number.NaN, 4 * 60 * 60 * 1000);
      expect(key).assertEqual('0.000:0.000:4');
    });

    it('normal: build_cache_key_should_prefix_source_type', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const key = cache.buildCacheKey('PLAN_LOCATION', '31.230:121.470:9');
      expect(key).assertEqual('weather:PLAN_LOCATION:31.230:121.470:9');
    });

    it('boundary: build_cache_key_should_allow_empty_location_key', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const key = cache.buildCacheKey('CURRENT_LOCATION', '');
      expect(key).assertEqual('weather:CURRENT_LOCATION:');
    });

    it('invalid: build_cache_key_should_allow_runtime_unknown_source_string', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const key = cache.buildCacheKey('UNKNOWN' as never, 'x');
      expect(key).assertEqual('weather:UNKNOWN:x');
    });

    it('normal: get_should_return_hit_before_ttl', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      const key = 'k1';
      try {
        hooks.setNow(1000);
        cache.set(key, createWeatherSnapshotAR('k1'));
        hooks.setNow(1500);
        const hit = cache.get(key, 1000);
        expect(hit !== null).assertTrue();
        expect(hit?.locationKey).assertEqual('k1');
      } finally {
        hooks.restore();
      }
    });

    it('boundary: get_should_keep_entry_when_age_equals_ttl', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      const key = 'k2';
      try {
        hooks.setNow(2000);
        cache.set(key, createWeatherSnapshotAR('k2'));
        hooks.setNow(3000);
        const hit = cache.get(key, 1000);
        expect(hit !== null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('invalid: get_should_return_null_and_delete_expired_entry', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      const key = 'k3';
      try {
        hooks.setNow(1000);
        cache.set(key, createWeatherSnapshotAR('k3'));
        hooks.setNow(4001);
        const miss = cache.get(key, 1000);
        const secondMiss = cache.get(key, 1000);
        expect(miss === null).assertTrue();
        expect(secondMiss === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('normal: set_should_store_snapshot_for_later_reads', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(1000);
        cache.set('set_key', createWeatherSnapshotAR('set_key'));
        const hit = cache.get('set_key', 5000);
        expect(hit?.locationKey).assertEqual('set_key');
      } finally {
        hooks.restore();
      }
    });

    it('boundary: set_should_overwrite_existing_snapshot_for_same_key', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(1000);
        cache.set('same_key', createWeatherSnapshotAR('old'));
        hooks.setNow(1500);
        cache.set('same_key', createWeatherSnapshotAR('new'));
        const hit = cache.get('same_key', 5000);
        expect(hit?.locationKey).assertEqual('new');
      } finally {
        hooks.restore();
      }
    });

    it('invalid: set_should_accept_empty_cache_key_at_runtime', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(1000);
        cache.set('', createWeatherSnapshotAR('empty_key'));
        const hit = cache.get('', 1000);
        expect(hit?.locationKey).assertEqual('empty_key');
      } finally {
        hooks.restore();
      }
    });

    it('normal: cleanup_should_remove_only_expired_entries', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(1000);
        cache.set('old_key', createWeatherSnapshotAR('old_key'));
        hooks.setNow(4000);
        cache.set('new_key', createWeatherSnapshotAR('new_key'));
        hooks.setNow(5000);
        cache.cleanup(1500);
        expect(cache.get('old_key', 5000) === null).assertTrue();
        expect(cache.get('new_key', 5000)?.locationKey).assertEqual('new_key');
      } finally {
        hooks.restore();
      }
    });

    it('boundary: cleanup_should_keep_entries_when_age_equals_ttl', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(1000);
        cache.set('edge_key', createWeatherSnapshotAR('edge_key'));
        hooks.setNow(2000);
        cache.cleanup(1000);
        const hit = cache.get('edge_key', 1000);
        expect(hit !== null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('regression: td-20260416-weather_cache_equal_ttl_should_remain_hit', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(5000);
        cache.set('reg_key', createWeatherSnapshotAR('reg_key'));
        hooks.setNow(6000);
        const hit = cache.get('reg_key', 1000);
        expect(hit?.locationKey).assertEqual('reg_key');
      } finally {
        hooks.restore();
      }
    });

    it('invalid: cleanup_should_remove_all_entries_when_ttl_negative', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(1000);
        cache.set('a', createWeatherSnapshotAR('a'));
        cache.set('b', createWeatherSnapshotAR('b'));
        hooks.setNow(1001);
        cache.cleanup(-1);
        expect(cache.get('a', 1000) === null).assertTrue();
        expect(cache.get('b', 1000) === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('combined: weather_cache_set_get_cleanup_should_roundtrip_then_expire', 0, () => {
      // Arrange
      // Act
      // Assert
      const cache = new WeatherCache();
      const hooks = new DateNowHooksAR();
      try {
        hooks.setNow(100);
        cache.set('combo', createWeatherSnapshotAR('combo'));
        hooks.setNow(200);
        const hit = cache.get('combo', 1000);
        hooks.setNow(2000);
        cache.cleanup(500);
        const miss = cache.get('combo', 500);
        expect(hit?.locationKey).assertEqual('combo');
        expect(miss === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });
  });
}
