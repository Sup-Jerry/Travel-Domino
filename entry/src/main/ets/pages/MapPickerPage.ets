// 文件路径: ets/pages/MapPickerPage.ets

import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
// 补全所有必需的 SDK 强类型类和接口
import {
  AMap,
  MapViewComponent,
  MapViewManager,
  CameraPosition,
  CameraUpdateFactory,
  LatLng,
  OnCameraChangeListener,
  MapView
} from '@amap/amap_lbs_map3d';
import { AmapService, PoiSearchItem } from '../infrastructure/services/AmapService';

import { MyLocationStyle  } from '@amap/amap_lbs_map3d';
import { ThemeCenter } from '../common/utils/ThemeCenter';

// ✅ 修复 1：定义明确的类，解决 "arkts-no-untyped-obj-literals" 报错
class PickedLocation {
  lat: number = 0;
  lng: number = 0;
  address: string = '';

  constructor(lat: number, lng: number, address: string) {
    this.lat = lat;
    this.lng = lng;
    this.address = address;
  }
}

class MapPickerRouteParams {
  lat: number = 0;
  lng: number = 0;
  planId: number = 0;
  centerSource: string = 'current';
  queryName: string = '';
}

@Entry
@Component
struct MapPickerPage {
  private map?: AMap;
  private searchDebounceTimer: number = -1;
  private addressDebounceTimer: number = -1;
  private addressRequestSeq: number = 0;
  private latestAppliedAddressSeq: number = 0;
  private uiContext?: common.UIAbilityContext;

  @State currentLat: number = 39.916344;
  @State currentLng: number = 116.397155;
  @State currentAddress: string = '正在获取位置...';
  @State isDragging: boolean = false;
  @State searchKeyword: string = '';
  @State searching: boolean = false;
  @State searchResults: PoiSearchItem[] = [];
  @State searchPanelVisible: boolean = false;
  @State searchToken: number = 0;
  @State hasPresetCoordinate: boolean = false;
  @State centerHint: string = '';
  @State storageScopePlanId: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (_error) {
    }
  }

  private isValidCoordinate(lat: number, lng: number): boolean {
    return Number.isFinite(lat) &&
      Number.isFinite(lng) &&
      Math.abs(lat) <= 90 &&
      Math.abs(lng) <= 180 &&
      !(lat === 0 && lng === 0);
  }

  // ✅ 修复 2：所有函数必须显式声明返回类型 (void)，解决 arkts-no-implicit-return-types
  aboutToAppear(): void {
    this.uiContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const params = this.getUIContext().getRouter().getParams() as MapPickerRouteParams;
    if (params) {
      const routeLat = params.lat ?? 0;
      const routeLng = params.lng ?? 0;
      this.storageScopePlanId = Number(params.planId ?? 0);
      if (this.isValidCoordinate(routeLat, routeLng)) {
        this.currentLat = routeLat;
        this.currentLng = routeLng;
        this.hasPresetCoordinate = true;
      }

      const centerSource = params.centerSource ?? 'current';
      const queryName = (params.queryName ?? '').trim();
      if (centerSource === 'geocode') {
        this.centerHint = queryName.length > 0
          ? `已按“${queryName}”定位到附近，可拖动微调`
          : '已按地点名定位到附近，可拖动微调';
      } else if (centerSource === 'existing') {
        this.centerHint = '已定位到已保存坐标，可拖动微调';
      } else {
        this.centerHint = '已定位到当前位置，可拖动选点';
      }
    }

    // ✅ 修复 3：通过全局单例捕获地图，解决 getMap 和 mapReadyCallback 不存在的报错
    MapViewManager.getInstance().registerMapViewCreatedCallback((mapview?: MapView) => {
      if (mapview) {
        hilog.info(0x0000, 'MapPickerPage', '[MAP_PICKER][map_created]');
        try {
          mapview.onCreate();
          hilog.info(0x0000, 'MapPickerPage', '[MAP_PICKER][map_on_create_called]');
        } catch (_error) {
          hilog.warn(0x0000, 'MapPickerPage', '[MAP_PICKER][map_on_create_failed]');
        }
        // 调用异步方法获取真实的 AMap 控制对象
        mapview.getMapAsync((map: AMap) => {
          this.map = map;
          hilog.info(0x0000, 'MapPickerPage', '[MAP_PICKER][map_ready]');
          this.onMapReady();
        });
      }
    });
  }

  aboutToDisappear(): void {
    if (this.searchDebounceTimer > 0) {
      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = -1;
    }
    if (this.addressDebounceTimer > 0) {
      clearTimeout(this.addressDebounceTimer);
      this.addressDebounceTimer = -1;
    }
    this.searchToken++;
    this.addressRequestSeq++;
  }

  private scheduleSearch(value: string): void {
    this.searchKeyword = value;
    if (this.searchDebounceTimer > 0) {
      clearTimeout(this.searchDebounceTimer);
    }

    const keyword = value.trim();
    if (keyword.length === 0) {
      this.searching = false;
      this.searchPanelVisible = false;
      this.searchResults = [];
      return;
    }

    this.searchDebounceTimer = setTimeout(() => {
      void this.runSearch(keyword);
    }, 280) as number;
  }

  private searchNow(): void {
    if (this.searchDebounceTimer > 0) {
      clearTimeout(this.searchDebounceTimer);
      this.searchDebounceTimer = -1;
    }

    const keyword = this.searchKeyword.trim();
    if (keyword.length === 0) {
      this.searching = false;
      this.searchPanelVisible = false;
      this.searchResults = [];
      return;
    }

    void this.runSearch(keyword);
  }

  private async runSearch(keyword: string): Promise<void> {
    const token = ++this.searchToken;
    this.searching = true;
    this.searchPanelVisible = true;

    try {
      const context = this.uiContext;
      const results = context
        ? await AmapService.searchPoi(context, keyword, this.currentLat, this.currentLng, 10)
        : [];
      if (token !== this.searchToken) {
        return;
      }
      this.searchResults = results;
    } catch (_) {
      if (token !== this.searchToken) {
        return;
      }
      this.searchResults = [];
    } finally {
      if (token === this.searchToken) {
        this.searching = false;
      }
    }
  }

  private formatDistance(distance?: number): string {
    if (distance === undefined) {
      return '';
    }
    if (distance >= 1000) {
      return `${(distance / 1000).toFixed(1)}km`;
    }
    return `${Math.floor(distance)}m`;
  }

  private focusPoi(item: PoiSearchItem): void {
    this.currentLat = item.lat;
    this.currentLng = item.lng;
    this.currentAddress = item.address && item.address.trim().length > 0 ? item.address : item.name;
    this.searchPanelVisible = false;
    this.searchResults = [];

    const latlng = new LatLng(item.lat, item.lng);
    this.map?.moveCamera(CameraUpdateFactory.newLatLngZoom(latlng, 16));
  }

  onMapReady(): void {
    if (!this.map) return;

    // 1. 开启定位蓝点功能
    this.map.setMyLocationEnabled(true);

    // 2. 实例化定位样式对象
    // ✅ 修复点：不能使用对象字面量 {}，必须通过方法调用来配置
    let style = new MyLocationStyle();
    // 新建模式: 1=定位并回中当前位置；编辑模式: 0=只显示蓝点，不强制回中
    style.myLocationType(this.hasPresetCoordinate ? 0 : 1);
      // 定位间隔
    style.showMyLocation(true);   // 是否显示蓝点

    // 应用样式
    this.map.setMyLocationStyle(style);

    // 3. 优先使用传入坐标，失败时回退到定位蓝点自动居中
    if (this.hasPresetCoordinate) {
      let latlng = new LatLng(this.currentLat, this.currentLng);
      this.map?.moveCamera(CameraUpdateFactory.newLatLngZoom(latlng, 16));
      this.scheduleFetchAddress(this.currentLat, this.currentLng);
    } else {
      this.currentAddress = '正在获取当前位置...';
    }

    // 4. 监听视角变动 (保持不变)
    this.map?.setOnCameraChangeListener(new OnCameraChangeListener(
      (position: CameraPosition) => { this.isDragging = true; },
      (position: CameraPosition) => {
        this.isDragging = false;
        if (position && position.target) {
          this.currentLat = position.target.latitude;
          this.currentLng = position.target.longitude;
          this.scheduleFetchAddress(this.currentLat, this.currentLng);
        }
      }
    ));
  }

  private scheduleFetchAddress(lat: number, lng: number): void {
    if (this.addressDebounceTimer > 0) {
      clearTimeout(this.addressDebounceTimer);
    }
    this.addressDebounceTimer = setTimeout(() => {
      this.addressDebounceTimer = -1;
      void this.fetchAddress(lat, lng);
    }, 300) as number;
  }

  async fetchAddress(lat: number, lng: number): Promise<void> {
    const seq = ++this.addressRequestSeq;
    this.currentAddress = '正在解析附近地名...';
    const address = await AmapService.getRegeo(lat, lng);
    if (seq < this.addressRequestSeq || seq < this.latestAppliedAddressSeq) {
      return;
    }
    this.latestAppliedAddressSeq = seq;
    if (address) {
      this.currentAddress = address;
    } else {
      this.currentAddress = '未知坐标点';
    }
  }

  confirmSelection(): void {
    if (this.currentLat === 0) {
      this.safeShowToast('请选择有效位置');
      return;
    }

    let finalAddress = (this.currentAddress === '未知坐标点' || this.currentAddress.includes('解析')) ? '' : this.currentAddress;

    // 实例化我们刚才定义的明确结构类
    const resultObj = new PickedLocation(this.currentLat, this.currentLng, finalAddress);

    // 转化为字符串传出
    const key = this.storageScopePlanId > 0 ? `pickedLocationStr_${this.storageScopePlanId}` : 'pickedLocationStr';
    AppStorage.setOrCreate(key, JSON.stringify(resultObj));
    this.getUIContext().getRouter().back();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {

      // ✅ 修复 6：移除不合法的 mapReadyCallback 属性，只保留名字
      MapViewComponent({
        mapViewName: "MapPicker"
      })
        .width('100%')
        .height('100%')

      Column() {
        Text('📍')
          .fontSize(48)
          .offset({ y: this.isDragging ? -20 : 0 })
          .animation({ duration: 250, curve: Curve.Friction })
      }
      .position({ x: '50%', y: '50%' })
      .translate({ x: '-50%', y: '-100%' })

      Row() {
        Button('< 返回')
          .type(ButtonType.Capsule)
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .fontColor(this.getThemePalette().textPrimary)
          .border({ width: 1, color: this.getThemePalette().border })
          .shadow({ radius: 8, color: this.effectiveTheme === 'dark' ? 'rgba(0,0,0,0.35)' : 'rgba(0,0,0,0.1)' })
          .onClick(() => this.getUIContext().getRouter().back())

        TextInput({ text: this.searchKeyword, placeholder: '搜索地点（例如：东京塔）' })
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(20)
          .fontSize(14)
          .fontColor(this.getThemePalette().textPrimary)
          .placeholderColor(this.getThemePalette().textTertiary)
          .padding({ left: 14, right: 14 })
          .margin({ left: 10, right: 6 })
          .onChange((value: string) => {
            this.scheduleSearch(value);
          })

        Button(this.searching ? '搜索中' : '搜索')
          .type(ButtonType.Capsule)
          .height(36)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .enabled(!this.searching)
          .onClick(() => {
            this.searchNow();
          })
      }
      .width('100%')
      .padding({ top: 50, left: 16, right: 16 })
      .position({ x: 0, y: 0 })

      if (this.searchPanelVisible) {
        Column() {
          if (this.searching) {
            Text('搜索中...')
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 16, bottom: 16 });
          } else if (this.searchKeyword.trim().length > 0 && this.searchResults.length === 0) {
            Text('未找到匹配地点')
              .fontSize(13)
              .fontColor(this.getThemePalette().textSecondary)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 16, bottom: 16 });
          } else {
            List({ space: 8 }) {
              ForEach(this.searchResults, (item: PoiSearchItem) => {
                ListItem() {
                  Row() {
                    Column({ space: 4 }) {
                      Text(item.name)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.getThemePalette().textPrimary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                      Text(item.address || `${item.lat.toFixed(5)}, ${item.lng.toFixed(5)}`)
                        .fontSize(12)
                        .fontColor(this.getThemePalette().textSecondary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis });
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start);

                    Text(this.formatDistance(item.distance))
                      .fontSize(12)
                      .fontColor(this.getThemePalette().textTertiary);
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                  .backgroundColor(this.getThemePalette().cardBg)
                  .borderRadius(10)
                  .onClick(() => {
                    this.focusPoi(item);
                  });
                };
              }, (item: PoiSearchItem) => `${item.name}-${item.lat.toFixed(6)}-${item.lng.toFixed(6)}`);
              ListItem().height(4);
            }
            .width('100%')
            .constraintSize({ maxHeight: 260 })
            .padding({ left: 8, right: 8, top: 8, bottom: 8 });
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .position({ x: 0, y: 98 })
        .backgroundColor(this.getThemePalette().cardBg)
        .border({ width: 1, color: this.getThemePalette().divider, radius: 14 })
        .borderRadius(14)
        .shadow({
          radius: 16,
          color: this.effectiveTheme === 'dark' ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.12)',
          offsetY: 4
        });
      }

      Column() {
        Text(this.currentAddress)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getThemePalette().textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 20 })
          .opacity(this.isDragging ? 0.3 : 1.0)
          .animation({ duration: 200 })

        if (this.centerHint.length > 0) {
          Text(this.centerHint)
            .fontSize(12)
            .fontColor(this.getThemePalette().textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 12 })
            .opacity(this.isDragging ? 0.3 : 1.0)
            .animation({ duration: 200 })
        }

        Button('确认选点')
          .width('100%')
          .height(48)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .fontSize(16)
          .shadow({
            radius: 8,
            color: this.effectiveTheme === 'dark' ? 'rgba(102,163,255,0.42)' : 'rgba(47,125,255,0.28)',
            offsetY: 4
          })
          .onClick(() => this.confirmSelection())
      }
      .width('100%')
      .backgroundColor(this.getThemePalette().cardBg)
      .borderRadius({ topLeft: 24, topRight: 24 })
      .padding({ left: 24, right: 24, top: 24, bottom: 40 })
      .shadow({ radius: 30, color: 'rgba(0,0,0,0.15)', offsetY: -5 })

    }
    .width('100%')
    .height('100%')
  }
}







