import { describe, expect, it } from '@ohos/hypium';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';

function buildItemEV(name: string): TravelPlanItem {
  return {
    id: 0,
    name: name,
    note: '',
    status: 1,
    duration: 45,
    preTravelMinutes: 0,
    sortOrder: 100,
    fixedStartTime: '',
    dayOffset: 0,
    type: 'FLOW'
  };
}

export default function phase2BatchEVTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchEV_event_entity_mapping', () => {
    it('normal: event_entity_from_interface_should_prefer_travel_mode_over_transport_mode', 0, () => {
      const item = buildItemEV('mode_ev');
      item.travelMode = 3;
      item.transportMode = 1;

      const entity = EventEntity.fromInterface(item, 77);

      expect(entity.plan_id).assertEqual(77);
      expect(entity.travel_mode).assertEqual(3);
      expect(entity.transport_mode).assertEqual(3);
    });

    it('boundary: event_entity_from_interface_should_fallback_to_transport_mode_when_travel_mode_missing', 0, () => {
      const item = buildItemEV('transport_ev');
      item.transportMode = 2;

      const entity = EventEntity.fromInterface(item, 78);

      expect(entity.travel_mode).assertEqual(2);
      expect(entity.transport_mode).assertEqual(2);
    });

    it('invalid: event_entity_from_interface_should_use_default_mode_when_both_modes_missing', 0, () => {
      const item = buildItemEV('missing_mode_ev');

      const entity = EventEntity.fromInterface(item, 79);

      expect(entity.travel_mode).assertEqual(0);
      expect(entity.transport_mode).assertEqual(0);
    });

    it('conflict: event_entity_from_interface_should_preserve_dynamic_day_offset_even_when_zero', 0, () => {
      const item = buildItemEV('dynamic_day_ev');
      item.dayOffset = 3;
      item.dynamicDayOffset = 0;

      const entity = EventEntity.fromInterface(item, 80);

      expect(entity.day_offset).assertEqual(3);
      expect(entity.dynamic_day_offset).assertEqual(0);
    });

    it('regression: event_entity_roundtrip_should_keep_last_from_and_transit_warning', 0, () => {
      const item = buildItemEV('roundtrip_ev');
      item.lastFromId = 0;
      item.transitWarning = true;
      item.ignoreWait = true;

      const entity = EventEntity.fromInterface(item, 81);
      const restored = entity.toInterface();

      expect(entity.last_from_id).assertEqual(0);
      expect(entity.transit_warning).assertTrue();
      expect(restored.lastFromId).assertEqual(0);
      expect(restored.transitWarning).assertTrue();
      expect(restored.ignoreWait).assertTrue();
    });

    it('combined: event_entity_to_interface_should_map_anchor_and_flow_by_lock_status', 0, () => {
      const anchor = new EventEntity('anchor_ev', 82);
      const flow = new EventEntity('flow_ev', 82);
      anchor.lock_status = 1;
      flow.lock_status = 0;

      const anchorItem = anchor.toInterface();
      const flowItem = flow.toInterface();

      expect(anchorItem.type).assertEqual('ANCHOR');
      expect(flowItem.type).assertEqual('FLOW');
      expect(anchorItem.transportMode).assertEqual(anchor.travel_mode);
      expect(flowItem.transportMode).assertEqual(flow.travel_mode);
    });
  });
}
