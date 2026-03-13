import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { AmapService, PoiSearchItem } from '../main/ets/common/utils/AmapService';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('amapPoi_parse_should_filter_invalid_nodes', 0, () => {
      const payload =
        '{"status":"1","pois":[' +
        '{"name":"有效点A","address":"地址A","location":"116.397155,39.916344","distance":[]},' +
        '{"name":"无坐标","address":"地址B","location":""},' +
        '{"name":"","address":"地址C","location":"120.1000,30.2000"},' +
        '{"name":"非法坐标","address":"地址D","location":"abc,def"}]}';

      const parsed = AmapService.parsePoiResponse(payload);
      expect(parsed.length).assertEqual(1);
      expect(parsed[0].name).assertEqual('有效点A');
      expect(parsed[0].lat).assertEqual(39.916344);
      expect(parsed[0].lng).assertEqual(116.397155);
      expect(parsed[0].distance === undefined).assertEqual(true);
    });

    it('amapPoi_merge_should_dedupe_and_keep_limit', 0, () => {
      const nearby: PoiSearchItem[] = [
        new PoiSearchItem('东京塔', '港区', 35.6586, 139.7454, 320),
        new PoiSearchItem('浅草寺', '台东区', 35.7148, 139.7967, 860)
      ];
      const nationwide: PoiSearchItem[] = [
        new PoiSearchItem('东京塔', '港区', 35.6586, 139.7454, 5000),
        new PoiSearchItem('东京站', '千代田区', 35.6812, 139.7671, 2100)
      ];

      const merged = AmapService.mergePoiResults(nearby, nationwide, 3);
      expect(merged.length).assertEqual(3);
      expect(merged[0].name).assertEqual('东京塔');
      expect(merged[1].name).assertEqual('浅草寺');
      expect(merged[2].name).assertEqual('东京站');
    });

    it('amapPoi_shouldFallbackToNationwide', 0, () => {
      expect(AmapService.shouldFallbackToNationwide(2, 5)).assertEqual(true);
      expect(AmapService.shouldFallbackToNationwide(5, 5)).assertEqual(false);
      expect(AmapService.shouldFallbackToNationwide(8, 5)).assertEqual(false);
    });

  });
}
