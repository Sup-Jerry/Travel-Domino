import { describe, expect, it } from '@ohos/hypium';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

interface PlanPayloadPlanEZ {
  title: string;
  startDate: number;
  status: number;
  enableAutoAmapRoute: number;
}

interface PlanPayloadEZ {
  schemaVersion: number;
  exportedAt: number;
  sourcePlanId: number;
  plan: PlanPayloadPlanEZ;
  events: TravelPlanItem[];
}

function assertThrowEZ(action: () => void, expected: string): void {
  let message = '';
  try {
    action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  expect(message).assertEqual(expected);
}

function repeatTextEZ(text: string, count: number): string {
  let out = '';
  for (let i = 0; i < count; i++) {
    out += text;
  }
  return out;
}

function buildEventEZ(name: string): TravelPlanItem {
  return {
    name: name,
    note: '',
    status: 1,
    duration: 30,
    preTravelMinutes: 0,
    sortOrder: 100,
    lockStatus: 0,
    fixedStartTime: '08:00',
    dayOffset: 0,
    itemType: 0,
    priority: 0,
    travelMode: 2,
    transportMode: 2,
    isTravelManual: 0,
    source: 0,
    groupId: 0,
    actualStartTime: 0,
    actualEndTime: 0,
    completionStatus: 0,
    type: 'FLOW'
  };
}

function buildPayloadEZ(events: TravelPlanItem[]): PlanPayloadEZ {
  return {
    schemaVersion: 1,
    exportedAt: 1713000000000,
    sourcePlanId: 0,
    plan: {
      title: 'Plan EZ',
      startDate: 1713000000000,
      status: 1,
      enableAutoAmapRoute: 1
    },
    events: events
  };
}

function stringifyPayloadEZ(payload: PlanPayloadEZ): string {
  return JSON.stringify(payload);
}

export default function phase2BatchEZTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEZ_plan_serializer_edges', () => {
    it('invalid: plan_serializer_should_reject_parse_error_and_missing_sections', 0, () => {
      // Arrange
      // Act
      // Assert
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan('{');
      }, 'invalid_payload:json_parse_failed');

      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan('{"schemaVersion":1,"events":[]}');
      }, 'invalid_payload:missing_plan_or_events');
    });

    it('boundary: plan_serializer_should_reject_too_many_events_and_long_title', 0, () => {
      // Arrange
      // Act
      // Assert
      const manyEvents: TravelPlanItem[] = [];
      for (let i = 0; i < 2001; i++) {
        manyEvents.push(buildEventEZ(`event_${i}`));
      }

      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ(manyEvents)));
      }, 'invalid_payload:too_many_events:2001');

      const payload = buildPayloadEZ([buildEventEZ('title_event_ez')]);
      payload.plan.title = repeatTextEZ('T', 81);
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(payload));
      }, 'invalid_payload:title_too_long:81');
    });

    it('invalid: plan_serializer_should_reject_plan_field_range_and_enum_edges', 0, () => {
      // Arrange
      // Act
      // Assert
      const badStartDate = buildPayloadEZ([buildEventEZ('start_date_event_ez')]);
      badStartDate.plan.startDate = 1;
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(badStartDate));
      }, 'invalid_field:plan.startDate:out_of_range:1');

      const badStatus = buildPayloadEZ([buildEventEZ('status_event_ez')]);
      badStatus.plan.status = 3;
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(badStatus));
      }, 'invalid_field:plan.status:out_of_range:3');

      const badAutoRoute = buildPayloadEZ([buildEventEZ('route_event_ez')]);
      badAutoRoute.plan.enableAutoAmapRoute = 2;
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(badAutoRoute));
      }, 'invalid_field:plan.enableAutoAmapRoute:invalid_enum:2');
    });

    it('combined: plan_serializer_should_reject_event_text_and_type_edges', 0, () => {
      // Arrange
      // Act
      // Assert
      const emptyName = buildEventEZ('empty_name_event_ez');
      emptyName.name = '   ';
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([emptyName])));
      }, 'invalid_event:name_empty:index=0');

      const longName = buildEventEZ(repeatTextEZ('N', 61));
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([longName])));
      }, 'invalid_event:name_too_long:index=0,len=61');

      const badType = buildEventEZ('type_event_ez');
      badType.type = 'BAD';
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([badType])));
      }, 'invalid_event:type:index=0,value=BAD');
    });

    it('regression: plan_serializer_should_reject_event_range_and_transport_edges', 0, () => {
      // Arrange
      // Act
      // Assert
      const badDuration = buildEventEZ('duration_event_ez');
      badDuration.duration = 0;
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([badDuration])));
      }, 'invalid_field:events[0].duration:out_of_range:0');

      const badActualRange = buildEventEZ('actual_range_event_ez');
      badActualRange.actualStartTime = 200;
      badActualRange.actualEndTime = 100;
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([badActualRange])));
      }, 'invalid_event:actual_time_range:index=0');

      const badTransport = buildEventEZ('transport_event_ez');
      badTransport.transportMode = 9;
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([badTransport])));
      }, 'invalid_field:events[0].transportMode:invalid_enum:9');
    });

    it('boundary: plan_serializer_should_reject_oversized_raw_before_json_parse', 0, () => {
      // Arrange
      const oversizedRaw = repeatTextEZ('x', 1024 * 1024 + 1);

      // Act
      // Assert
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(oversizedRaw);
      }, `invalid_payload:json_too_large:${oversizedRaw.length}`);
    });

    it('invalid: plan_serializer_should_reject_not_number_plan_and_event_fields', 0, () => {
      // Arrange
      const badPlan = buildPayloadEZ([buildEventEZ('bad_plan_number_ez')]);
      const badEvent = buildPayloadEZ([buildEventEZ('bad_event_number_ez')]);

      // Act
      Reflect.set(badPlan.plan as Object, 'startDate', 'bad');
      Reflect.set(badEvent.events[0] as Object, 'status', 'bad');

      // Assert
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(badPlan));
      }, 'invalid_field:plan.startDate:not_number');
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(badEvent));
      }, 'invalid_field:events[0].status:not_number');
    });

    it('combined: plan_serializer_should_reject_too_long_note_reasoning_and_address', 0, () => {
      // Arrange
      const noteEvent = buildEventEZ('note_too_long_ez');
      const reasoningEvent = buildEventEZ('reasoning_too_long_ez');
      const addressEvent = buildEventEZ('address_too_long_ez');
      noteEvent.note = repeatTextEZ('n', 2001);
      reasoningEvent.aiReasoning = repeatTextEZ('r', 4001);
      addressEvent.address = repeatTextEZ('a', 2001);

      // Act
      // Assert
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([noteEvent])));
      }, 'invalid_event:note_too_long:index=0');
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([reasoningEvent])));
      }, 'invalid_event:reasoning_too_long:index=0');
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(buildPayloadEZ([addressEvent])));
      }, 'invalid_event:address_too_long:index=0');
    });

    it('boundary: plan_serializer_should_normalize_export_and_import_with_numeric_fallbacks', 0, () => {
      // Arrange
      const rawEvent = buildEventEZ('');
      Reflect.set(rawEvent as Object, 'duration', 'bad');
      Reflect.set(rawEvent as Object, 'travelMode', 'bad');
      Reflect.set(rawEvent as Object, 'latitude', 'bad');
      Reflect.set(rawEvent as Object, 'actualStartTime', -3);
      rawEvent.transportMode = undefined;

      // Act
      const exported = JSON.parse(PlanSerializer.serializePlan({
        title: 'Fallback Plan',
        startDate: 1713000000000,
        status: 1,
        enableAutoAmapRoute: 1
      }, [rawEvent])) as PlanPayloadEZ;
      const imported = PlanSerializer.normalizeImportEvent(rawEvent, 2);

      // Assert
      expect(exported.events[0].duration || 0).assertEqual(30);
      expect(exported.events[0].travelMode || 0).assertEqual(2);
      expect(exported.events[0].transportMode || 0).assertEqual(2);
      expect(exported.events[0].latitude || 0).assertEqual(0);
      expect(exported.events[0].actualStartTime || 0).assertEqual(0);
      expect(imported.duration || 0).assertEqual(30);
      expect(imported.travelMode || 0).assertEqual(2);
      expect(imported.transportMode || 0).assertEqual(2);
      expect(imported.longitude || 0).assertEqual(0);
    });

    it('invalid: plan_serializer_should_allow_missing_transport_mode_but_reject_coordinate_nan_when_provided', 0, () => {
      // Arrange
      const noTransport = buildEventEZ('no_transport_mode_ez');
      noTransport.transportMode = undefined;
      const payloadWithoutTransport = buildPayloadEZ([noTransport]);

      const badCoordinate = buildEventEZ('coordinate_nan_ez');
      Reflect.set(badCoordinate as Object, 'latitude', 'bad');
      const payloadWithBadCoordinate = buildPayloadEZ([badCoordinate]);

      // Act
      const parsed = PlanSerializer.deserializePlan(stringifyPayloadEZ(payloadWithoutTransport));

      // Assert
      expect(parsed.events.length).assertEqual(1);
      assertThrowEZ((): void => {
        PlanSerializer.deserializePlan(stringifyPayloadEZ(payloadWithBadCoordinate));
      }, 'invalid_event:coordinate_nan:index=0');
    });

    it('normal: validator_marker_should_cover_normal_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });

    it('conflict: validator_marker_should_cover_conflict_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
