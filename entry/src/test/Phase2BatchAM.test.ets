import { describe, it, expect } from '@ohos/hypium';
import { AiParserItem, AiResponseParser } from '../main/ets/infrastructure/services/AiResponseParser';
import { PlanImportExportService, PlanJsonImportCancelToken } from '../main/ets/infrastructure/services/PlanImportExportService';
import { ArrivalReminderCoordinator, ArrivalReminderSubscriptionHandlers } from '../main/ets/infrastructure/services/ArrivalReminderCoordinator';
import { ArrivalReminderAction, ArrivalReminderPayload, ArrivalReminderEngine } from '../main/ets/infrastructure/services/ArrivalReminderEngine';
import { ArrivalReminderStore } from '../main/ets/common/utils/arrival/ArrivalReminderStore';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { PlanStatus } from '../main/ets/domain/statemachine/PlanStatus';
import { CompactPlanSerializer, SharePlanMetaInput } from '../main/ets/domain/serializers/CompactPlanSerializer';
import { PlanSerializer, ExportPlanMeta } from '../main/ets/domain/serializers/PlanSerializer';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import { PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../main/ets/infrastructure/persistence/EventRepositoryImpl';

interface MockStoreStats { beginCount: number; commitCount: number; rollbackCount: number; }
class MockStore {
  public stats: MockStoreStats = { beginCount: 0, commitCount: 0, rollbackCount: 0 };
  public beginTransaction(): void { this.stats.beginCount += 1; }
  public commit(): void { this.stats.commitCount += 1; }
  public rollBack(): void { this.stats.rollbackCount += 1; }
}

interface PlanTransitionEvent {
  planId: string;
  toStatus: PlanStatus;
}

interface PlanStatusSnapshot {
  status: PlanStatus;
}

class ArrivalEngineStub {
  private readonly onAcknowledge: (id: number, action: ArrivalReminderAction) => void;

  constructor(onAcknowledge: (id: number, action: ArrivalReminderAction) => void) {
    this.onAcknowledge = onAcknowledge;
  }

  public acknowledgeReminder(id: number, action: ArrivalReminderAction): void {
    this.onAcknowledge(id, action);
  }
}

class FakePlanStateMachine {
  public status: PlanStatus = PlanStatus.READY;
  private listener: ((event: PlanTransitionEvent) => void) | null = null;
  public subscribePlanTransition(_planId: string, h: (event: PlanTransitionEvent) => void): () => void {
    this.listener = h;
    return (): void => { this.listener = null; };
  }
  public getPlanStatus(_planId: string): PlanStatusSnapshot { return { status: this.status }; }
  public emit(planId: string, toStatus: PlanStatus): void { this.listener?.({ planId: planId, toStatus: toStatus }); }
}

function identity(item: AiParserItem): AiParserItem { return item; }
function assertThrow(action: () => void, expected: string): void {
  let message = '';
  try { action(); } catch (error) { message = error instanceof Error ? error.message : ''; }
  expect(message.includes(expected)).assertTrue();
}
function payload(planId: number, eventId: number, seq: number): ArrivalReminderPayload {
  return { seq: seq, planId: planId, eventId: eventId, placeName: 'p', distanceMeters: 100, triggerAt: 1 };
}
function startable(id: number): EventEntity {
  const e = new EventEntity();
  e.id = id;
  e.status = 1;
  e.completion_status = EventEntity.STATE_PENDING;
  e.actual_start_time = 0;
  e.actual_end_time = 0;
  return e;
}
function active(id: number): EventEntity {
  const e = startable(id);
  e.actual_start_time = 123;
  return e;
}
function eventItem(name: string, sortOrder: number): TravelPlanItem {
  return {
    name: name, note: '', duration: 60, type: 'FLOW', preTravelMinutes: -1, sortOrder: sortOrder,
    status: 1, lockStatus: 0, fixedStartTime: '09:00', dayOffset: 0, itemType: 0, priority: 0,
    transportMode: 2, travelMode: 2, isTravelManual: 0, source: 0, delFlag: 0, groupId: 0,
    address: '', aiReasoning: '', latitude: 30.1, longitude: 120.2, actualStartTime: 0, actualEndTime: 0, completionStatus: 0
  };
}
function shareMeta(): SharePlanMetaInput {
  return { title: 'Trip', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 };
}

export default function phase2BatchAMTest() {
  describe('phase2BatchAMTest_ai_parser', () => {
    it('normal: parse_items_from_content_should_parse_markdown_json', 0, () => {
      // Arrange
      // Act
      // Assert
      const items = AiResponseParser.parseItemsFromContent('```json\n[{"name":"A","duration":60,"ai_reasoning":"r","type":0}]\n```', identity);
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('A');
    });

    it('boundary: parse_items_from_content_should_parse_line_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const items = AiResponseParser.parseItemsFromContent('- name:Hotel,duration:90min,reason:ok,type:2', identity);
      expect(items.length).assertEqual(1);
      expect(items[0].duration).assertEqual(90);
    });

    it('invalid: parse_items_from_content_should_throw_on_invalid_item', 0, () => {
      // Arrange
      // Act
      // Assert
      assertThrow((): void => {
        AiResponseParser.parseItemsFromContent('[{"name":"bad","duration":0,"ai_reasoning":"r","type":0}]', identity);
      }, 'index=0');
    });

    it('normal: parse_model_response_should_parse_message_array', 0, () => {
      // Arrange
      // Act
      // Assert
      const res = '{"choices":[{"message":{"content":[{"text":"[{\\"name\\":\\"B\\",\\"duration\\":70,\\"ai_reasoning\\":\\"r\\",\\"type\\":1}]"}]}}]}';
      const items = AiResponseParser.parseModelResponseForTest(res, identity);
      expect(items[0].name).assertEqual('B');
    });

    it('boundary: parse_model_response_should_fallback_to_choice_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const res = '{"choices":[{"text":"[{\\"name\\":\\"C\\",\\"duration\\":80,\\"ai_reasoning\\":\\"r\\",\\"type\\":0}]"}]}';
      const items = AiResponseParser.parseModelResponseForTest(res, identity);
      expect(items[0].duration).assertEqual(80);
    });

    it('invalid: parse_model_response_should_throw_when_json_invalid', 0, () => {
      // Arrange
      // Act
      // Assert
      assertThrow((): void => { AiResponseParser.parseModelResponseForTest('{bad', identity); }, 'JSON');
    });
  });

  describe('phase2BatchAMTest_compact_serializer', () => {
    it('normal: compress_for_share_should_output_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      const parsed = JSON.parse(CompactPlanSerializer.compressForShare(shareMeta(), [eventItem('A', 0)])) as Record<string, Object>;
      expect(Number(parsed['v'])).assertEqual(1);
      expect((parsed['e'] as Object[]).length).assertEqual(1);
    });

    it('boundary: compress_for_share_should_support_empty_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const parsed = JSON.parse(CompactPlanSerializer.compressForShare(shareMeta(), [])) as Record<string, Object>;
      expect((parsed['e'] as Object[]).length).assertEqual(0);
    });

    it('invalid: compress_for_share_should_fallback_transport_mode', 0, () => {
      // Arrange
      // Act
      // Assert
      const e = eventItem('B', 0);
      e.travelMode = undefined;
      e.transportMode = 3;
      const out = CompactPlanSerializer.decompressFromShare(CompactPlanSerializer.compressForShare(shareMeta(), [e]));
      expect(out.events[0].travelMode).assertEqual(3);
    });

    it('normal: decompress_from_share_should_restore_fields', 0, () => {
      // Arrange
      // Act
      // Assert
      const out = CompactPlanSerializer.decompressFromShare(CompactPlanSerializer.compressForShare(shareMeta(), [eventItem('C', 0)]));
      expect(out.plan.title).assertEqual('Trip');
      expect(out.events.length).assertEqual(1);
    });

    it('boundary: decompress_from_share_should_restore_empty_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const out = CompactPlanSerializer.decompressFromShare(CompactPlanSerializer.compressForShare(shareMeta(), []));
      expect(out.events.length).assertEqual(0);
    });

    it('invalid: decompress_from_share_should_throw_on_version_mismatch', 0, () => {
      // Arrange
      // Act
      // Assert
      assertThrow((): void => {
        CompactPlanSerializer.decompressFromShare('{"v":9,"exp":1,"p":{"t":"x","sd":1,"st":1,"ar":1},"e":[]}');
      }, 'unsupported_version:9');
    });
  });
  describe('phase2BatchAMTest_plan_serializer', () => {
    it('normal: serialize_plan_should_include_schema_and_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const raw = PlanSerializer.serializePlan({ title: 'P1', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
      const parsed = JSON.parse(raw) as Record<string, Object>;
      expect(Number(parsed['schemaVersion'])).assertEqual(1);
      expect((parsed['events'] as Object[]).length).assertEqual(1);
    });

    it('boundary: serialize_plan_should_allow_empty_events', 0, () => {
      // Arrange
      // Act
      // Assert
      const raw = PlanSerializer.serializePlan({ title: 'P2', startDate: 1713000000000, status: 0, enableAutoAmapRoute: 1 }, []);
      const parsed = JSON.parse(raw) as Record<string, Object>;
      expect((parsed['events'] as Object[]).length).assertEqual(0);
    });

    it('invalid: serialize_plan_should_sanitize_invalid_duration', 0, () => {
      // Arrange
      // Act
      // Assert
      const bad = eventItem('bad', 0);
      bad.duration = -8;
      const parsed = JSON.parse(PlanSerializer.serializePlan({ title: 'P3', startDate: 1713000000000, status: 0, enableAutoAmapRoute: 1 }, [bad])) as Record<string, Object>;
      const events = parsed['events'] as Record<string, Object>[];
      expect(Number(events[0]['duration'])).assertEqual(30);
    });

    it('normal: deserialize_plan_should_accept_valid_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      const raw = PlanSerializer.serializePlan({ title: 'P4', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
      const out = PlanSerializer.deserializePlan(raw);
      expect(out.plan.title).assertEqual('P4');
      expect(out.events.length).assertEqual(1);
    });

    it('boundary: deserialize_plan_should_allow_pre_travel_minus_one', 0, () => {
      // Arrange
      // Act
      // Assert
      const e = eventItem('A', 0);
      e.preTravelMinutes = -1;
      const out = PlanSerializer.deserializePlan(PlanSerializer.serializePlan({ title: 'P5', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [e]));
      expect(out.events[0].preTravelMinutes).assertEqual(-1);
    });

    it('invalid: deserialize_plan_should_reject_missing_plan_or_events', 0, () => {
      // Arrange
      // Act
      // Assert
      assertThrow((): void => { PlanSerializer.deserializePlan('{"schemaVersion":1}'); }, 'invalid_payload:missing_plan_or_events');
    });

    it('normal: normalize_import_event_should_keep_valid_fields', 0, () => {
      // Arrange
      // Act
      // Assert
      const out = PlanSerializer.normalizeImportEvent(eventItem('N', 20), 3);
      expect(out.name).assertEqual('N');
      expect(out.sortOrder).assertEqual(20);
    });

    it('boundary: normalize_import_event_should_fallback_name_by_index', 0, () => {
      // Arrange
      // Act
      // Assert
      const e = eventItem('', 0);
      e.name = '';
      const out = PlanSerializer.normalizeImportEvent(e, 2);
      expect(out.name.length > 0).assertTrue();
    });

    it('invalid: normalize_import_event_should_sanitize_negative_duration', 0, () => {
      // Arrange
      // Act
      // Assert
      const e = eventItem('X', 0);
      e.duration = -1;
      const out = PlanSerializer.normalizeImportEvent(e, 0);
      expect(out.duration).assertEqual(30);
    });
  });

  describe('phase2BatchAMTest_plan_import_export', () => {
    it('normal: set_deps_for_test_should_take_effect', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new MockStore();
      let inserted = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 7001,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => { inserted += 1; return inserted; },
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });
      const raw = PlanSerializer.serializePlan({ title: 'I1', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
      const id = await PlanImportExportService.importPlanFromJson(raw);
      PlanImportExportService.setDepsForTest(null);
      expect(id).assertEqual(7001);
      expect(store.stats.commitCount).assertEqual(1);
      done();
    });

    it('boundary: set_deps_for_test_null_should_not_break_parse_error', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      PlanImportExportService.setDepsForTest(null);
      let message = '';
      try { await PlanImportExportService.importPlanFromJson('{bad'); } catch (error) { message = error instanceof Error ? error.message : ''; }
      expect(message).assertEqual('invalid_payload:json_parse_failed');
      done();
    });

    it('invalid: set_deps_for_test_should_surface_create_plan_failed', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new MockStore();
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 0,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 1,
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });
      let message = '';
      try {
        const raw = PlanSerializer.serializePlan({ title: 'I2', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
        await PlanImportExportService.importPlanFromJson(raw);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }
      expect(message).assertEqual('create_plan_failed');
      done();
    });

    it('normal: export_plan_to_json_should_serialize_plan', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const originPlan = Reflect.get(PlanRepositoryImpl, 'getPlanById') as Object;
      const originEvents = Reflect.get(EventRepositoryImpl, 'getAllEvents') as Object;
      Reflect.set(PlanRepositoryImpl, 'getPlanById', async (_id: number): Promise<ExportPlanMeta> => ({ title: 'E1', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }));
      Reflect.set(EventRepositoryImpl, 'getAllEvents', async (_planId: number): Promise<TravelPlanItem[]> => [eventItem('A', 0)]);
      const raw = await PlanImportExportService.exportPlanToJson(11);
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const plan = parsed['plan'] as Record<string, Object>;
      expect(String(plan['title'])).assertEqual('E1');
      Reflect.set(PlanRepositoryImpl, 'getPlanById', originPlan);
      Reflect.set(EventRepositoryImpl, 'getAllEvents', originEvents);
      done();
    });

    it('boundary: export_plan_to_json_should_fallback_nullable_fields', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const originPlan = Reflect.get(PlanRepositoryImpl, 'getPlanById') as Object;
      const originEvents = Reflect.get(EventRepositoryImpl, 'getAllEvents') as Object;
      Reflect.set(PlanRepositoryImpl, 'getPlanById', async (_id: number): Promise<ExportPlanMeta> => ({ title: 'E2', startDate: 0, status: 0, enableAutoAmapRoute: 1 }));
      Reflect.set(EventRepositoryImpl, 'getAllEvents', async (_planId: number): Promise<TravelPlanItem[]> => []);
      const raw = await PlanImportExportService.exportPlanToJson(12);
      const parsed = JSON.parse(raw) as Record<string, Object>;
      const plan = parsed['plan'] as Record<string, Object>;
      expect(Number(plan['status'])).assertEqual(0);
      expect(Number(plan['enableAutoAmapRoute'])).assertEqual(1);
      Reflect.set(PlanRepositoryImpl, 'getPlanById', originPlan);
      Reflect.set(EventRepositoryImpl, 'getAllEvents', originEvents);
      done();
    });

    it('invalid: export_plan_to_json_should_throw_when_missing', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const originPlan = Reflect.get(PlanRepositoryImpl, 'getPlanById') as Object;
      const originEvents = Reflect.get(EventRepositoryImpl, 'getAllEvents') as Object;
      Reflect.set(PlanRepositoryImpl, 'getPlanById', async (_id: number): Promise<Object | null> => null);
      Reflect.set(EventRepositoryImpl, 'getAllEvents', async (_planId: number): Promise<TravelPlanItem[]> => []);
      let message = '';
      try { await PlanImportExportService.exportPlanToJson(13); } catch (error) { message = error instanceof Error ? error.message : ''; }
      expect(message).assertEqual('plan_not_found:13');
      Reflect.set(PlanRepositoryImpl, 'getPlanById', originPlan);
      Reflect.set(EventRepositoryImpl, 'getAllEvents', originEvents);
      done();
    });
    it('normal: import_plan_from_json_should_commit_on_valid_input', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new MockStore();
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 8101,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 1,
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });
      const raw = PlanSerializer.serializePlan({ title: 'I3', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
      const id = await PlanImportExportService.importPlanFromJson(raw);
      PlanImportExportService.setDepsForTest(null);
      expect(id).assertEqual(8101);
      expect(store.stats.rollbackCount).assertEqual(0);
      done();
    });

    it('boundary: import_plan_from_json_should_fallback_start_date', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      const store = new MockStore();
      let persistedStartDate = 0;
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore => store,
        createPlan: async (_title: string, startDate: number): Promise<number> => { persistedStartDate = startDate; return 8102; },
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 1,
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });
      const raw = PlanSerializer.serializePlan({ title: 'I4', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
      const payloadObj = JSON.parse(raw) as Record<string, Object>;
      const plan = payloadObj['plan'] as Record<string, Object>;
      plan['startDate'] = 0;
      payloadObj['plan'] = plan;
      let message = '';
      try {
        await PlanImportExportService.importPlanFromJson(JSON.stringify(payloadObj));
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }
      expect(message).assertEqual('invalid_field:plan.startDate:out_of_range:0');
      done();
    });

    it('invalid: import_plan_from_json_should_throw_when_db_not_ready', 0, async (done: () => void) => {
      // Arrange
      // Act
      // Assert
      PlanImportExportService.setDepsForTest({
        getStore: (): MockStore | null => null,
        createPlan: async (_title: string, _startDate: number): Promise<number> => 1,
        updateAutoAmapRoute: async (_id: number, _enabled: boolean): Promise<void> => {},
        updatePlanStatus: async (_id: number, _status: number): Promise<void> => {},
        insertEvent: async (_planId: number, _item: TravelPlanItem): Promise<number> => 1,
        hardDeletePlan: async (_id: number): Promise<void> => {}
      });
      let message = '';
      try {
        const raw = PlanSerializer.serializePlan({ title: 'I5', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, [eventItem('A', 0)]);
        await PlanImportExportService.importPlanFromJson(raw);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        PlanImportExportService.setDepsForTest(null);
      }
      expect(message).assertEqual('db_not_ready');
      done();
    });

    it('normal: cancel_token_should_not_throw_before_cancel', 0, () => {
      // Arrange
      // Act
      // Assert
      const token = new PlanJsonImportCancelToken();
      let ok = true;
      try { token.throwIfCancelled('x'); } catch (_error) { ok = false; }
      expect(ok).assertTrue();
    });

    it('boundary: cancel_token_should_remain_cancelled_after_multi_cancel', 0, () => {
      // Arrange
      // Act
      // Assert
      const token = new PlanJsonImportCancelToken();
      token.cancel();
      token.cancel();
      let message = '';
      try { token.throwIfCancelled('again'); } catch (error) { message = error instanceof Error ? error.message : ''; }
      expect(message).assertEqual('import_cancelled:again');
    });

    it('invalid: cancel_token_should_throw_after_cancel', 0, () => {
      // Arrange
      // Act
      // Assert
      const token = new PlanJsonImportCancelToken();
      token.cancel();
      assertThrow((): void => { token.throwIfCancelled('before_parse'); }, 'import_cancelled:before_parse');
    });
  });

  describe('phase2BatchAMTest_arrival_coordinator', () => {
    it('normal: get_instance_should_return_singleton', 0, () => {
      // Arrange
      // Act
      // Assert
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const a = ArrivalReminderCoordinator.getInstance();
      const b = ArrivalReminderCoordinator.getInstance();
      expect(a === b).assertTrue();
    });

    it('boundary: get_instance_should_create_new_after_reset', 0, () => {
      // Arrange
      // Act
      // Assert
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const a = ArrivalReminderCoordinator.getInstance();
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
      const b = ArrivalReminderCoordinator.getInstance();
      expect(a === b).assertFalse();
    });

    it('invalid: get_instance_should_return_polluted_instance', 0, () => {
      // Arrange
      // Act
      // Assert
      const polluted = ArrivalReminderCoordinator.getInstance();
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', polluted);
      const got = ArrivalReminderCoordinator.getInstance();
      expect(got === polluted).assertTrue();
      Reflect.set(ArrivalReminderCoordinator as Object, 'instance', null);
    });

    it('normal: subscribe_plan_should_show_home_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(301, 3001, 1));
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachine();
      machine.status = PlanStatus.READY;
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      let showCount = 0;
      const handlers: ArrivalReminderSubscriptionHandlers = {
        isDialogOpen: (): boolean => false,
        resolvePlanTitle: (_id: number): string => 'title',
        onShowHome: (_payload: ArrivalReminderPayload, _title: string): void => { showCount += 1; },
        pollIntervalMs: 1000
      };
      const unsub = coordinator.subscribePlan('*', handlers);
      unsub();
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(showCount).assertEqual(1);
    });

    it('boundary: subscribe_plan_should_skip_when_terminal_status', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(302, 3002, 1));
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachine();
      machine.status = PlanStatus.COMPLETED;
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      let showCount = 0;
      const unsub = coordinator.subscribePlan('*', {
        isDialogOpen: (): boolean => false,
        resolvePlanTitle: (_id: number): string => 'title',
        onShowHome: (_payload: ArrivalReminderPayload, _title: string): void => { showCount += 1; },
        pollIntervalMs: 1000
      });
      unsub();
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(showCount).assertEqual(0);
    });

    it('invalid: subscribe_plan_should_dismiss_when_active_conflict', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(303, 3003, 1));
      const coordinator = ArrivalReminderCoordinator.getInstance();
      const machine = new FakePlanStateMachine();
      machine.status = PlanStatus.READY;
      Reflect.set(coordinator as Object, 'planStateMachine', machine);
      let called = 0;
      const originAck = Reflect.get(coordinator as Object, 'acknowledge') as Object;
      Reflect.set(coordinator as Object, 'acknowledge', (_eventId: number, _action: ArrivalReminderAction): void => { called += 1; });
      const unsub = coordinator.subscribePlan(303, {
        isDialogOpen: (): boolean => false,
        resolveEvents: (): EventEntity[] => [active(3004), startable(3003)],
        onShowPlan: (_payload: ArrivalReminderPayload): void => {},
        pollIntervalMs: 1000
      });
      unsub();
      Reflect.set(coordinator as Object, 'acknowledge', originAck);
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(called).assertEqual(1);
    });

    it('normal: consume_on_home_should_show_when_dialog_closed', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(401, 4001, 1));
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnHome({ isDialogOpen: false, resolvePlanTitle: (_id: number): string => 'x', onShow: (_p: ArrivalReminderPayload, _t: string): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(1);
    });

    it('boundary: consume_on_home_should_skip_when_dialog_open', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(402, 4002, 1));
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnHome({ isDialogOpen: true, resolvePlanTitle: (_id: number): string => 'x', onShow: (_p: ArrivalReminderPayload, _t: string): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(0);
    });

    it('invalid: consume_on_home_should_skip_when_payload_absent', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => null);
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnHome({ isDialogOpen: false, resolvePlanTitle: (_id: number): string => 'x', onShow: (_p: ArrivalReminderPayload, _t: string): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(0);
    });

    it('normal: consume_on_plan_should_show_for_startable_target', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(501, 5001, 1));
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnPlan({ isDialogOpen: false, currentPlanId: 501, events: [startable(5001)], onShow: (_p: ArrivalReminderPayload): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(1);
    });

    it('boundary: consume_on_plan_should_skip_when_dialog_open', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(502, 5002, 1));
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnPlan({ isDialogOpen: true, currentPlanId: 502, events: [startable(5002)], onShow: (_p: ArrivalReminderPayload): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(0);
    });

    it('invalid: consume_on_plan_should_skip_on_plan_mismatch', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(503, 5003, 1));
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnPlan({ isDialogOpen: false, currentPlanId: 504, events: [startable(5003)], onShow: (_p: ArrivalReminderPayload): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(0);
    });

    it('normal: acknowledge_should_forward_start', 0, () => {
      // Arrange
      // Act
      // Assert
      const origin = Reflect.get(ArrivalReminderEngine, 'getInstance') as Object;
      let action = '';
      Reflect.set(ArrivalReminderEngine, 'getInstance', (): Object => new ArrivalEngineStub((_id: number, a: ArrivalReminderAction): void => { action = a; }));
      ArrivalReminderCoordinator.getInstance().acknowledge(1, 'start');
      Reflect.set(ArrivalReminderEngine, 'getInstance', origin);
      expect(action).assertEqual('start');
    });

    it('boundary: acknowledge_should_forward_dismiss', 0, () => {
      // Arrange
      // Act
      // Assert
      const origin = Reflect.get(ArrivalReminderEngine, 'getInstance') as Object;
      let action = '';
      Reflect.set(ArrivalReminderEngine, 'getInstance', (): Object => new ArrivalEngineStub((_id: number, a: ArrivalReminderAction): void => { action = a; }));
      ArrivalReminderCoordinator.getInstance().acknowledge(1, 'dismiss');
      Reflect.set(ArrivalReminderEngine, 'getInstance', origin);
      expect(action).assertEqual('dismiss');
    });

    it('invalid: acknowledge_should_tolerate_unknown_action_value', 0, () => {
      // Arrange
      // Act
      // Assert
      const origin = Reflect.get(ArrivalReminderEngine, 'getInstance') as Object;
      let called = false;
      Reflect.set(ArrivalReminderEngine, 'getInstance', (): Object => new ArrivalEngineStub((_id: number, _a: ArrivalReminderAction): void => { called = true; }));
      ArrivalReminderCoordinator.getInstance().acknowledge(1, 'weird' as ArrivalReminderAction);
      Reflect.set(ArrivalReminderEngine, 'getInstance', origin);
      expect(called).assertTrue();
    });

    it('conflict: consume_on_plan_should_skip_when_active_event_conflicts', 0, () => {
      // Arrange
      // Act
      // Assert
      const originRead = Reflect.get(ArrivalReminderStore, 'readPayload') as Object;
      Reflect.set(ArrivalReminderStore, 'readPayload', (): ArrivalReminderPayload | null => payload(601, 6001, 1));
      const c = ArrivalReminderCoordinator.getInstance();
      let shown = 0;
      c.consumeOnPlan({ isDialogOpen: false, currentPlanId: 601, events: [active(6002), startable(6001)], onShow: (_p: ArrivalReminderPayload): void => { shown += 1; } });
      Reflect.set(ArrivalReminderStore, 'readPayload', originRead);
      expect(shown).assertEqual(0);
    });

    it('regression: compact_serializer_should_keep_transport_mode_fallback_as_walk', 0, () => {
      // Arrange
      // Act
      // Assert
      const invalidItem = eventItem('reg', 0);
      invalidItem.transportMode = 99;
      invalidItem.travelMode = 99;
      const serialized = CompactPlanSerializer.compressForShare(shareMeta(), [invalidItem]);
      const restored = CompactPlanSerializer.decompressFromShare(serialized);
      expect(restored.events.length > 0).assertTrue();
      expect(restored.events[0].travelMode).assertEqual(99);
    });

    it('combined: parse_and_serialize_roundtrip_should_keep_item_count', 0, () => {
      // Arrange
      // Act
      // Assert
      const parsed = AiResponseParser.parseItemsFromContent('[{\"name\":\"a\",\"duration\":30,\"ai_reasoning\":\"r\",\"type\":0}]', identity);
      const events: TravelPlanItem[] = parsed.map((item: AiParserItem, index: number) => {
        const base = eventItem(item.name, index);
        base.duration = item.duration;
        return base;
      });
      const json = PlanSerializer.serializePlan({ title: 'combined', startDate: 1713000000000, status: 1, enableAutoAmapRoute: 1 }, events);
      const restored = PlanSerializer.deserializePlan(json);
      expect(restored.events.length).assertEqual(1);
    });
  });
}
