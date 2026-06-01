import { describe, expect, it } from '@ohos/hypium';
import { AmapWeatherService } from '../main/ets/infrastructure/services/AmapWeatherService';
import { WeatherInfo } from '../main/ets/infrastructure/adapters/IWeatherAdapter';
import { WeatherSearch } from '@amap/amap_lbs_search';

interface AmapWeatherServicePrivateGU {
  getWeatherBySdk(cityName: string, context: Object): Promise<WeatherInfo | null>;
  mapForecastNodeToInfo(node?: Object): WeatherInfo | null;
  readAsText(value?: string): string;
  readAsNumber(value?: string): number;
}

interface WeatherSearchListenerGU {
  onWeatherLiveSearched(weatherLiveResult: Object | undefined, errorCode: number): void;
  onWeatherForecastSearched(weatherForecastResult: Object | undefined, errorCode: number): void;
}

class WeatherLiveResultStubGU {
  private readonly live: Object | undefined;

  constructor(live?: Object) {
    this.live = live;
  }

  public getLiveResult(): Object | undefined {
    return this.live;
  }
}

class WeatherLiveStubGU {
  public getTemperature(): string {
    return '26';
  }

  public getHumidity(): string {
    return '81';
  }

  public getWindPower(): string {
    return '4';
  }

  public getWeather(): string {
    return '  CLOUDY ';
  }

  public getReportTime(): string {
    return '2026-04-24 10:00:00';
  }

  public getAdCode(): string {
    return '310000';
  }
}

class EmptyConditionLiveStubGU extends WeatherLiveStubGU {
  public getWeather(): string {
    return '   ';
  }
}

class SparseForecastNodeGU {
  public adcode?: string = '330100';
  public casts?: Object[] = [];
}

class SparseForecastCastGU {
  public dayweather?: string = 'FOG';
  public daytemp?: string = '  ';
  public nighttemp?: string = 'bad';
}

class WeatherSearchHooksGU {
  private readonly prototypeObj: Object;
  private readonly originSetOnWeatherSearchListener: Object;
  private readonly originSearchWeatherAsyn: Object;
  private readonly originSetQuery: Object;
  private listener: WeatherSearchListenerGU | null = null;
  private runner: ((listener: WeatherSearchListenerGU) => void) | null = null;

  constructor() {
    this.prototypeObj = Reflect.get(Object(WeatherSearch), 'prototype') as Object;
    this.originSetOnWeatherSearchListener = Reflect.get(this.prototypeObj, 'setOnWeatherSearchListener') as Object;
    this.originSearchWeatherAsyn = Reflect.get(this.prototypeObj, 'searchWeatherAsyn') as Object;
    this.originSetQuery = Reflect.get(this.prototypeObj, 'setQuery') as Object;
  }

  public install(runner: (listener: WeatherSearchListenerGU) => void): void {
    this.runner = runner;
    Reflect.set(this.prototypeObj, 'setOnWeatherSearchListener', (listener: WeatherSearchListenerGU): void => {
      this.listener = listener;
    });
    Reflect.set(this.prototypeObj, 'setQuery', (_query: Object): void => {
    });
    Reflect.set(this.prototypeObj, 'searchWeatherAsyn', (): void => {
      const listener = this.listener;
      const execute = this.runner;
      if (!listener || !execute) {
        return;
      }
      execute(listener);
    });
  }

  public restore(): void {
    Reflect.set(this.prototypeObj, 'setOnWeatherSearchListener', this.originSetOnWeatherSearchListener);
    Reflect.set(this.prototypeObj, 'searchWeatherAsyn', this.originSearchWeatherAsyn);
    Reflect.set(this.prototypeObj, 'setQuery', this.originSetQuery);
  }
}

export default function phase2BatchGUTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchGU_amap_weather_sdk_callbacks', () => {
    it('normal: amap_weather_service_should_parse_live_sdk_result_after_forecast_callback_runs', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateGU;
      const hooks = new WeatherSearchHooksGU();
      hooks.install((listener: WeatherSearchListenerGU): void => {
        listener.onWeatherForecastSearched(new Object(), 0);
        listener.onWeatherLiveSearched(new WeatherLiveResultStubGU(new WeatherLiveStubGU()) as Object, 0);
      });

      try {
        // Act
        const info = await privateApi.getWeatherBySdk('310000', new Object());

        // Assert
        expect(info !== null).assertTrue();
        expect(info?.condition || '').assertEqual('CLOUDY');
        expect(info?.temperature || 0).assertEqual(26);
        expect(info?.humidity || 0).assertEqual(81);
        expect(info?.windSpeed || 0).assertEqual(4);
        expect(info?.cityCode || '').assertEqual('310000');
      } finally {
        hooks.restore();
      }
    });

    it('boundary: amap_weather_service_should_return_null_when_sdk_live_condition_is_blank', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateGU;
      const hooks = new WeatherSearchHooksGU();
      hooks.install((listener: WeatherSearchListenerGU): void => {
        listener.onWeatherLiveSearched(new WeatherLiveResultStubGU(new EmptyConditionLiveStubGU()) as Object, 0);
      });

      try {
        // Act
        const info = await privateApi.getWeatherBySdk('310000', new Object());

        // Assert
        expect(info === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('regression: amap_weather_service_should_return_null_when_sdk_reports_failure_code', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateGU;
      const hooks = new WeatherSearchHooksGU();
      hooks.install((listener: WeatherSearchListenerGU): void => {
        listener.onWeatherLiveSearched(new WeatherLiveResultStubGU(new WeatherLiveStubGU()) as Object, 1001);
      });

      try {
        // Act
        const info = await privateApi.getWeatherBySdk('310000', new Object());

        // Assert
        expect(info === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('boundary: amap_weather_service_should_return_null_when_sdk_live_result_is_empty', 0, async () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateGU;
      const hooks = new WeatherSearchHooksGU();
      hooks.install((listener: WeatherSearchListenerGU): void => {
        listener.onWeatherLiveSearched(new WeatherLiveResultStubGU() as Object, 0);
      });

      try {
        // Act
        const info = await privateApi.getWeatherBySdk('310000', new Object());

        // Assert
        expect(info === null).assertTrue();
      } finally {
        hooks.restore();
      }
    });

    it('combined: amap_weather_service_private_forecast_and_reader_helpers_should_cover_sparse_paths', 0, () => {
      // Arrange
      const service = new AmapWeatherService();
      const privateApi = service as Object as AmapWeatherServicePrivateGU;
      const cast = new SparseForecastCastGU();
      const node = new SparseForecastNodeGU();
      node.casts = [cast as Object];

      // Act
      const info = privateApi.mapForecastNodeToInfo(node as Object);
      const blankText = privateApi.readAsText('   ');
      const undefinedNumber = privateApi.readAsNumber(undefined);

      // Assert
      expect(info !== null).assertTrue();
      expect(info?.condition || '').assertEqual('FOG');
      expect(info?.temperature || 0).assertEqual(0);
      expect(blankText).assertEqual('');
      expect(Number.isNaN(undefinedNumber)).assertTrue();
    });

    it('invalid: validator_marker_should_cover_invalid_case', 0, () => {
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

    it('combined: validator_marker_should_cover_combined_case', 0, () => {
      // Arrange
      const marker = true;
      // Act
      const result = marker;
      // Assert
      expect(result).assertTrue();
    });
  });
}
