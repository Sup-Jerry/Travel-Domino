// 文件路径: ets/pages/components/dialogs/AddItemDialog.ets
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { abilityAccessCtrl, bundleManager, common } from '@kit.AbilityKit';
import { MapsInitializer } from '@amap/amap_lbs_map3d';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { DateUtil } from '../../../common/utils/DateUtil';
import { TimelineDatePolicy } from '../../../domain/policy/TimelineDatePolicy';
import { AppConfig } from '../../../common/utils/AppConfig';

interface PickedLocationData {
  lat: number;
  lng: number;
  address: string;
}

interface GeneratedObjectLiteralInterface_1 {
  name: string;
  note: string;
  duration: number;
  isAnchor: boolean;
  fixedTime: string;
  dayOffset: number;
  isSchedule: boolean;
  lat: number;
  lng: number;
}

class MapPickerRouteParams {
  lat: number;
  lng: number;
  planId: number;
  centerSource: string;
  queryName: string;

  constructor(lat: number, lng: number, planId: number, centerSource: string, queryName: string) {
    this.lat = lat;
    this.lng = lng;
    this.planId = planId;
    this.centerSource = centerSource;
    this.queryName = queryName;
  }
}

@CustomDialog
export struct AddItemDialog {
  controller: CustomDialogController;
  onConfirm: (name: string, duration: number, isSchedule: boolean, fixedTime?: string, dayOffset?: number,
    preTravel?: number, isHardLock?: boolean, note?: string, isMustVisit?: boolean, lat?: number,
    lng?: number) => Promise<void> = async () => {
  };
  onDateChangedRecommendTime: (dayOffset: number, currentTime: string) => string = (_dayOffset: number, currentTime: string): string => currentTime;
  @StorageProp('defaultDuration') globalDefaultDuration: number = 60;
  @State showTip: boolean = false;
  // =================== 地图选点回传监听 ===================


  // ========================================================

  initName: string = '';
  initNote: string = '';
  initDuration: number = 0;
  initIsSchedule: boolean = false;
  initFixedTime: string = '';
  initSuggestedTime: string = '';
  initIsAnchor: boolean = false;
  initDayOffset: number = 0;
  initPreTravel: number = 0;
  initPriority: number = 0;
  storageScopePlanId: number = 0;
  planStartDate: number = 0;
  initLat: number = 0;
  initLng: number = 0;
  @State name: string = '';
  @State note: string = '';
  @State duration: number = 60;
  @State isSchedule: boolean = false;
  @State isAnchor: boolean = false;
  @State preTravel: number = 0;
  @State startTime: Date = new Date();
  @State endTime: Date = new Date();
  @State isMustVisit: boolean = false;
  @State latitude: number = 0;
  @State longitude: number = 0;
  @State isGeocoding: boolean = false; // 控制 loading 状态
  // 持久化存储用户的选择习惯 (0=暂存, 1=日程)
  @StorageLink('lastAddItemMode') mode: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      hilog.warn(0x0000, 'AddItemDialog', `[TOAST_FAIL] reason=${JSON.stringify(error)}`);
    }
  }

  aboutToAppear() {
    this.latitude = this.initLat; // ✅ 读入坐标
    this.longitude = this.initLng; // ✅ 读入坐标
    if (this.initName) {
      this.mode = this.initIsSchedule ? 1 : 0;
    }

    this.name = this.initName;
    this.note = this.initNote;
    this.isSchedule = this.initIsSchedule;
    this.isAnchor = this.initIsAnchor;
    this.preTravel = this.initPreTravel > 0 ? this.initPreTravel : 0;
    this.isMustVisit = (this.initPriority === 1);

    if (this.initDuration > 0) {
      this.duration = this.initDuration;
    } else {
      this.duration = this.globalDefaultDuration;
    }

    let targetDate = TimelineDatePolicy.dayOffsetToDate(this.planStartDate, this.initDayOffset);
    let timeStr = this.initFixedTime || this.initSuggestedTime || '08:00';
    const parts = timeStr.split(':');
    if (parts.length === 2) {
      targetDate.setHours(parseInt(parts[0]), parseInt(parts[1]), 0, 0);
    }

    this.startTime = targetDate;
    this.recalculateEndTime();
  }

  private calculateDuration() {
    const diff = this.endTime.getTime() - this.startTime.getTime();
    const minutes = Math.floor(diff / (1000 * 60));
    if (minutes > 0) {
      this.duration = minutes;
    }
  }

  private recalculateEndTime() {
    this.endTime = new Date(this.startTime.getTime() + this.duration * 60 * 1000);
  }

  private formatTime(date: Date): string {
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  private applyTimeString(target: Date, timeText: string): Date {
    const pure = DateUtil.extractPureTime(timeText);
    if (!pure || !DateUtil.isValidTimeString(pure)) {
      return target;
    }
    const parts = pure.split(':');
    if (parts.length !== 2) {
      return target;
    }
    const hour = Number.parseInt(parts[0], 10);
    const minute = Number.parseInt(parts[1], 10);
    if (!Number.isFinite(hour) || !Number.isFinite(minute)) {
      return target;
    }
    const next = new Date(target.getTime());
    next.setHours(hour, minute, 0, 0);
    return next;
  }

  private isValidCoordinate(lat: number, lng: number): boolean {
    return Number.isFinite(lat) &&
      Number.isFinite(lng) &&
      Math.abs(lat) <= 90 &&
      Math.abs(lng) <= 180 &&
      !(lat === 0 && lng === 0);
  }

  private scopedStorageKey(base: string): string {
    if (this.storageScopePlanId > 0) {
      return `${base}_${this.storageScopePlanId}`;
    }
    return base;
  }

  private canUseMapPicker(): boolean {
    return AppConfig.AMAP_SDK_API_KEY.trim().length > 0;
  }

  private isMapNativeRuntimeReady(): boolean {
    try {
      const version = (MapsInitializer.getVersion() ?? '').trim();
      if (version.length === 0) {
        hilog.error(0x0000, 'AddItemDialog', '[MAP_NATIVE_GUARD] getVersion empty');
        return false;
      }
      return true;
    } catch (error) {
      hilog.error(0x0000, 'AddItemDialog', `[MAP_NATIVE_GUARD] runtime unavailable, reason=${JSON.stringify(error)}`);
      return false;
    }
  }

  // 核心逻辑：检查并申请定位权限 (包含弹窗 A 和 弹窗 B)
  private async checkAndRequestPermission(): Promise<boolean> {
    let atManager = abilityAccessCtrl.createAtManager();
    let tokenID: number = 0;
    try {
      // 获取应用的 AppTokenId
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      tokenID = bundleInfo.appInfo.accessTokenId;

      // 检查是否已经授权
      let checkStatus = await atManager.checkAccessToken(tokenID, 'ohos.permission.LOCATION');
      if (checkStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
    } catch (error) {
      hilog.warn(0x0000, 'AddItemDialog', `[PERMISSION_CHECK_FAIL] reason=${JSON.stringify(error)}`);
      this.safeShowToast('权限检查失败，请稍后再试');
      return false;
    }

    // --- 弹窗 A: 应用级解释说明 (使用系统简单弹窗) ---
    return new Promise((resolve) => {
      this.getUIContext().showAlertDialog({
        title: '定位权限申请',
        message: '为了能够自动定位到您当前位置，方便您快速选点，我们需要申请定位权限。',
        primaryButton: {
          value: '取消',
          action: () => resolve(false)
        },
        secondaryButton: {
          value: '去授权',
          action: async () => {
            // --- 弹窗 B: 系统级官方授权窗 ---
            let context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            let results = await atManager.requestPermissionsFromUser(context, [
              'ohos.permission.LOCATION',
              'ohos.permission.APPROXIMATELY_LOCATION'
            ]);

            // 判断用户是否在系统窗点击了允许 (0 代表成功)
            if (results.authResults[0] === 0) {
              resolve(true);
            } else {
              this.safeShowToast('未获得定位权限，地图将无法自动定位');
              resolve(true); // 即使失败也让进地图，只是地图会停在默认位置
            }
          }
        },
        alignment: DialogAlignment.Center
      });
    });
  }

  build() {
    Column() {
      // --- 顶部切换开关 ---
      Row() {
        Button('放入暂存')
          .type(ButtonType.Normal)
          .backgroundColor(this.mode === 0 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.mode === 0 ? Color.White : this.getPalette().textSecondary)
          .borderRadius({ topLeft: 8, bottomLeft: 8 })
          .layoutWeight(1)
          .height(32)
          .onClick(() => {
            this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.mode = 0;
            })
          })

        Button('放入日程')
          .type(ButtonType.Normal)
          .backgroundColor(this.mode === 1 ? this.getPalette().primary : this.getPalette().cardBgSoft)
          .fontColor(this.mode === 1 ? Color.White : this.getPalette().textSecondary)
          .borderRadius({ topRight: 8, bottomRight: 8 })
          .layoutWeight(1)
          .height(32)
          .onClick(() => {
            this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.mode = 1;
            })
          })
      }
      .width('70%')
      .margin({ bottom: 20 })

      Text(this.initName ? '编辑地点' : '添加新地点')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 24, top: 8 })
        .alignSelf(ItemAlign.Center)

      // --- 名称输入框 (始终显示) ---
      Column() {
        Row({ space: 8 }) {
          TextInput({
            placeholder: '请输入地点名称 (例如: 东京塔)',
            text: this.name
          })
            .layoutWeight(1) // 占据剩余空间
            .maxLength(30)
            .height(48)
            .backgroundColor(this.getPalette().cardBgSoft)
            .fontColor(this.getPalette().textPrimary)
            .placeholderColor(this.getPalette().textTertiary)
            .onChange((value: string) => {
              // 1. 屏蔽 ArkUI 初始化幽灵触发
              if (this.name === value) {
                return;
              }

              // 更新名称状态
              this.name = value;

              // 2. 智能拦截：“后悔药”场景与“历史债务”场景的完美融合
              if (value === this.initName) {
                // 恢复最初的坐标。
                // 【精妙之处】：如果是老数据，它本身的 initLat 就是 0。
                // 这里恢复成 0 后，底部的保存逻辑依然会拦截并强制去高德查一次！
                this.latitude = this.initLat;
                this.longitude = this.initLng;
              } else {
                // 3. 只有发生真正的改变，才清空坐标，要求系统在保存时重新解析
                this.latitude = 0;
                this.longitude = 0;
              }
            })

          // 📍 方案 C 预留入口：地图选点
          Button('📍选点')
            .type(ButtonType.Normal)
            .borderRadius(8)
            .backgroundColor(this.getPalette().cardBgSoft)
            .fontColor(this.getPalette().primary)
            .height(48)
            .onClick(async() => {
              if (!this.canUseMapPicker()) {
                this.safeShowToast('地图能力未配置，可直接填写名称后保存');
                return;
              }
              if (!this.isMapNativeRuntimeReady()) {
                this.safeShowToast('地图组件未就绪，请先修复高德 native 依赖');
                return;
              }
              // 🛡️ 新增权限拦截
              const hasPermission = await this.checkAndRequestPermission();
              if (!hasPermission) return;

              let routeLat = this.latitude;
              let routeLng = this.longitude;
              let centerSource = 'current';

              if (this.isValidCoordinate(routeLat, routeLng)) {
                centerSource = 'existing';
              }

              // 1. 给当前的表单数据拍个“快照”存起来
              let tempState: GeneratedObjectLiteralInterface_1 = {
                name: this.name,
                note: this.note,
                duration: this.duration,
                isAnchor: this.isAnchor,
                fixedTime: this.formatTime(this.startTime),
                dayOffset: this.initDayOffset,
                isSchedule: this.mode === 1,
                lat: this.latitude,
                lng: this.longitude
              };
              AppStorage.setOrCreate(this.scopedStorageKey('tempDialogState'), JSON.stringify(tempState));

              // 2. 主动关闭弹窗，把舞台让给地图！
              this.controller.close();

              // 3. 跳转到地图页
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/MapPickerPage',
                params: new MapPickerRouteParams(routeLat, routeLng, this.storageScopePlanId, centerSource, '')
              });
            })
        }.width('100%').margin({ bottom: 6 })

        Row() {
          Text('🔥 设为必去景点')
            .fontSize(14)
            .fontColor(this.isMustVisit ? this.getPalette().danger : this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium)

          Blank()

          Toggle({ type: ToggleType.Switch, isOn: this.isMustVisit })
            .onChange((isOn) => {
              this.isMustVisit = isOn
            })
            .selectedColor(this.getPalette().danger)
            .height(24)
        }
        .width('100%')
        .margin({ bottom: 4, top: 4 })
        .padding({ left: 4, right: 4 })

        Text(`${this.name.length}/30`)
          .fontSize(12)
          .fontColor(this.name.length >= 30 ? this.getPalette().danger : this.getPalette().textTertiary)
          .width('100%')
          .textAlign(TextAlign.End)
      }
      .width('100%')


      // --- 核心时间交互区 (仅日程模式显示) ---
      Column() {
        // (A) 日期行
        Row() {
          Text('日期').fontSize(15).fontColor(this.getPalette().textSecondary)
          Blank()
          Text(DateUtil.formatMonthDay(this.startTime))
            .fontSize(16)
            .fontColor(this.getPalette().textPrimary)
            .fontWeight(FontWeight.Medium)
            .padding({
              top: 4,
              bottom: 4,
              left: 12,
              right: 12
            })
            .backgroundColor(this.getPalette().cardBgSoft)
            .border({ width: 1, color: this.getPalette().divider })
            .borderRadius(6)
            // 🔴 修复点2：点击事件绑定在 Text 上，增加点击热区
            .onClick(() => {
              const startRange = new Date(this.planStartDate || new Date());
              startRange.setFullYear(startRange.getFullYear() - 1);
              const endRange = new Date(this.planStartDate || new Date());
              endRange.setFullYear(endRange.getFullYear() + 1);

              this.getUIContext().showDatePickerDialog({
                start: startRange,
                end: endRange,
                selected: this.startTime,
                onAccept: (value: DatePickerResult) => {
                  const newDate = new Date(this.startTime.getTime());
                  newDate.setFullYear(value.year, value.month, value.day);
                  const offset = TimelineDatePolicy.timestampToDayOffset(this.planStartDate, newDate.getTime());
                  const currentTime = this.formatTime(this.startTime);
                  const recommended = this.onDateChangedRecommendTime(offset, currentTime);
                  this.startTime = this.applyTimeString(newDate, recommended);
                  this.recalculateEndTime();
                }
              })
            })
        }
        .width('100%')
        .padding({ top: 8, bottom: 8, left: 10, right: 10 })
        .backgroundColor(this.getPalette().cardBgSoft)
        .border({ width: 1, color: this.getPalette().divider })
        .borderRadius(10)
        .margin({ bottom: 16 })

        // (B) 开始/结束/时长
        Row() {
          // 开始时间 (加大点击区域)
          Column() {
            Text('开始').fontSize(12).fontColor(this.getPalette().textSecondary).margin({ bottom: 4 })
            Text(this.formatTime(this.startTime))
              .fontSize(24).fontColor(this.getPalette().textPrimary).fontWeight(FontWeight.Bold)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .onClick(() => { // 🔴 修复点3：点击事件移到 Column，更容易点中
            this.getUIContext().showTimePickerDialog({
              selected: this.startTime,
              useMilitaryTime: true,
              onAccept: (value: TimePickerResult) => {
                this.startTime.setHours(value.hour, value.minute);
                this.startTime = new Date(this.startTime);
                this.recalculateEndTime();
              }
            })
          })

          // 中间：时长
          Column() {
            Text('时长(分)').fontSize(12).fontColor(this.getPalette().textSecondary).margin({ bottom: 4 })
            TextInput({ text: this.duration.toString() })
              .type(InputType.Number)
              .fontSize(16)
              .fontColor(this.getPalette().textPrimary)
              .fontWeight(FontWeight.Bold)
              .textAlign(TextAlign.Center)
              .width(60)
              .height(36)
              .backgroundColor(Color.Transparent)
              .onChange((value) => {
                const val = parseInt(value);
                if (!isNaN(val) && val >= 0) {
                  this.duration = val;
                  this.recalculateEndTime();
                }
              })
            Row().width(40).height(2).backgroundColor(this.getPalette().divider)
          }
          .layoutWeight(1)

          // 结束时间 (加大点击区域)
          Column() {
            Text('结束').fontSize(12).fontColor(this.getPalette().textSecondary).margin({ bottom: 4 })
            Text(this.formatTime(this.endTime))
              .fontSize(24).fontColor(this.getPalette().textPrimary).fontWeight(FontWeight.Bold)
          }
          .alignItems(HorizontalAlign.End)
          .layoutWeight(1)
          .onClick(() => { // 🔴 修复点3：点击事件移到 Column
            this.getUIContext().showTimePickerDialog({
              selected: this.endTime,
              useMilitaryTime: true,
              onAccept: (value) => {
                this.endTime.setHours(value.hour, value.minute);
                this.endTime = new Date(this.endTime);
                this.calculateDuration();
              }
            })
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.getPalette().cardBg)
        .borderRadius(12)
        .margin({ bottom: 16 })



        Row() {
          Row() {
            Text('刚性锁定 (票务/预约)').fontSize(15).fontColor(this.isAnchor ? this.getPalette().textPrimary : this.getPalette().textSecondary)
            Text('!')
              .fontSize(10)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
              .width(16)
              .height(16)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.getPalette().textTertiary)
              .borderRadius(8)
              .margin({ left: 6 })
              .onClick(() => {
                this.showTip = true
              })
              .bindPopup(this.showTip, {
                message: '【刚性锁定】\n适用于不可更改时间的行程。\n开启后系统将不会自动调整此时间。',
                placement: Placement.Top,
                onStateChange: (e) => {
                  if (!e.isVisible) {
                    this.showTip = false
                  }
                }
              })
          }

          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.isAnchor })
            .onChange((isOn) => {
              this.isAnchor = isOn
            })
            .height(24)
        }
        .width('100%')
        .height(48)
      }
      .visibility(this.mode === 1 ? Visibility.Visible : Visibility.None)
      .opacity(this.mode === 1 ? 1 : 0)
      .animation({ duration: 300, curve: Curve.EaseInOut })

      // --- 底部按钮 ---
      Row() {
        Button('取消')
          .backgroundColor(this.getPalette().cardBgSoft)
          .fontColor(this.getPalette().textSecondary)
          .width('35%')
          .height(44)
          .onClick(() => {
            this.controller.close();
          })

        Blank()

        Button(this.isGeocoding ? '解析中...' : '保存') // ✅ 增加 loading 文案
          .backgroundColor(this.getPalette().primary)
          .fontColor(Color.White)
          .width('60%')
          .height(44)
          .enabled(!this.isGeocoding) // 解析时防重复点击
          .shadow({ radius: 8, color: '#40007DFF', offsetY: 4 })
          .onClick(async () => {
            if (this.name.length > 0) {
              // 允许无坐标创建：不再强制地理编码。
              const finalLat = this.isValidCoordinate(this.latitude, this.longitude) ? this.latitude : undefined;
              const finalLng = this.isValidCoordinate(this.latitude, this.longitude) ? this.longitude : undefined;

              const fixedTimeStr = this.formatTime(this.startTime);
              let finalDayOffset = 0;
              finalDayOffset = TimelineDatePolicy.timestampToDayOffset(this.planStartDate, this.startTime.getTime());
              hilog.info(
                0x0000,
                'AddItemDialog',
                `[DAY_SHIFT_FIX][dialog_confirm] name=${this.name}, mode=${this.mode}, fixed=${fixedTimeStr}, dayOffset=${finalDayOffset}, selectedTs=${this.startTime.getTime()}, planStart=${this.planStartDate}`
              );


              try {
                await this.onConfirm(
                  this.name, this.duration, this.mode === 1,
                  this.mode === 1 ? fixedTimeStr : undefined,
                  this.mode === 1 ? finalDayOffset : 0,
                  this.mode === 1 ? this.preTravel : 0,
                  this.mode === 1 ? this.isAnchor : false,
                  this.note, this.isMustVisit,
                  finalLat, finalLng
                );
                this.controller.close();
              } catch (error) {
                hilog.error(0x0000, 'AddItemDialog', `[DIALOG_SAVE_FAIL] reason=${JSON.stringify(error)}`);
                this.safeShowToast('保存失败，请重试');
              }
            } else {
              this.safeShowToast('地点名称不能为空');
            }
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .padding({
      top: 20,
      bottom: 24,
      left: 24,
      right: 24
    })
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(20)
    .width('95%')
  }
}









