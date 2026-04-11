// 文件路径: ets/pages/components/EventItemView.ets
import { TravelMode } from '../../../model/logic/TravelMode';
import { EventEntity } from '../../../model/entity/EventEntity';
import { DateUtil } from '../../../common/utils/DateUtil';
import { ConflictSelectionDialog } from '../dialogs/ConflictSelectionDialog';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { promptAction } from '@kit.ArkUI';
import { ThemeCenter } from '../../../common/utils/ThemeCenter';
import { DomainConstants } from '../../../common/constants/DomainConstants';

interface TimeRangeMeta {
  text: string;
  isEstimated: boolean;
}

export function getEventItemTravelModeIcon(mode: number): string {
  switch (mode) {
    case 0:
    case 4:
      return '🚶';
    case 1:
      return '🚴';
    case 2:
      return '🚗';
    case 3:
      return '🚇';
    default:
      return '🚗';
  }
}

export function formatEventItemCommuteTime(minutes: number): string {
  if (minutes < 60) {
    return `${minutes}m`;
  }
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

export function resolveEventItemConflictGapMinutes(gapMinutes: number, conflictMsg: string): number {
  if (gapMinutes > 0) {
    return gapMinutes;
  }
  const match = (conflictMsg || '').match(/(\d+)/);
  if (!match || match.length < 2) {
    return 0;
  }
  const parsed = Number.parseInt(match[1], 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

@Component
export struct EventItemView {
  @ObjectLink event: EventEntity;
  @Prop index: number;
  @Prop totalCount: number;
  @Prop showTravelIndicator: boolean = true;
  @Prop isCompanionMode: boolean = false;
  @Prop companionCurrentEventId: number = -1;
  @Prop showWeather: boolean = true;

  onMoveUp: () => void = () => {};
  onMoveDown: () => void = () => {};
  onMainContentClick: () => void = () => {}; // 点击中间：完整编辑
  onTimeClick: () => void = () => {};        // 点击左侧：时间编辑
  onCommuteChange: (minutes: number) => void = () => {};
  onEditClick: () => void = () => {};
  onTravelModeChange: (mode: number) => void = () => {};
  onManualTravelInput: (minutes: number) => void = () => {};
  onConflictAction: (item: EventEntity, strategy: 'delay' | 'compress' | 'advance' | 'smart', gapMinutes: number) => void = () => {};
  private conflictSelectionController: CustomDialogController | null = null;
  @State isReasonPopupShow: boolean = false;
  @State tempCommuteVal: string = '';
  @State isManualInputPopupShow: boolean = false;
  @StorageLink('PlanningTimeDisplayMode') planningTimeDisplayMode: number = 0;
  @StorageLink('CompanionTimeDisplayMode') companionTimeDisplayMode: number = 0;
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';

  private getPalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      hilog.warn(0x0000, 'EventItemView', `[TOAST_FAIL] reason=${JSON.stringify(error)}`);
    }
  }




  private getTravelModeIcon(mode: number): string {
    return getEventItemTravelModeIcon(mode);
  }

  private getDisplayTime(isStart: boolean): string {
    // 1. 计划时间 (Plan)
    const planStart = this.event.computed_time || this.event.fixed_start_time || '--:--';
    const planEnd = DateUtil.calculateEndTime(planStart, this.event.duration);

    // 2. 实际/预测时间 (Real/Forecast)
    let realStart = '';

    // 核心逻辑：第一站如果没有实际开始，显示"未记录"
    if (this.index === 0 && this.event.actual_start_time === 0) {
      realStart = '未记录';
    } else {
      // 其他情况：有实际显实际，无实际显预测
      if (this.event.actual_start_time > 0) {
        realStart = DateUtil.formatDate(new Date(this.event.actual_start_time), 'HH:mm');
      } else {
        realStart = this.event.forecast_start_time || '--:--';
      }
    }

    let realEnd = this.event.actual_end_time > 0
      ? DateUtil.formatDate(new Date(this.event.actual_end_time), 'HH:mm')
      : (this.event.forecast_end_time || '--:--');

    // 3. 根据模式返回
    if (this.getCurrentDisplayMode() === 0) { // 计划/实际主模式
      return isStart ? planStart : planEnd;
    } else if (this.getCurrentDisplayMode() === 1) { // 双显模式下第二主线仍返回主时段
      return isStart ? realStart : realEnd;
    }
    return ''; // 双显模式单独处理
  }

  private getCurrentDisplayMode(): number {
    return this.isCompanionMode ? this.companionTimeDisplayMode : this.planningTimeDisplayMode;
  }

  private switchDisplayMode(): void {
    if (this.isCompanionMode) {
      this.companionTimeDisplayMode = (this.companionTimeDisplayMode + 1) % 2;
    } else {
      this.planningTimeDisplayMode = (this.planningTimeDisplayMode + 1) % 2;
    }
  }

  private getThemeColor(name: string): string {
    const isDark = this.effectiveTheme === 'dark';
    // 如果 AI 明确指定了类型 (0:景点, 1:美食, 2:住宿, 3:交通)
    if (this.event.type === 1) return isDark ? '#FFB85C' : '#FF9800'; // 橙色 (吃)
    if (this.event.type === 2) return isDark ? '#B889E0' : '#7B1FA2'; // 紫色 (住)
    if (this.event.type === 3) return isDark ? '#9FB1C8' : '#9E9E9E'; // 灰色 (行)
    if (this.event.type === 0 && this.event.source === 1) return isDark ? '#57C6B7' : '#009688'; // 绿色 (AI生成的景点)

    // 正则兜底 (保持你原有的优秀逻辑)
    if (/饭|餐|吃|饮|饿|茶|咖/.test(name)) return isDark ? '#FFB85C' : '#FF9800';
    if (/车|路|交通|行|地铁|站|飞|铁|航/.test(name)) return isDark ? '#9FB1C8' : '#9E9E9E';
    if (/宿|住|房|酒店|寓/.test(name)) return isDark ? '#B889E0' : '#7B1FA2';
    if (/景|游|玩|园|山|水|馆|寺|塔/.test(name)) return isDark ? '#57C6B7' : '#009688';

    return this.getPalette().primary; // 默认蓝
  }

  private getStartTimeDisplay(): string {
    if (this.event.computed_time) return this.event.computed_time;
    if (this.event.fixed_start_time) return this.event.fixed_start_time;
    return `--:--`;
  }

  private getEndTimeDisplay(): string {
    const startStr = this.getStartTimeDisplay();
    return DateUtil.calculateEndTime(startStr, this.event.duration);
  }

  private formatCommuteTime(minutes: number): string {
    return formatEventItemCommuteTime(minutes);
  }
  // 修改点：内部辅助方法，用于统一处理时间戳转 HH:mm
  private formatTs(ts: number): string {
    if (ts <= 0) return '--:--';
    return DateUtil.formatDate(new Date(ts), 'HH:mm');
  }

  private getPlanRange(): string {
    const start = this.event.computed_time || this.event.fixed_start_time || '--:--';
    const end = DateUtil.calculateEndTime(start, this.event.duration);
    return `${start}-${end}`;
  }

  private getForecastRange(): string {
    if (this.event.dynamic_start_time > 0 && this.event.dynamic_end_time > 0) {
      return `${this.formatTs(this.event.dynamic_start_time)}-${this.formatTs(this.event.dynamic_end_time)}`;
    }
    return this.getPlanRange();
  }

  private getActualRangeMeta(): TimeRangeMeta {
    if (this.event.actual_start_time > 0 && this.event.actual_end_time > 0) {
      return {
        text: `${this.formatTs(this.event.actual_start_time)}-${this.formatTs(this.event.actual_end_time)}`,
        isEstimated: false
      };
    }

    if (this.event.actual_start_time > 0) {
      const estimatedEnd = this.event.actual_start_time + (this.event.duration * 60 * 1000);
      return {
        text: `${this.formatTs(this.event.actual_start_time)}-${this.formatTs(estimatedEnd)}`,
        isEstimated: true
      };
    }

    if (this.event.dynamic_start_time > 0 && this.event.dynamic_end_time > 0) {
      return {
        text: `${this.formatTs(this.event.dynamic_start_time)}-${this.formatTs(this.event.dynamic_end_time)}`,
        isEstimated: true
      };
    }

    return {
      text: this.getPlanRange(),
      isEstimated: true
    };
  }

  private getActualMainColor(): ResourceColor {
    return this.event.is_forecast_conflict ? this.getPalette().danger : this.getPalette().primary;
  }
  private getCompanionOpacity(): number {
    if (!this.isCompanionMode) {
      return 1;
    }

    if (this.event.id === this.companionCurrentEventId) {
      return 1;
    }

    if (this.event.completion_status === EventEntity.STATE_COMPLETED) {
      return 0.45;
    }

    if (this.event.completion_status === EventEntity.STATE_SKIPPED) {
      return 0.30;
    }

    if (this.event.actual_start_time > 0 && this.event.completion_status === EventEntity.STATE_PENDING) {
      return 1;
    }

    return 0.55;
  }

  private getCompanionStateLabel(): string {
    if (this.event.completion_status === EventEntity.STATE_COMPLETED) {
      return 'COMPLETED';
    }
    if (this.event.completion_status === EventEntity.STATE_SKIPPED) {
      return 'SKIPPED';
    }
    if (this.event.actual_start_time > 0) {
      return 'ACTIVE';
    }
    if (this.event.id === this.companionCurrentEventId) {
      return 'READY';
    }
    return 'FUTURE';
  }

  private getCompanionCardBackground(): ResourceColor {
    if (!this.isCompanionMode) {
      return this.getPalette().cardBg;
    }
    if (this.event.id === this.companionCurrentEventId) {
      return this.getPalette().cardBgSoft;
    }
    return this.getPalette().cardBg;
  }

  private getCompanionBorderColor(): ResourceColor {
    if (!this.isCompanionMode) {
      return this.getPalette().divider;
    }
    if (this.event.id === this.companionCurrentEventId) {
      return this.getPalette().primary;
    }
    if (this.event.completion_status === EventEntity.STATE_SKIPPED) {
      return this.getPalette().warning;
    }
    return this.getPalette().divider;
  }
  private getConflictGapMinutes(): number {
    return resolveEventItemConflictGapMinutes(this.event.gap_minutes, this.event.conflict_msg || '');
  }

  private openConflictSelectionDialog(): void {
    const gapMinutes = this.getConflictGapMinutes();

    hilog.info(
      0x0000,
      'EventItemView',
      `[CONFLICT_UI][open] id=${this.event.id}, name=${this.event.name}, lock=${this.event.lock_status}, gap=${gapMinutes}`
    );

    this.conflictSelectionController = new CustomDialogController({
      builder: ConflictSelectionDialog({
        gapMinutes: gapMinutes,
        onDelayY: () => {
          hilog.info(0x0000, 'EventItemView', `[CONFLICT_UI][choose_delay] id=${this.event.id}, gap=${gapMinutes}`);
          this.onConflictAction(this.event, 'delay', gapMinutes);
        },
        onCompressX: () => {
          hilog.info(0x0000, 'EventItemView', `[CONFLICT_UI][choose_compress] id=${this.event.id}, gap=${gapMinutes}`);
          this.onConflictAction(this.event, 'compress', gapMinutes);
        },
        onAdvanceAdjust: () => {
          hilog.info(0x0000, 'EventItemView', `[CONFLICT_UI][choose_advance] id=${this.event.id}, gap=${gapMinutes}`);
          this.onConflictAction(this.event, 'advance', gapMinutes);
        },
        onSmartAdjust: () => {
          hilog.info(0x0000, 'EventItemView', `[CONFLICT_UI][choose_smart] id=${this.event.id}, gap=${gapMinutes}`);
          this.onConflictAction(this.event, 'smart', gapMinutes);
        },
        onCancel: () => {
          hilog.info(0x0000, 'EventItemView', `[CONFLICT_UI][cancel] id=${this.event.id}`);
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false
    });

    this.conflictSelectionController.open();
  }
  @Builder TransportMenu() {
    Menu() {
      MenuItem({ content: '✍️ 手动输入' }).onClick(() => {
        this.tempCommuteVal = this.event.pre_travel_min > 0 ? `${this.event.pre_travel_min}` : '';
        this.isManualInputPopupShow = true;
      })
      // ✅ 修复数字映射灾难！
      MenuItem({ content: '🚗 驾车' }).onClick(() => {
        console.info('[UI层] 快捷菜单选了 2:驾车');
        this.onTravelModeChange(2);
      })
      MenuItem({ content: '🚶 步行' }).onClick(() => {
        console.info('[UI层] 快捷菜单选了 0:步行');
        this.onTravelModeChange(0);
      })
      MenuItem({ content: '🚲 骑行' }).onClick(() => {
        console.info('[UI层] 快捷菜单选了 1:骑行');
        this.onTravelModeChange(1);
      })
      MenuItem({ content: '🚌 公交' }).onClick(() => {
        console.info('[UI层] 快捷菜单选了 3:公交');
        this.onTravelModeChange(3);
      })
    }
  }

  // path: ets/pages/components/EventItemView.ets

  @Builder TravelIndicator() {
    Column() {
      // ---------------------------------------------------------
      // 状态 1: Loading 同步中
      // ---------------------------------------------------------
      if (this.event.pre_travel_min === DomainConstants.COMMUTE_LOADING) {
        Column() {
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
          Row({ space: 6 }) {
            LoadingProgress().width(16).height(16).color(this.getPalette().primary)
            Text('同步路况...').fontSize(10).fontColor(this.getPalette().textTertiary)
          }
          .backgroundColor(this.getPalette().cardBgSoft)
          .border({ width: 1, color: this.getPalette().border, radius: 12 })
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
        }
      }
      // ---------------------------------------------------------
      // 状态 2: 步行距离过长熔断 (-5) -> 绑定二次确认弹窗
      // ---------------------------------------------------------
      else if (this.event.pre_travel_min === DomainConstants.COMMUTE_WALK_TOO_FAR) {
        Column() {
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
          Row() {
            Text(`🚶 距离超5km, 建议切换`).fontSize(11).fontColor(this.getPalette().warning)
          }
          .width('60%').justifyContent(FlexAlign.Center).backgroundColor(this.getPalette().cardBgSoft)
          .border({ width: 1, color: this.getPalette().warning, radius: 16 }).padding({ top: 10, bottom: 10 })
          .onClick(() => {
            this.getUIContext().showAlertDialog({
              title: '步行距离过长',
              message: '当前两地直线距离超过 5 公里，步行可能耗时数小时。是否切换为更快捷的交通工具？',
              buttons: [
                {
                  value: '🚗 改为驾车',
                  fontColor: this.getPalette().primary,
                  action: () => { this.onTravelModeChange(2); }
                },
                {
                  value: '🚇 改为公交',
                  fontColor: this.getPalette().primary,
                  action: () => { this.onTravelModeChange(3); }
                },
                {
                  // ✅ 核心修复：发送强走信号(4)，触发高德计算！
                  value: '我偏要走 🚶',
                  fontColor: this.getPalette().danger,
                  action: () => { this.onTravelModeChange(4); }
                }
              ]
            })
          })
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
        }
      }
      // ---------------------------------------------------------
      // 状态 3: 暂无公交路线 (-3) -> 绑定降级弹窗
      // ---------------------------------------------------------
      else if (this.event.pre_travel_min === DomainConstants.COMMUTE_NO_TRANSIT) {
        Column() {
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
          Row() {
            Text(`🚌 暂无公交路线`).fontSize(11).fontColor(this.getPalette().danger)
          }
          .width('60%').justifyContent(FlexAlign.Center).backgroundColor(this.getPalette().cardBgSoft)
          .border({ width: 1, color: this.getPalette().danger, radius: 16 }).padding({ top: 10, bottom: 10 })
          .onClick(() => {
            this.getUIContext().showAlertDialog({
              title: '暂无公交',
              message: '未能查询到合适的公交/地铁路线，建议切换为打车或驾车。',
              primaryButton: {
                value: '取消',
                fontColor: this.getPalette().textSecondary,
                action: () => {}
              },
              secondaryButton: {
                value: '🚗 改为驾车',
                fontColor: this.getPalette().primary,
                action: () => { this.onTravelModeChange(2); }
              }
            })
          })
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
        }
      }
      // ---------------------------------------------------------
      // 状态 4: 正常算路成功或 999 兜底 -> 绑定快捷菜单
      // ---------------------------------------------------------
      else {
        Column() {
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
          // 将这里从 Row 改为 Column，以便把提示文字放在时间下面
          Column() {
            Row() {
              Text(this.getTravelModeIcon(this.event.travel_mode)).fontSize(12).margin({ right: 6 })
              Text(this.formatCommuteTime(this.event.pre_travel_min))
                .fontSize(11)
                .fontColor(this.event.pre_travel_min === DomainConstants.COMMUTE_FALLBACK_UNKNOWN ? this.getPalette().textTertiary : this.getPalette().primary)
                .fontWeight(FontWeight.Medium)
            }
            if (this.event.transit_warning) {
              Text('🚄 可能包含跨城列车')
                .fontSize(9)
                .fontColor(this.getPalette().warning)
                .margin({ top: 2 })
            }
          }
          .width('60%').justifyContent(FlexAlign.Center)
          .backgroundColor(this.getPalette().cardBgSoft)
          .border({ width: 1, color: this.getPalette().divider, radius: 16 }).padding({ top: 10, bottom: 10 })
          .bindMenu(this.TransportMenu())
          .bindPopup(this.isManualInputPopupShow, {
            builder: this.ManualInputPopupBuilder,
            placement: Placement.Bottom,
            mask: false,
            popupColor: this.getPalette().cardBg,
            onStateChange: (e) => {
              if (!e.isVisible) {
                this.isManualInputPopupShow = false;
              }
            }
          })
          .onClick(() => {
            if (this.event.pre_travel_min > 0 && this.event.pre_travel_min !== DomainConstants.COMMUTE_FALLBACK_UNKNOWN) {
              this.onTimeClick();
            }
          })
          Line().width(1).height(12).strokeDashArray([4, 4]).stroke(this.getPalette().divider)
        }
      }
    }
    .width('100%').alignItems(HorizontalAlign.Center).margin({ top: -4, bottom: -4 }).zIndex(1)
  }

  @Builder ReasonPopupBuilder() {
    Column() {
      Text('💡 AI 推荐理由')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getPalette().primary)
        .margin({ bottom: 8 })

      Text(this.event.ai_reasoning)
        .fontSize(14)
        .fontColor(this.getPalette().textPrimary)
        .lineHeight(20)
    }
    .padding(16)
    .backgroundColor(this.getPalette().cardBgSoft)
    .borderRadius(12)
    .width(260) // 限制宽度，防止太宽
  }

  @Builder ManualInputPopupBuilder() {
    Column() {
      Text('手动输入路程时间（分钟）')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.getPalette().textPrimary)
        .margin({ bottom: 10 })

      TextInput({ text: this.tempCommuteVal, placeholder: '请输入正整数分钟数' })
        .type(InputType.Number)
        .width(220)
        .height(40)
        .onChange((value: string) => {
          this.tempCommuteVal = value;
        })

      Row({ space: 10 }) {
        Button('取消')
          .fontSize(12)
          .backgroundColor(this.getPalette().cardBgSoft)
          .fontColor(this.getPalette().textSecondary)
          .onClick(() => {
            this.isManualInputPopupShow = false;
          })
        Button('保存')
          .fontSize(12)
          .backgroundColor(this.getPalette().primary)
          .fontColor('#FFF')
          .onClick(() => {
            const minutes = Number.parseInt(this.tempCommuteVal, 10);
            if (!Number.isFinite(minutes) || minutes <= 0) {
              this.safeShowToast('请输入正整数分钟数');
              return;
            }
            this.onManualTravelInput(minutes);
            this.isManualInputPopupShow = false;
          })
      }
      .margin({ top: 12 })
    }
    .padding(12)
    .backgroundColor(this.getPalette().cardBg)
    .borderRadius(12)
    .width(260)
  }

  build() {
    Column() {
      if (this.showTravelIndicator) {
        this.TravelIndicator()
      }


        Row() {
          // ✅ [区域 1] 左侧：时间显示 (点击切换模式)
          Column() {
            if (!this.isCompanionMode) {
              if (this.getCurrentDisplayMode() === 0) {
                Text('计划').fontSize(10).fontColor(this.getPalette().textTertiary).margin({ top: 2 })
                Text(this.getPlanRange()).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.getPalette().textPrimary)
              } else {
                Text(`计划 ${this.getPlanRange()}`).fontSize(10).fontColor(this.getPalette().textSecondary)
                Text(`实际 ${this.getActualRangeMeta().text}`)
                  .fontSize(11)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getActualMainColor())
                  .opacity(this.getActualRangeMeta().isEstimated ? 0.55 : 1.0)
                  .margin({ top: 2 })
                Text(`预测 ${this.getForecastRange()}`)
                  .fontSize(10)
                  .fontColor(this.getPalette().textTertiary)
                  .opacity(0.55)
                  .margin({ top: 1 })
              }
            } else {
              if (this.getCurrentDisplayMode() === 0) {
                Text(this.getActualRangeMeta().isEstimated ? '预计' : '实际')
                  .fontSize(10)
                  .fontColor(this.getPalette().textTertiary)
                  .margin({ top: 2 })
                Text(this.getActualRangeMeta().text)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getActualMainColor())
                  .opacity(this.getActualRangeMeta().isEstimated ? 0.55 : 1.0)
              } else {
                Text(`${this.getActualRangeMeta().isEstimated ? '预' : '实'} ${this.getActualRangeMeta().text}`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.getActualMainColor())
                  .opacity(this.getActualRangeMeta().isEstimated ? 0.55 : 1.0)
                Text(`计划 ${this.getPlanRange()}`)
                  .fontSize(10)
                  .fontColor(this.getPalette().textTertiary)
                  .margin({ top: 2 })
              }
            }
          }
          .width(85).alignItems(HorizontalAlign.End).margin({ right: 12 }) // 修改点：宽度增至 85 以容纳区间文字
          .onClick(() => {
            this.switchDisplayMode();
          })
        // ✅ [区域 2] 中间：内容详情 (点击进入完整编辑)
        // 包含竖线和文字内容
        Row() {
          // --- 竖线 ---
          Column()
            .width(4).height(50).backgroundColor(this.getThemeColor(this.event.name))
            .borderRadius(2).margin({ right: 12 })

          // --- 文字内容 ---
          Column() {
            Row() {
              Text(this.event.name)
                .fontSize(16).fontWeight(FontWeight.Medium).maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .flexShrink(1) // 修改点：名称过长时自动收缩，为后面的 Emoji 留出空间

              Row() {
                if (this.event.priority === 1) {
                  Text('🚩')
                    .fontSize(12).backgroundColor(this.getPalette().danger).padding({ left: 4, right: 4, top: 2, bottom: 2 }).borderRadius(4).margin({ left: 9 })
                }
                if (this.event.lock_status === 1) {
                  Text('🔒')
                    .fontSize(12).backgroundColor(this.getPalette().warning).padding({ left: 4, right: 4, top: 2, bottom: 2 }).borderRadius(4).margin({ left: 9 })
                }
                if (this.event.source === 1) {
                  Text('✨')
                    .fontSize(10).backgroundColor(this.getPalette().primary).padding({ left: 4, right: 4, top: 2, bottom: 2 }).borderRadius(4).margin({ left: 9 })
                }
              }.flexShrink(0) // 确保图标不被长名称挤压
            }
            .width('100%')
            .alignItems(VerticalAlign.Center) // 确保标签和文字垂直居中


            Row() {
              if (this.event.source === 1) {
                Column() {
                  if (this.event.ai_reasoning) {
                    Text(this.event.ai_reasoning)
                      .fontSize(11)
                      .fontColor(this.getPalette().primary)
                      .backgroundColor(this.getPalette().cardBgSoft)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ bottom: 4 })
                      .onClick(() => {
                        this.isReasonPopupShow = !this.isReasonPopupShow;
                      })
                      .bindPopup(this.isReasonPopupShow, {
                        builder: this.ReasonPopupBuilder,
                        placement: Placement.BottomLeft, // 气泡显示在左下
                        mask: false, // 非模态，点击空白处自动关闭
                        popupColor: this.getPalette().cardBgSoft, // 气泡背景色
                        onStateChange: (e) => {
                          if (!e.isVisible) {
                            this.isReasonPopupShow = false;
                          }
                        }
                      })
                  }
                  Row() {
                    Text('⚠️ 时长/路程仅供参考，请核实')
                      .fontSize(10)
                      .fontColor(this.getPalette().danger)
                  }
                }
                .alignItems(HorizontalAlign.Start)
              }
              else {
                Row() {
                  // 1. 始终显示时长
                  Text(`游玩 ${this.event.duration} 分钟`)
                    .fontSize(12)
                    .fontColor(this.getPalette().textSecondary)
                    .flexShrink(0) // 核心：防止挤压，保证时长完整显示

                  // 2. 如果有备忘，追加显示
                  if (this.event.note) {
                    // 分隔符 (可选)
                    Text(' | ')
                      .fontSize(10)
                      .fontColor(this.getPalette().textTertiary)
                      .margin({ left: 6, right: 6 })

                    // 备忘内容
                    Text(this.event.note)
                      .fontSize(12)
                      .fontColor(this.getPalette().textSecondary) // 比时长稍微深一点，突出内容
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1) // 核心：让备忘占用剩余宽度
                  }
                }
                .alignItems(VerticalAlign.Center) // 垂直居中对齐
              }
            }
            .margin({ top: 6 })
            .width('100%') // 确保能撑开布局

            if (this.showWeather) {
              Row() {
                Text('🌤')
                  .fontSize(11)
                  .margin({ right: 4 })
                Text(
                  this.event.weather_text && this.event.weather_text.length > 0
                    ? `${this.event.weather_text}${this.event.weather_temperature > 0 ? ` ${this.event.weather_temperature}°C` : ''}`
                    : '天气未知'
                )
                  .fontSize(11)
                  .fontColor(this.event.weather_text ? this.getPalette().textSecondary : this.getPalette().textTertiary)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .margin({ top: 6 })
              .width('100%')
            }

            if (this.event.is_conflict) {
              Row() {
                Text(`⚠️ ${this.event.conflict_msg} (点击处理冲突)`)
                  .fontSize(11)
                  .fontColor(this.getPalette().danger)
                  .decoration({ type: TextDecorationType.Underline })
                  .onClick(() => {
                    this.openConflictSelectionDialog();
                  })
              }
              .margin({ top: 6 })
            }
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1) // 占满剩余空间
        .onClick(() => this.onMainContentClick()) // 绑定主内容点击事件


        // ✅ [区域 3] 最右侧：仅保留排序箭头
        Column() {
          if (!this.isCompanionMode) {
            if (this.index < this.totalCount - 1) {
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                Text("▼").fontSize(12).fontColor(this.getPalette().textSecondary)
              }
              .backgroundColor(Color.Transparent).width(36).height(24)
              .onClick(() => this.onMoveDown())
            }

            if (this.index > 0) {
              Button({ type: ButtonType.Circle, stateEffect: true }) {
                Text("▲").fontSize(12).fontColor(this.getPalette().textSecondary)
              }
              .backgroundColor(Color.Transparent).width(36).height(24)
              .onClick(() => this.onMoveUp())
            }
          }
        }
        .width(40).alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)
        // 这一列不需要整列点击事件，让Button自己响应即可
      }
      .width('100%')
      .padding({ top: 16, bottom: 16, left: 12, right: 4 })
      .backgroundColor(this.getCompanionCardBackground()).borderRadius(16)
      .border({ width: this.isCompanionMode ? 1 : 0, color: this.getCompanionBorderColor() })
      .opacity(this.getCompanionOpacity())
            .onAppear(() => {
        if (this.isCompanionMode) {
          const opacity = this.getCompanionOpacity();
          const state = this.getCompanionStateLabel();
          hilog.info(
            0x0000,
            'EventItemView',
            `[DUAL_MODE_ACCEPT][card_visual] id=${this.event.id}, name=${this.event.name}, state=${state}, opacity=${opacity}, status=${this.event.completion_status}, actualStart=${this.event.actual_start_time}`
          );
        }
      })
      .shadow({ radius: 10, color: '#0F000000', offsetY: 4 })
      .margin({ bottom: 0 })
    }
  }
}

















