import { DateUtil } from "../../../common/utils/DateUtil";
import { EventEntity } from "../../../model/entity/EventEntity";
import { TimelineViewModel } from "../../../viewmodel/TimelineViewModel";
import { promptAction } from '@kit.ArkUI'; // 新增导入

interface GeneratedTypeLiteralInterface_1 {
  timeRange: string;
  addStr: string;
}

@CustomDialog
export struct GapResolutionDialog {
  controller: CustomDialogController;
  @Link vm: TimelineViewModel;
  // 注意：不再使用 gapItem，统一使用 currentGap
  @State strategy: 'EQUAL' | 'SMART' = 'EQUAL';
  @State selectedIds: Set<number> = new Set();
  @State currentGap: EventEntity | null = null;
  @State gapList: EventEntity[] = [];
  @State candidates: EventEntity[] = [];

  private safeShowToast(message: string, duration?: number): void {
    try {
      if (typeof duration === 'number') {
        promptAction.openToast({ message: message, duration: duration });
      } else {
        promptAction.openToast({ message: message });
      }
    } catch (_error) {
    }
  }

  aboutToAppear() {
    this.refreshGaps();
  }

  refreshGaps() {
    this.gapList = this.vm.getSortedGaps();
    if (this.gapList.length === 1) {
      this.selectGap(this.gapList[0]);
    } else {
      this.currentGap = null;
    }
  }

  selectGap(item: EventEntity) {
    this.currentGap = item;
    // 候选列表只保留真实可分配地点；当前空闲点作为独立上下文卡片展示
    this.candidates = this.vm.getDistributionCandidates(item);
    this.selectedIds = new Set();
  }

  // ✅ 修复：使用 currentGap 进行预览计算
  getPreview(item: EventEntity): GeneratedTypeLiteralInterface_1 {
    const distributionMap = this.currentGap
      ? this.vm.calculateDistributionPreview(this.currentGap, this.candidates, this.selectedIds, this.strategy)
      : new Map<number, number>();
    const addMin = distributionMap.get(item.id) || 0;
    const startTime = item.computed_time.split(' ').pop() || '00:00';
    const oldEnd = DateUtil.calculateEndTime(startTime, item.duration);
    const newEnd = DateUtil.calculateEndTime(startTime, item.duration + addMin);

    return {
      timeRange: `${startTime}-${oldEnd} → ${newEnd}`,
      addStr: addMin > 0 ? `(+${addMin}m)` : ''
    };
  }

  private getTierColor(min: number): string {
    const trigger = this.vm.getIdleGapTriggerMinutes();
    if (min >= 150) return '#FFB800'; // 黄金重排：金色
    if (min >= 90) return '#007DFF';  // 体验升级：蓝色
    if (min >= trigger) return '#4CAF50';  // 效率补全：绿色
    return ''; // 阈值以下不显示
  }

  // 获取对应阶梯的文案
  private getTierLabel(min: number): string {
    const trigger = this.vm.getIdleGapTriggerMinutes();
    if (min >= 150) return '黄金重排';
    if (min >= 90) return '体验升级';
    if (min >= trigger) return '效率补全';
    return '';
  }

  private hasPositiveAllocation(distributionMap: Map<number, number>): boolean {
    const values = Array.from(distributionMap.values());
    for (let i = 0; i < values.length; i++) {
      if (values[i] > 0) {
        return true;
      }
    }
    return false;
  }

  private getAllocatableCandidates(): EventEntity[] {
    if (!this.currentGap) {
      return [];
    }
    return this.candidates.filter(item => this.vm.getSafetyCap(item, this.currentGap!) > 0);
  }

  private isCandidateAllocatable(item: EventEntity): boolean {
    if (!this.currentGap) {
      return false;
    }
    return this.vm.getSafetyCap(item, this.currentGap) > 0;
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) { // 引入 Stack 实现右上角关闭
      // 右上角关闭按钮 (方案 B)
      Text('✕')
        .fontSize(18)
        .fontColor('#CCCCCC')
        .padding(12)
        .onClick(() => this.controller.close())
        .zIndex(2)

      Column() {
        // --- 模式 1：空闲时间选择列表 ---
        if (this.currentGap === null) {
          // 顶部引导语 (已压缩间距与字号)
          Column() {
            Text('💡 智能建议')
              .fontSize(12) // 缩小字号
              .fontColor($r('app.color.text_secondary'))
              .fontWeight(FontWeight.Medium)
            Text(`今日行程尚有 ${this.gapList.length} 处优化空间`)
              .fontSize(16) // 缩小字号
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 2, bottom: 12 }) // 大幅压缩间距
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          List({ space: 16 }) {
            ForEach(this.gapList, (item: EventEntity) => {
              ListItem() {
                Column() {
                  // 1. 卡片头部：标签与时长
                  Row() {
                    // 仅在 >= 触发阈值时显示标签
                    if (item.gap_minutes >= this.vm.getIdleGapTriggerMinutes()) {
                      Text(this.getTierLabel(item.gap_minutes))
                        .fontSize(10)
                        .fontColor(Color.White)
                        .backgroundColor(this.getTierColor(item.gap_minutes))
                        .padding({
                          left: 6,
                          right: 6,
                          top: 2,
                          bottom: 2
                        })
                        .borderRadius(4)
                    }

                    Blank()

                    Text(`${item.gap_minutes}`)
                      .fontSize(22)
                      .fontWeight(FontWeight.Bolder)
                      .fontColor($r('app.color.text_secondary'))
                    Text(' min')
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .margin({ bottom: 2 })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Bottom)

                  // 2. 卡片中部：描述文案
                  Text(`这段空闲出现在「${item.name}」之前。`)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 8, bottom: 16 })
                    .width('100%')

                  // 3. 卡片底部：操作按钮
                  Button('立即处理', { type: ButtonType.Capsule })
                    .width('100%')
                    .height(36)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .backgroundColor('#F0F7FF')
                    .fontColor($r('app.color.text_secondary'))
                    .onClick(() => this.selectGap(item))
                }
                .padding(16)
                .backgroundColor($r('app.color.card_bg'))
                .borderRadius(16)
                // ✅ 方案 B：边框颜色联动，且仅在 >= 触发阈值时显示边框
                .border({
                  width: item.gap_minutes >= this.vm.getIdleGapTriggerMinutes() ? 1.5 : 0,
                  color: this.getTierColor(item.gap_minutes)
                })
                .shadow({ radius: 12, color: '#0F000000', offsetY: 6 })
              }
            })
          }
          .layoutWeight(1) // 自动填充剩余高度，取代固定百分比
          .edgeEffect(EdgeEffect.Spring)
          .padding({ right: 12 })
          .scrollBarWidth(4)      // 👈 调细滚动条（默认通常较宽）
          .scrollBarColor('#D8D8D8') // 👈 调淡颜色，使其若隐若现


        } else {
          // --- 模式 2：分配详情视图 ---


          if (this.gapList.length > 1) {
            Row() {
              Row() {
                Text('←')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .fontWeight(FontWeight.Bold)
                Text(' 返回列表')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
              }
              .backgroundColor('#F0F7FF') // 增加浅蓝色背景
              .padding({
                left: 12,
                right: 12,
                top: 6,
                bottom: 6
              })
              .borderRadius(16)
              .onClick(() => {
                this.currentGap = null;
                this.refreshGaps();
              })
            }
            .width('100%')
            .margin({ bottom: 12 })
          }

          // ✅ 修改点：语义翻转
          Text(`分配空闲时间 (${this.currentGap?.name} 之前: ${this.currentGap?.gap_minutes || 0} min)`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 16 })

          Column() {

            // 策略切换器
            Row() {
              Text('均分模式')
                .fontSize(14)
                .fontColor(this.strategy === 'EQUAL' ? Color.White : '#666')
                .backgroundColor(this.strategy === 'EQUAL' ? '#007DFF' : Color.Transparent)
                .borderRadius(16)
                .padding({
                  top: 6,
                  bottom: 6,
                  left: 16,
                  right: 16
                })
                .onClick(() => this.strategy = 'EQUAL')

              Text('智能优化')
                .fontSize(14)
                .fontColor(this.strategy === 'SMART' ? Color.White : '#666')
                .backgroundColor(this.strategy === 'SMART' ? '#007DFF' : Color.Transparent)
                .borderRadius(16)
                .padding({
                  top: 6,
                  bottom: 6,
                  left: 16,
                  right: 16
                })
                .margin({ left: 8 })
                .onClick(() => this.strategy = 'SMART')
            }
            .backgroundColor($r('app.color.card_bg'))
            .borderRadius(20)
            .padding(4)
            .margin({ bottom: 16 })

            // 全选控制
            Row() {
              Checkbox()
              // 只针对真正可分配的地点执行全选
                .select(this.getAllocatableCandidates().length > 0 && this.selectedIds.size === this.getAllocatableCandidates().length)
                .onChange((isCheck: boolean) => {
                  if (isCheck) {
                    this.getAllocatableCandidates().forEach(c => this.selectedIds.add(c.id));
                  } else {
                    this.selectedIds.clear();
                  }
                  this.selectedIds = new Set(this.selectedIds);
                })
              Text(`全选可分配地点 (${this.selectedIds.size}/${this.getAllocatableCandidates().length})`)
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 8 })
            }
            .width('100%')
            .padding({ bottom: 8 })

            if (this.currentGap && this.getAllocatableCandidates().length === 0) {
              Text('当前候选地点均不可延长，已自动禁用勾选')
                .fontSize(12)
                .fontColor('#FF4D4F')
                .width('100%')
                .margin({ bottom: 12 })
            }

            // 当前空闲点作为固定上下文卡片展示；候选列表仅保留真实可分配地点
            Column() {
              if (this.currentGap) {
                Column() {
                  Row() {
                    Text('空闲来源')
                      .fontSize(11)
                      .fontColor('#8A2BE2')
                      .backgroundColor('#F6EDFF')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)

                    Blank()

                    Text(`${this.currentGap.gap_minutes} min`)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#8A2BE2')
                  }
                  .width('100%')

                  Text(`当前空闲出现在「${this.currentGap.name}」开始前`)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_secondary'))
                    .width('100%')
                    .margin({ top: 10 })

                  if (this.currentGap.computed_time) {
                    Text(`锚点时间：${this.currentGap.computed_time}`)
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .width('100%')
                      .margin({ top: 4 })
                  }
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#FAF7FF')
                .borderRadius(12)
                .margin({ bottom: 12 })
              }

              if (this.candidates.length === 0) {
                Column() {
                  Text('当前空闲前暂无可分配地点')
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                  Text('请返回选择其他空闲段，或直接保留这段空闲时间')
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                    .margin({ top: 6 })
                }
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .layoutWeight(1)
                .width('100%')
              } else {
                List({ space: 8 }) {
                  ForEach(this.candidates, (item: EventEntity) => {
                    ListItem() {
                      Row() {
                        Checkbox()
                          .select(this.selectedIds.has(item.id))
                          .enabled(this.isCandidateAllocatable(item))
                          .onChange((val: boolean) => {
                            if (!this.isCandidateAllocatable(item)) {
                              return;
                            }
                            if (val) {
                              this.selectedIds.add(item.id);
                            } else {
                              this.selectedIds.delete(item.id);
                            }
                            this.selectedIds = new Set(this.selectedIds);
                          })
                          .margin({ right: 12 })

                        Column() {
                          Row() {
                            if (item.source === 1) {
                              Text('🪄')
                                .fontSize(14)
                                .margin({ right: 4 })
                            }

                            Text(item.name)
                              .fontSize(16)
                              .fontWeight(FontWeight.Medium)
                              .layoutWeight(1)

                            if (item.priority === 1) {
                              Text('必去')
                                .fontSize(10)
                                .fontColor(Color.White)
                                .backgroundColor('#FF4D4F')
                                .padding({ left: 4, right: 4 })
                                .borderRadius(4)
                                .margin({ left: 4 })
                            }

                            if (item.lock_status === 1) {
                              Text('刚性')
                                .fontSize(10)
                                .fontColor(Color.White)
                                .backgroundColor('#FF9800')
                                .padding({ left: 4, right: 4 })
                                .borderRadius(4)
                                .margin({ left: 4 })
                            }
                          }
                          .width('100%')

                          Text(this.getPreview(item).timeRange + ' ' + this.getPreview(item).addStr)
                            .fontSize(13)
                            .fontColor(!this.isCandidateAllocatable(item) ? '#FF4D4F' : '#999')
                            .margin({ top: 4 })

                          if (!this.isCandidateAllocatable(item)) {
                            Text('后续行程紧凑，无法延长时间')
                              .fontSize(11)
                              .fontColor('#FF4D4F')
                              .margin({ top: 2 })
                          }
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)
                        .opacity(!this.isCandidateAllocatable(item) ? 0.5 : 1.0)
                      }
                      .width('100%')
                      .padding(12)
                    }
                  })
                }
                .width('100%')
                .layoutWeight(1)
                .edgeEffect(EdgeEffect.Spring)
              }
            }
            .border({ width: 1.5, color: '#8A2BE2', radius: 12 })
            .padding(12)
            .layoutWeight(1)
            .clip(true)
          }
          .layoutWeight(1) // 核心：让中间这块区域吃掉所有可用空间
          .margin({ bottom: 16 })

          // ✅ 修改点：从 G.ets 移植的冲突风险预警块
          if (this.currentGap && this.vm.checkDistributionRisk(
            this.currentGap,
            this.vm.calculateDistributionPreview(this.currentGap, this.candidates, this.selectedIds, this.strategy)
          )) {
            Row() {
              Text('⚠️').fontSize(14)
              Text('警告：分配过多将导致路径中的刚性地点冲突')
                .fontSize(12)
                .fontColor('#FF4D4F')
                .margin({ left: 4 })
            }
            .backgroundColor('#FFF2F0')
            .padding(8)
            .borderRadius(8)
            .margin({ bottom: 16 })
            .width('100%')
          }

          // 操作按钮
          Row() {
            Button('取消', { type: ButtonType.Capsule })
              .backgroundColor('#F2F4F7')
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => this.controller.close())
              .width('40%')

            Button('确认修改', { type: ButtonType.Capsule })
              .backgroundColor($r('app.color.card_bg'))
              .onClick(async () => {
                if (!this.currentGap) {
                  return;
                }

                if (this.selectedIds.size === 0) {
                  this.safeShowToast('请先选择要分配时间的地点', 2000);
                  return;
                }

                const map = this.vm.calculateDistributionPreview(
                  this.currentGap,
                  this.candidates,
                  this.selectedIds,
                  this.strategy
                );

                if (!this.hasPositiveAllocation(map)) {
                  this.safeShowToast('所选地点后续行程过紧，当前无法分配时间', 2200);
                  return;
                }

                await this.vm.applyDistribution(map);
                this.safeShowToast('时间分配成功', 2000);

                this.refreshGaps();
                if (this.gapList.length === 0) {
                  this.controller.close();
                }
              })
              .width('45%')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
      }
      .width('100%')
    }
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(24)
    .padding(16)
    .width('90%')
    .constraintSize({ maxHeight: '80%' })
  }
}










