import { describe, expect, it } from '@ohos/hypium';
import { AmapService, PoiSearchItem } from '../main/ets/infrastructure/services/AmapService';
import { AppConfig } from '../main/ets/common/utils/AppConfig';
import { HttpRequestHelper } from '../main/ets/infrastructure/adapters/HttpRequestHelper';

interface AmapPrivateDS {
  searchPoiByWebApi(
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number,
    nearbyOnly: boolean
  ): Promise<PoiSearchItem[]>;

  searchPoiWithWebFallback(
    keyword: string,
    centerLat: number,
    centerLng: number,
    limit: number
  ): Promise<PoiSearchItem[]>;
}

interface HttpResponseDS {
  responseCode: number;
  result: string;
}

class AmapWebHooksDS {
  private readonly originValidateAmapWebConfig: Object;
  private readonly originRequest: Object;

  constructor() {
    this.originValidateAmapWebConfig = Reflect.get(AppConfig as Object, 'validateAmapWebConfig') as Object;
    this.originRequest = Reflect.get(HttpRequestHelper as Object, 'request') as Object;
  }

  setValidateNoop(): void {
    Reflect.set(AppConfig as Object, 'validateAmapWebConfig', (): void => {
    });
  }

  setRequest(fn: (ownerTag: string, requestName: string, url: string, options: Object) => Promise<Object>): void {
    Reflect.set(HttpRequestHelper as Object, 'request', fn);
  }

  restore(): void {
    Reflect.set(AppConfig as Object, 'validateAmapWebConfig', this.originValidateAmapWebConfig);
    Reflect.set(HttpRequestHelper as Object, 'request', this.originRequest);
  }
}

function buildPoiPayloadDS(pois: string): string {
  return `{"status":"1","pois":[${pois}]}`;
}

export default function phase2BatchDSTest() {
  describe('phase2BatchDSTest', () => {
    it('normal: amap_search_poi_by_web_api_should_parse_nearby_result', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      let capturedUrl = '';
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        capturedUrl = url;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: buildPoiPayloadDS('{"name":"Museum","address":"Road","location":"121.470000,31.230000","distance":"88"}')
        };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiByWebApi('Museum', 31.23, 121.47, 2, true);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Museum');
      expect(items[0].distance ?? 0).assertEqual(88);
      expect(capturedUrl.includes('/around?')).assertTrue();
      expect(capturedUrl.includes('location=121.47,31.23')).assertTrue();
    });

    it('boundary: amap_search_poi_with_web_fallback_should_merge_nearby_and_nationwide', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      let aroundCalls = 0;
      let textCalls = 0;
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, url: string, _options: Object): Promise<Object> => {
        if (url.includes('/around?')) {
          aroundCalls += 1;
          const response: HttpResponseDS = {
            responseCode: 200,
            result: buildPoiPayloadDS('{"name":"Nearby","address":"A","location":"121.400000,31.200000","distance":"10"}')
          };
          return response as Object;
        }
        textCalls += 1;
        const response: HttpResponseDS = {
          responseCode: 200,
          result: buildPoiPayloadDS(
            '{"name":"Nearby","address":"A2","location":"121.400000,31.200000","distance":"99"},' +
              '{"name":"Nationwide","address":"B","location":"120.100000,30.100000","distance":"200"}'
          )
        };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiWithWebFallback('coffee', 31.2, 121.4, 3);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(aroundCalls).assertEqual(1);
      expect(textCalls).assertEqual(1);
      expect(items.length).assertEqual(2);
      expect(items[0].name).assertEqual('Nearby');
      expect(items[1].name).assertEqual('Nationwide');
    });

    it('invalid: amap_search_poi_by_web_api_should_return_empty_on_non_200', 0, async () => {
      // Arrange
      const api = AmapService as Object as AmapPrivateDS;
      const hooks = new AmapWebHooksDS();
      hooks.setValidateNoop();
      hooks.setRequest(async (_ownerTag: string, _requestName: string, _url: string, _options: Object): Promise<Object> => {
        const response: HttpResponseDS = { responseCode: 500, result: '{}' };
        return response as Object;
      });

      // Act
      let items: PoiSearchItem[] = [];
      try {
        items = await api.searchPoiByWebApi('bad', 31.23, 121.47, 2, false);
      } finally {
        hooks.restore();
      }

      // Assert
      expect(items.length).assertEqual(0);
    });
  });
}
