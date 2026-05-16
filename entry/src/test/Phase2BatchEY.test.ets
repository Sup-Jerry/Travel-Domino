import { describe, expect, it } from '@ohos/hypium';
import { PlanSerializer } from '../main/ets/domain/serializers/PlanSerializer';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

interface PlanPayloadPlanEY {
  title: string;
  startDate: number;
  status: number;
  enableAutoAmapRoute: number;
}

interface PlanPayloadEY {
  schemaVersion: number;
  exportedAt: number;
  sourcePlanId: number;
  plan: PlanPayloadPlanEY;
  events: TravelPlanItem[];
}

function assertThrowEY(action: () => void, expected: string): void {
  let message = '';
  try {
    action();
  } catch (error) {
    message = error instanceof Error ? error.message : '';
  }
  expect(message).assertEqual(expected);
}

function buildEventEY(name: string): TravelPlanItem {
  return {
    name: name,
    note: '',
    status: 1,
    duration: 45,
    preTravelMinutes: 0,
    sortOrder: 100,
    lockStatus: 0,
    fixedStartTime: '09:30',
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

function buildPayloadEY(events: TravelPlanItem[]): string {
  const payload: PlanPayloadEY = {
    schemaVersion: 1,
    exportedAt: 1713000000000,
    sourcePlanId: 0,
    plan: {
      title: 'Plan EY',
      startDate: 1713000000000,
      status: 1,
      enableAutoAmapRoute: 1
    },
    events: events
  };
  return JSON.stringify(payload);
}

export default function phase2BatchEYTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEY_plan_serializer_validation', () => {
    it('normal: plan_serializer_should_accept_minimal_valid_payload', 0, () => {
      // Arrange
      // Act
      // Assert
      const payload = PlanSerializer.deserializePlan(buildPayloadEY([buildEventEY('valid_event_ey')]));

      expect(payload.plan.title).assertEqual('Plan EY');
      expect(payload.events.length).assertEqual(1);
    });

    it('boundary: plan_serializer_should_reject_empty_raw_json', 0, () => {
      // Arrange
      // Act
      // Assert
      assertThrowEY((): void => {
        PlanSerializer.deserializePlan('   ');
      }, 'invalid_payload:empty_json');
    });

    it('invalid: plan_serializer_should_reject_wrong_schema_version', 0, () => {
      // Arrange
      // Act
      // Assert
      const payload = JSON.parse(buildPayloadEY([buildEventEY('schema_event_ey')])) as Object as PlanPayloadEY;
      payload.schemaVersion = 2;

      assertThrowEY((): void => {
        PlanSerializer.deserializePlan(JSON.stringify(payload));
      }, 'invalid_payload:schema_version:2');
    });

    it('conflict: plan_serializer_should_reject_blank_plan_title_after_trim', 0, () => {
      // Arrange
      // Act
      // Assert
      const payload = JSON.parse(buildPayloadEY([buildEventEY('title_event_ey')])) as Object as PlanPayloadEY;
      payload.plan.title = '   ';

      assertThrowEY((): void => {
        PlanSerializer.deserializePlan(JSON.stringify(payload));
      }, 'invalid_payload:empty_title');
    });

    it('regression: plan_serializer_should_reject_fixed_start_time_format', 0, () => {
      // Arrange
      // Act
      // Assert
      const event = buildEventEY('fixed_time_event_ey');
      event.fixedStartTime = '9:3';

      assertThrowEY((): void => {
        PlanSerializer.deserializePlan(buildPayloadEY([event]));
      }, 'invalid_event:fixed_start_time:index=0');
    });

    it('combined: plan_serializer_should_reject_coordinate_nan_out_of_range_and_invalid_enum', 0, () => {
      // Arrange
      // Act
      // Assert
      const missingLng = buildEventEY('coord_nan_event_ey');
      missingLng.latitude = 30;
      const outOfRange = buildEventEY('coord_range_event_ey');
      outOfRange.latitude = 91;
      outOfRange.longitude = 120;
      const invalidEnum = buildEventEY('enum_event_ey');
      invalidEnum.travelMode = 9;

      assertThrowEY((): void => {
        PlanSerializer.deserializePlan(buildPayloadEY([missingLng]));
      }, 'invalid_event:coordinate_nan:index=0');
      assertThrowEY((): void => {
        PlanSerializer.deserializePlan(buildPayloadEY([outOfRange]));
      }, 'invalid_event:coordinate_out_of_range:index=0,lat=91,lng=120');
      assertThrowEY((): void => {
        PlanSerializer.deserializePlan(buildPayloadEY([invalidEnum]));
      }, 'invalid_field:events[0].travelMode:invalid_enum:9');
    });
  });
}
