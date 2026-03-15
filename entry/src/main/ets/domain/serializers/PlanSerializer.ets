import { TravelPlanItem } from '../../model/interface/IStandardEvent';

const MAX_IMPORT_JSON_LENGTH = 1024 * 1024;
const MAX_IMPORT_EVENT_COUNT = 2000;
const MAX_PLAN_TITLE_LENGTH = 80;
const MAX_EVENT_NAME_LENGTH = 60;
const MAX_NOTE_LENGTH = 2000;
const MAX_REASONING_LENGTH = 4000;
const MAX_TIME_TS = 4102444800000; // 2100-01-01T00:00:00.000Z

export interface ExportPlanMeta {
  title: string;
  startDate: number;
  status: number;
  enableAutoAmapRoute: number;
}

export interface PlanJsonPayload {
  schemaVersion: number;
  exportedAt: number;
  sourcePlanId: number;
  plan: ExportPlanMeta;
  events: TravelPlanItem[];
}

export class PlanSerializer {
  public static serializePlan(plan: ExportPlanMeta, events: TravelPlanItem[]): string {
    const payload: PlanJsonPayload = {
      schemaVersion: 1,
      exportedAt: Date.now(),
      sourcePlanId: 0,
      plan: plan,
      events: events.map((item: TravelPlanItem, index: number) =>
        PlanSerializer.normalizeExportEvent(item, index))
    };
    return JSON.stringify(payload, null, 2);
  }

  public static deserializePlan(raw: string): PlanJsonPayload {
    return PlanSerializer.parseAndValidateImportPayload(raw);
  }

  private static normalizeExportEvent(item: TravelPlanItem, index: number): TravelPlanItem {
    const duration = PlanSerializer.readInt(item.duration, 30, false);
    const normalizedMode = PlanSerializer.readInt(item.travelMode ?? item.transportMode, 2, false);
    return {
      name: item.name || `未命名地点${index + 1}`,
      note: item.note || '',
      duration: duration > 0 ? duration : 30,
      type: item.type || 'FLOW',
      preTravelMinutes: PlanSerializer.readInt(item.preTravelMinutes, 0, true),
      sortOrder: PlanSerializer.readInt(item.sortOrder, index * 100, true),
      status: PlanSerializer.readInt(item.status, 0, false),
      lockStatus: PlanSerializer.readInt(item.lockStatus, 0, false),
      fixedStartTime: item.fixedStartTime,
      dayOffset: PlanSerializer.readInt(item.dayOffset, 0, true),
      itemType: PlanSerializer.readInt(item.itemType, 0, false),
      priority: PlanSerializer.readInt(item.priority, 0, true),
      transportMode: normalizedMode,
      travelMode: normalizedMode,
      isTravelManual: PlanSerializer.readInt(item.isTravelManual, 0, false),
      source: PlanSerializer.readInt(item.source, 0, false),
      delFlag: 0,
      groupId: PlanSerializer.readInt(item.groupId, 0, true),
      address: item.address || '',
      aiReasoning: item.aiReasoning || '',
      latitude: PlanSerializer.readNumber(item.latitude, 0),
      longitude: PlanSerializer.readNumber(item.longitude, 0),
      actualStartTime: PlanSerializer.readInt(item.actualStartTime, 0, false),
      actualEndTime: PlanSerializer.readInt(item.actualEndTime, 0, false),
      completionStatus: PlanSerializer.readInt(item.completionStatus, 0, false)
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

  public static normalizeImportEvent(item: TravelPlanItem, index: number): TravelPlanItem {
    const duration = PlanSerializer.readInt(item.duration, 30, false);
    const normalizedMode = PlanSerializer.readInt(item.travelMode ?? item.transportMode, 2, false);
    return {
      name: item.name || `未命名地点${index + 1}`,
      note: item.note || '',
      duration: duration > 0 ? duration : 30,
      type: item.type || 'FLOW',
      preTravelMinutes: PlanSerializer.readInt(item.preTravelMinutes, 0, true),
      sortOrder: PlanSerializer.readInt(item.sortOrder, index * 100, true),
      status: PlanSerializer.readInt(item.status, 0, false),
      lockStatus: PlanSerializer.readInt(item.lockStatus, 0, false),
      fixedStartTime: item.fixedStartTime,
      dayOffset: PlanSerializer.readInt(item.dayOffset, 0, true),
      itemType: PlanSerializer.readInt(item.itemType, 0, false),
      priority: PlanSerializer.readInt(item.priority, 0, true),
      transportMode: normalizedMode,
      travelMode: normalizedMode,
      isTravelManual: PlanSerializer.readInt(item.isTravelManual, 0, false),
      source: PlanSerializer.readInt(item.source, 0, false),
      delFlag: 0,
      groupId: PlanSerializer.readInt(item.groupId, 0, true),
      address: item.address || '',
      aiReasoning: item.aiReasoning || '',
      latitude: PlanSerializer.readNumber(item.latitude, 0),
      longitude: PlanSerializer.readNumber(item.longitude, 0),
      actualStartTime: PlanSerializer.readInt(item.actualStartTime, 0, false),
      actualEndTime: PlanSerializer.readInt(item.actualEndTime, 0, false),
      completionStatus: PlanSerializer.readInt(item.completionStatus, 0, false)
    };
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
    PlanSerializer.ensureIntInRange(parsed.plan.startDate, 946656000000, MAX_TIME_TS, 'plan.startDate');
    PlanSerializer.ensureIntInRange(parsed.plan.status, 0, 2, 'plan.status');
    PlanSerializer.ensureEnumInt(parsed.plan.enableAutoAmapRoute, [0, 1], 'plan.enableAutoAmapRoute');

    const events = parsed.events as TravelPlanItem[];
    for (let i = 0; i < events.length; i++) {
      PlanSerializer.validateEvent(events[i], i);
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

    PlanSerializer.ensureIntInRange(item.duration, 1, 24 * 60, `events[${index}].duration`);
    PlanSerializer.ensureIntInRange(item.preTravelMinutes, -1, 24 * 60, `events[${index}].preTravelMinutes`);
    PlanSerializer.ensureIntInRange(item.sortOrder, -1000000, 1000000, `events[${index}].sortOrder`);
    PlanSerializer.ensureIntInRange(item.dayOffset, -3650, 3650, `events[${index}].dayOffset`);
    PlanSerializer.ensureIntInRange(item.groupId, 0, 1000000000, `events[${index}].groupId`);
    PlanSerializer.ensureIntInRange(item.actualStartTime, 0, MAX_TIME_TS, `events[${index}].actualStartTime`);
    PlanSerializer.ensureIntInRange(item.actualEndTime, 0, MAX_TIME_TS, `events[${index}].actualEndTime`);
    if (Number(item.actualEndTime || 0) > 0 && Number(item.actualStartTime || 0) > Number(item.actualEndTime || 0)) {
      throw new Error(`invalid_event:actual_time_range:index=${index}`);
    }
    if (item.fixedStartTime && !/^\d{2}:\d{2}$/.test(item.fixedStartTime)) {
      throw new Error(`invalid_event:fixed_start_time:index=${index}`);
    }

    PlanSerializer.ensureEnumInt(item.status, [0, 1], `events[${index}].status`);
    PlanSerializer.ensureEnumInt(item.lockStatus, [0, 1], `events[${index}].lockStatus`);
    PlanSerializer.ensureEnumInt(item.itemType, [0, 1, 2, 3], `events[${index}].itemType`);
    PlanSerializer.ensureEnumInt(item.priority, [0, 1], `events[${index}].priority`);
    PlanSerializer.ensureEnumInt(item.travelMode ?? item.transportMode, [0, 1, 2, 3], `events[${index}].travelMode`);
    if (item.transportMode !== undefined) {
      PlanSerializer.ensureEnumInt(item.transportMode, [0, 1, 2, 3], `events[${index}].transportMode`);
    }
    PlanSerializer.ensureEnumInt(item.isTravelManual, [0, 1], `events[${index}].isTravelManual`);
    PlanSerializer.ensureEnumInt(item.source, [0, 1], `events[${index}].source`);
    PlanSerializer.ensureEnumInt(item.completionStatus, [0, 1, 2], `events[${index}].completionStatus`);

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
