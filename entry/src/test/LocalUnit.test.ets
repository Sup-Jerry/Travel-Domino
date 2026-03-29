import { describe, it, expect } from '@ohos/hypium';
import { AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { PageDraftRecovery } from '../main/ets/common/utils/PageDraftRecovery';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    it('assert_contain', 0, () => {
      const source = 'abc';
      const target = 'b';
      expect(source).assertContain(target);
      expect(source).assertEqual('abc');
    });

    it('amap_parse_poi_should_filter_invalid_nodes', 0, () => {
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

    it('amap_merge_should_dedupe_and_keep_limit', 0, () => {
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

    it('amap_should_fallback_to_nationwide', 0, () => {
      expect(AmapService.shouldFallbackToNationwide(2, 5)).assertEqual(true);
      expect(AmapService.shouldFallbackToNationwide(5, 5)).assertEqual(false);
      expect(AmapService.shouldFallbackToNationwide(8, 5)).assertEqual(false);
    });

    it('draft_recover_should_use_coordinate_fallback_when_picked_address_empty', 0, () => {
      const tempState =
        '{"name":"东京塔","note":"","duration":60,"isAnchor":false,"fixedTime":"10:00","dayOffset":0,"isSchedule":true,"lat":35.65858,"lng":139.74543}';
      const pickedState = '{"lat":35.71006,"lng":139.8107,"address":""}';
      const recovered = PageDraftRecovery.recover(tempState, pickedState);
      expect(recovered.shouldRestore).assertEqual(true);
      expect(recovered.restored?.name).assertEqual('已选位置(35.71006, 139.81070)');
      expect(recovered.restored?.lat).assertEqual(35.71006);
      expect(recovered.restored?.lng).assertEqual(139.8107);
    });
  });
}
