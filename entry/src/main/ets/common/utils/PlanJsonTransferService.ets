import { hilog } from '@kit.PerformanceAnalysisKit';
import { PlanDao } from '../../model/entity/PlanDao';
import { EventDao } from '../../model/entity/EventDao';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';
import { RdbHelper } from './RdbHelper';

const TAG = 'PlanJsonTransferService';
const MAX_IMPORT_JSON_LENGTH = 1024 * 1024;
const MAX_IMPORT_EVENT_COUNT = 2000;
const MAX_PLAN_TITLE_LENGTH = 80;
const MAX_EVENT_NAME_LENGTH = 60;
const MAX_NOTE_LENGTH = 2000;
const MAX_REASONING_LENGTH = 4000;
const MAX_TIME_TS = 4102444800000; // 2100-01-01T00:00:00.000Z

interface ExportPlanMeta {
  title: string;
  startDate: number;
  status: number;
  enableAutoAmapRoute: number;
}

interface PlanJsonPayload {
  schemaVersion: number;
  exportedAt: number;
  sourcePlanId: number;
  plan: ExportPlanMeta;
  events: TravelPlanItem[];
}

interface TransactionStoreLike {
  beginTransaction(): void;
  commit(): void;
  rollBack(): void;
}

interface PlanJsonTransferDeps {
  getStore: () => TransactionStoreLike | null;
  createPlan: (title: string, startDate: number) => Promise<number>;
  updateAutoAmapRoute: (id: number, enabled: boolean) => Promise<void>;
  updatePlanStatus: (id: number, status: number) => Promise<void>;
  insertEvent: (planId: number, item: TravelPlanItem) => Promise<number>;
  hardDeletePlan: (id: number) => Promise<void>;
}

export class PlanJsonImportCancelToken {
  private canceled: boolean = false;

  public cancel(): void {
    this.canceled = true;
  }

  public throwIfCancelled(stage: string): void {
    if (this.canceled) {
      throw new Error(`import_cancelled:${stage}`);
    }
  }
}

export class PlanJsonTransferService {
  private static testDeps: PlanJsonTransferDeps | null = null;

  public static setDepsForTest(deps: PlanJsonTransferDeps | null): void {
    PlanJsonTransferService.testDeps = deps;
  }

  private static resolveDeps(): PlanJsonTransferDeps {
    if (PlanJsonTransferService.testDeps) {
      return PlanJsonTransferService.testDeps;
    }
    return {
      getStore: (): TransactionStoreLike | null => RdbHelper.getInstance().getRdbStore(),
      createPlan: async (title: string, startDate: number): Promise<number> => PlanDao.createPlan(title, startDate),
      updateAutoAmapRoute: async (id: number, enabled: boolean): Promise<void> => PlanDao.updateAutoAmapRoute(id, enabled),
      updatePlanStatus: async (id: number, status: number): Promise<void> => PlanDao.updatePlanStatus(id, status),
      insertEvent: async (planId: number, item: TravelPlanItem): Promise<number> => EventDao.insertEvent(planId, item),
      hardDeletePlan: async (id: number): Promise<void> => PlanDao.hardDeletePlan(id)
    };
  }

  public static async exportPlanToJson(planId: number): Promise<string> {
    const plan = await PlanDao.getPlanById(planId);
    if (!plan) {
      throw new Error(`plan_not_found:${planId}`);
    }
    const events = await EventDao.getAllEvents(planId);
    const payload: PlanJsonPayload = {
      schemaVersion: 1,
      exportedAt: Date.now(),
      sourcePlanId: planId,
      plan: {
        title: plan.title,
        startDate: plan.startDate || Date.now(),
        status: plan.status ?? 0,
        enableAutoAmapRoute: plan.enableAutoAmapRoute ?? 1
      },
      events: events.map((item: TravelPlanItem, index: number) =>
        PlanJsonTransferService.normalizeExportEvent(item, index))
    };
    return JSON.stringify(payload, null, 2);
  }

  public static async importPlanFromJson(raw: string, cancelToken?: PlanJsonImportCancelToken): Promise<number> {
    cancelToken?.throwIfCancelled('before_parse');
    const parsed = PlanJsonTransferService.parseAndValidateImportPayload(raw);
    cancelToken?.throwIfCancelled('after_validate');
    const deps = PlanJsonTransferService.resolveDeps();

    const startDate = Number(parsed.plan.startDate) > 0 ? Number(parsed.plan.startDate) : Date.now();
    const importedPlanTitle = `${parsed.plan.title.trim()}(导入)`;
    const rdbStore = deps.getStore();
    if (!rdbStore) {
      throw new Error('db_not_ready');
    }

    const events = parsed.events as TravelPlanItem[];
    let newPlanId = -1;
    let transactionOpened = false;
    try {
      cancelToken?.throwIfCancelled('before_transaction');
      rdbStore.beginTransaction();
      transactionOpened = true;
      newPlanId = await deps.createPlan(importedPlanTitle, startDate);
      if (newPlanId <= 0) {
        throw new Error('create_plan_failed');
      }

      const autoRoute = parsed.plan.enableAutoAmapRoute === 0 ? 0 : 1;
      await deps.updateAutoAmapRoute(newPlanId, autoRoute === 1);
      const planStatus = PlanJsonTransferService.readInt(parsed.plan.status, 0, false);
      await deps.updatePlanStatus(newPlanId, planStatus);

      for (let i = 0; i < events.length; i++) {
        cancelToken?.throwIfCancelled(`insert_event_${i}`);
        const normalized = PlanJsonTransferService.normalizeImportEvent(events[i], i);
        await deps.insertEvent(newPlanId, normalized);
      }

      cancelToken?.throwIfCancelled('before_commit');
      rdbStore.commit();
      transactionOpened = false;
      hilog.info(0x0000, TAG, `[PLAN_JSON][import_done] newPlanId=${newPlanId}, count=${events.length}, status=${planStatus}`);
      return newPlanId;
    } catch (error) {
      if (transactionOpened) {
        try {
          rdbStore.rollBack();
        } catch (rollbackError) {
          hilog.error(0x0000, TAG, `[PLAN_JSON][import_rollback_failed] reason=${JSON.stringify(rollbackError)}`);
        } finally {
          transactionOpened = false;
        }
      }
      if (newPlanId > 0) {
        try {
          await deps.hardDeletePlan(newPlanId);
        } catch (compensateError) {
          hilog.error(0x0000, TAG, `[PLAN_JSON][import_compensate_delete_failed] planId=${newPlanId}, reason=${JSON.stringify(compensateError)}`);
        }
      }
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(`import_failed:${JSON.stringify(error)}`);
    }
  }

  private static normalizeExportEvent(item: TravelPlanItem, index: number): TravelPlanItem {
    const duration = PlanJsonTransferService.readInt(item.duration, 30, false);
    const normalizedMode = PlanJsonTransferService.readInt(item.travelMode ?? item.transportMode, 2, false);
    return {
      name: item.name || `未命名地点${index + 1}`,
      note: item.note || '',
      duration: duration > 0 ? duration : 30,
      type: item.type || 'FLOW',
      preTravelMinutes: PlanJsonTransferService.readInt(item.preTravelMinutes, 0, true),
      sortOrder: PlanJsonTransferService.readInt(item.sortOrder, index * 100, true),
      status: PlanJsonTransferService.readInt(item.status, 0, false),
      lockStatus: PlanJsonTransferService.readInt(item.lockStatus, 0, false),
      fixedStartTime: item.fixedStartTime,
      dayOffset: PlanJsonTransferService.readInt(item.dayOffset, 0, true),
      itemType: PlanJsonTransferService.readInt(item.itemType, 0, false),
      priority: PlanJsonTransferService.readInt(item.priority, 0, true),
      transportMode: normalizedMode,
      travelMode: normalizedMode,
      isTravelManual: PlanJsonTransferService.readInt(item.isTravelManual, 0, false),
      source: PlanJsonTransferService.readInt(item.source, 0, false),
      delFlag: 0,
      groupId: PlanJsonTransferService.readInt(item.groupId, 0, true),
      address: item.address || '',
      aiReasoning: item.aiReasoning || '',
      latitude: PlanJsonTransferService.readNumber(item.latitude, 0),
      longitude: PlanJsonTransferService.readNumber(item.longitude, 0),
      actualStartTime: PlanJsonTransferService.readInt(item.actualStartTime, 0, false),
      actualEndTime: PlanJsonTransferService.readInt(item.actualEndTime, 0, false),
      completionStatus: PlanJsonTransferService.readInt(item.completionStatus, 0, false)
    };
  }

  private static normalizeImportEvent(item: TravelPlanItem, index: number): TravelPlanItem {
    const duration = PlanJsonTransferService.readInt(item.duration, 30, false);
    const normalizedMode = PlanJsonTransferService.readInt(item.travelMode ?? item.transportMode, 2, false);
    return {
      name: item.name || `未命名地点${index + 1}`,
      note: item.note || '',
      duration: duration > 0 ? duration : 30,
      type: item.type || 'FLOW',
      preTravelMinutes: PlanJsonTransferService.readInt(item.preTravelMinutes, 0, true),
      sortOrder: PlanJsonTransferService.readInt(item.sortOrder, index * 100, true),
      status: PlanJsonTransferService.readInt(item.status, 0, false),
      lockStatus: PlanJsonTransferService.readInt(item.lockStatus, 0, false),
      fixedStartTime: item.fixedStartTime,
      dayOffset: PlanJsonTransferService.readInt(item.dayOffset, 0, true),
      itemType: PlanJsonTransferService.readInt(item.itemType, 0, false),
      priority: PlanJsonTransferService.readInt(item.priority, 0, true),
      transportMode: normalizedMode,
      travelMode: normalizedMode,
      isTravelManual: PlanJsonTransferService.readInt(item.isTravelManual, 0, false),
      source: PlanJsonTransferService.readInt(item.source, 0, false),
      delFlag: 0,
      groupId: PlanJsonTransferService.readInt(item.groupId, 0, true),
      address: item.address || '',
      aiReasoning: item.aiReasoning || '',
      latitude: PlanJsonTransferService.readNumber(item.latitude, 0),
      longitude: PlanJsonTransferService.readNumber(item.longitude, 0),
      actualStartTime: PlanJsonTransferService.readInt(item.actualStartTime, 0, false),
      actualEndTime: PlanJsonTransferService.readInt(item.actualEndTime, 0, false),
      completionStatus: PlanJsonTransferService.readInt(item.completionStatus, 0, false)
    };
  }

  private static readInt(value: number | undefined, fallback: number, allowNegative: boolean): number {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      return fallback;
    }
    const safe = Math.floor(n);
    if (!allowNegative && safe < 0) {
      return fallback;
    }
    return safe;
  }

  private static readNumber(value: number | undefined, fallback: number): number {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
  }

  private static parseAndValidateImportPayload(raw: string): PlanJsonPayload {
    if (!raw || raw.trim() === '') {
      throw new Error('invalid_payload:empty_json');
    }
    if (raw.length > MAX_IMPORT_JSON_LENGTH) {
      throw new Error(`invalid_payload:json_too_large:${raw.length}`);
    }

    let parsed = null as Partial<PlanJsonPayload> | null;
    try {
      parsed = JSON.parse(raw) as Partial<PlanJsonPayload>;
    } catch (_error) {
      throw new Error('invalid_payload:json_parse_failed');
    }
    if (!parsed || !parsed.plan || !Array.isArray(parsed.events)) {
      throw new Error('invalid_payload:missing_plan_or_events');
    }

    const schemaVersion = Number(parsed.schemaVersion);
    if (!Number.isFinite(schemaVersion) || schemaVersion !== 1) {
      throw new Error(`invalid_payload:schema_version:${parsed.schemaVersion}`);
    }
    if (parsed.events.length > MAX_IMPORT_EVENT_COUNT) {
      throw new Error(`invalid_payload:too_many_events:${parsed.events.length}`);
    }

    const title = (parsed.plan.title || '').trim();
    if (!title) {
      throw new Error('invalid_payload:empty_title');
    }
    if (title.length > MAX_PLAN_TITLE_LENGTH) {
      throw new Error(`invalid_payload:title_too_long:${title.length}`);
    }
    PlanJsonTransferService.ensureIntInRange(parsed.plan.startDate, 946656000000, MAX_TIME_TS, 'plan.startDate');
    PlanJsonTransferService.ensureIntInRange(parsed.plan.status, 0, 2, 'plan.status');
    PlanJsonTransferService.ensureEnumInt(parsed.plan.enableAutoAmapRoute, [0, 1], 'plan.enableAutoAmapRoute');

    const events = parsed.events as TravelPlanItem[];
    for (let i = 0; i < events.length; i++) {
      PlanJsonTransferService.validateEvent(events[i], i);
    }
    return parsed as PlanJsonPayload;
  }

  private static validateEvent(item: TravelPlanItem, index: number): void {
    const name = (item.name || '').trim();
    if (!name) {
      throw new Error(`invalid_event:name_empty:index=${index}`);
    }
    if (name.length > MAX_EVENT_NAME_LENGTH) {
      throw new Error(`invalid_event:name_too_long:index=${index},len=${name.length}`);
    }
    if ((item.note || '').length > MAX_NOTE_LENGTH) {
      throw new Error(`invalid_event:note_too_long:index=${index}`);
    }
    if ((item.aiReasoning || '').length > MAX_REASONING_LENGTH) {
      throw new Error(`invalid_event:reasoning_too_long:index=${index}`);
    }
    if ((item.address || '').length > MAX_NOTE_LENGTH) {
      throw new Error(`invalid_event:address_too_long:index=${index}`);
    }
    if (item.type !== undefined && item.type !== 'ANCHOR' && item.type !== 'FLOW') {
      throw new Error(`invalid_event:type:index=${index},value=${item.type}`);
    }

    PlanJsonTransferService.ensureIntInRange(item.duration, 1, 24 * 60, `events[${index}].duration`);
    PlanJsonTransferService.ensureIntInRange(item.preTravelMinutes, -1, 24 * 60, `events[${index}].preTravelMinutes`);
    PlanJsonTransferService.ensureIntInRange(item.sortOrder, -1000000, 1000000, `events[${index}].sortOrder`);
    PlanJsonTransferService.ensureIntInRange(item.dayOffset, -3650, 3650, `events[${index}].dayOffset`);
    PlanJsonTransferService.ensureIntInRange(item.groupId, 0, 1000000000, `events[${index}].groupId`);
    PlanJsonTransferService.ensureIntInRange(item.actualStartTime, 0, MAX_TIME_TS, `events[${index}].actualStartTime`);
    PlanJsonTransferService.ensureIntInRange(item.actualEndTime, 0, MAX_TIME_TS, `events[${index}].actualEndTime`);
    if (Number(item.actualEndTime || 0) > 0 && Number(item.actualStartTime || 0) > Number(item.actualEndTime || 0)) {
      throw new Error(`invalid_event:actual_time_range:index=${index}`);
    }
    if (item.fixedStartTime && !/^\d{2}:\d{2}$/.test(item.fixedStartTime)) {
      throw new Error(`invalid_event:fixed_start_time:index=${index}`);
    }

    PlanJsonTransferService.ensureEnumInt(item.status, [0, 1], `events[${index}].status`);
    PlanJsonTransferService.ensureEnumInt(item.lockStatus, [0, 1], `events[${index}].lockStatus`);
    PlanJsonTransferService.ensureEnumInt(item.itemType, [0, 1, 2, 3], `events[${index}].itemType`);
    PlanJsonTransferService.ensureEnumInt(item.priority, [0, 1], `events[${index}].priority`);
    PlanJsonTransferService.ensureEnumInt(item.travelMode ?? item.transportMode, [0, 1, 2, 3], `events[${index}].travelMode`);
    if (item.transportMode !== undefined) {
      PlanJsonTransferService.ensureEnumInt(item.transportMode, [0, 1, 2, 3], `events[${index}].transportMode`);
    }
    PlanJsonTransferService.ensureEnumInt(item.isTravelManual, [0, 1], `events[${index}].isTravelManual`);
    PlanJsonTransferService.ensureEnumInt(item.source, [0, 1], `events[${index}].source`);
    PlanJsonTransferService.ensureEnumInt(item.completionStatus, [0, 1, 2], `events[${index}].completionStatus`);

    const latRaw = Number(item.latitude);
    const lngRaw = Number(item.longitude);
    const latProvided = item.latitude !== undefined;
    const lngProvided = item.longitude !== undefined;
    if (!latProvided && !lngProvided) {
      return;
    }
    if (!Number.isFinite(latRaw) || !Number.isFinite(lngRaw)) {
      throw new Error(`invalid_event:coordinate_nan:index=${index}`);
    }
    if (Math.abs(latRaw) > 90 || Math.abs(lngRaw) > 180) {
      throw new Error(`invalid_event:coordinate_out_of_range:index=${index},lat=${latRaw},lng=${lngRaw}`);
    }
  }

  private static ensureIntInRange(value: number | undefined, min: number, max: number, field: string): void {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      throw new Error(`invalid_field:${field}:not_number`);
    }
    const i = Math.floor(n);
    if (i < min || i > max) {
      throw new Error(`invalid_field:${field}:out_of_range:${i}`);
    }
  }

  private static ensureEnumInt(value: number | undefined, allowed: number[], field: string): void {
    const n = Number(value);
    if (!Number.isFinite(n)) {
      throw new Error(`invalid_field:${field}:not_number`);
    }
    const i = Math.floor(n);
    for (let idx = 0; idx < allowed.length; idx++) {
      if (allowed[idx] === i) {
        return;
      }
    }
    throw new Error(`invalid_field:${field}:invalid_enum:${i}`);
  }
}
