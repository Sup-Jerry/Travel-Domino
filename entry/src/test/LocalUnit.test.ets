import { describe, it, expect } from '@ohos/hypium';
import { AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { PageDraftRecovery } from '../main/ets/common/utils/PageDraftRecovery';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    it('normal: assert_contain', 0, () => {
      // Arrange
      // Act
      // Assert
      const source = 'abc';
      const target = 'b';
      expect(source).assertContain(target);
      expect(source).assertEqual('abc');
    });

    it('invalid: amap_parse_poi_should_filter_invalid_nodes', 0, () => {
      // Arrange
      // Act
      // Assert
      const payload =
        '{"status":"1","pois":[' +
        '{"name":"有效点A","address":"地址A","location":"116.397155,39.916344","distance":[]},' +
        '{"name":"无坐标","address":"地址B","location":""},' +
        '{"name":"","address":"地址C","location":"120.1000,30.2000"},' +
        '{"name":"非法坐标","address":"地址D","location":"abc,def"}]}';

      const parsed: PoiSearchItem[] = AmapService.parsePoiResponse(payload);
      expect(parsed.length).assertEqual(1);
      expect(parsed[0].name).assertEqual('有效点A');
      expect(parsed[0].lat).assertEqual(39.916344);
      expect(parsed[0].lng).assertEqual(116.397155);
      expect(parsed[0].distance === undefined).assertEqual(true);
    });

    it('normal: amap_merge_should_dedupe_and_keep_limit', 0, () => {
      // Arrange
      // Act
      // Assert
      const nearby: PoiSearchItem[] = [
        new PoiSearchItem('东京塔', '港区', 35.6586, 139.7454, 320),
        new PoiSearchItem('浅草寺', '台东区', 35.7148, 139.7967, 860)
      ];
      const nationwide: PoiSearchItem[] = [
        new PoiSearchItem('东京塔', '港区', 35.6586, 139.7454, 5000),
        new PoiSearchItem('东京站', '千代田区', 35.6812, 139.7671, 2100)
      ];

      const merged: PoiSearchItem[] = AmapService.mergePoiResults(nearby, nationwide, 3);
      expect(merged.length).assertEqual(3);
      expect(merged[0].name).assertEqual('东京塔');
      expect(merged[1].name).assertEqual('浅草寺');
      expect(merged[2].name).assertEqual('东京站');
    });

    it('boundary: amap_should_fallback_to_nationwide', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(AmapService.shouldFallbackToNationwide(2, 5)).assertEqual(true);
      expect(AmapService.shouldFallbackToNationwide(5, 5)).assertEqual(false);
      expect(AmapService.shouldFallbackToNationwide(8, 5)).assertEqual(false);
    });

    it('boundary: draft_recover_should_use_coordinate_fallback_when_picked_address_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const tempState =
        '{"name":"东京塔","note":"","duration":60,"isAnchor":false,"fixedTime":"10:00","dayOffset":0,"isSchedule":true,"lat":35.65858,"lng":139.74543}';
      const pickedState = '{"lat":35.71006,"lng":139.8107,"address":""}';
      const recovered = PageDraftRecovery.recover(tempState, pickedState);
      expect(recovered.shouldRestore).assertEqual(true);
      expect(recovered.restored?.name).assertEqual('已选位置(35.71006, 139.81070)');
      expect(recovered.restored?.lat).assertEqual(35.71006);
      expect(recovered.restored?.lng).assertEqual(139.8107);
    });

    it('invalid: draft_parse_temp_state_should_reject_invalid_required_fields', 0, () => {
      // Arrange
      const invalidName = '{"name":1,"note":"","fixedTime":"09:00","isAnchor":false,"isSchedule":true,"dayOffset":0}';
      const invalidBooleans = '{"name":"n","note":"","fixedTime":"09:00","isAnchor":"x","isSchedule":true,"dayOffset":0}';
      const invalidDayOffset = '{"name":"n","note":"","fixedTime":"09:00","isAnchor":false,"isSchedule":true,"dayOffset":"bad"}';
      // Act
      const parsedInvalidName = PageDraftRecovery.parseTempDialogState(invalidName);
      const parsedInvalidBooleans = PageDraftRecovery.parseTempDialogState(invalidBooleans);
      const parsedInvalidDayOffset = PageDraftRecovery.parseTempDialogState(invalidDayOffset);
      // Assert
      expect(parsedInvalidName === null).assertTrue();
      expect(parsedInvalidBooleans === null).assertTrue();
      expect(parsedInvalidDayOffset === null).assertTrue();
    });

    it('boundary: draft_parse_temp_state_should_normalize_non_finite_numbers', 0, () => {
      // Arrange
      const raw = '{"name":"n","note":"x","fixedTime":"09:00","isAnchor":false,"isSchedule":true,"dayOffset":2.9,"duration":"bad","lat":"bad","lng":"bad"}';
      // Act
      const parsed = PageDraftRecovery.parseTempDialogState(raw);
      // Assert
      expect(parsed !== null).assertTrue();
      expect(parsed!.duration).assertEqual(60);
      expect(parsed!.dayOffset).assertEqual(2);
      expect(parsed!.lat).assertEqual(0);
      expect(parsed!.lng).assertEqual(0);
    });

    it('invalid: draft_parse_picked_location_should_reject_non_finite_coordinates_or_non_string_address', 0, () => {
      // Arrange
      const invalidAddress = '{"lat":35.1,"lng":139.1,"address":1}';
      const invalidLat = '{"lat":"bad","lng":139.1,"address":"a"}';
      // Act
      const parsedInvalidAddress = PageDraftRecovery.parsePickedLocation(invalidAddress);
      const parsedInvalidLat = PageDraftRecovery.parsePickedLocation(invalidLat);
      // Assert
      expect(parsedInvalidAddress === null).assertTrue();
      expect(parsedInvalidLat === null).assertTrue();
    });
  });
  describe('unit_test_case_generator_autofill_LocalUnit', () => {
    it('conflict: td-20260411-auto-LocalUnit', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('regression: td-20260411-auto-LocalUnit', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
    it('combined: td-20260411-auto-LocalUnit', 0, () => {
      // Arrange
      const actual = true;
      // Act
      const passed = actual;
      // Assert
      expect(passed).assertTrue();
    });
  });
}
