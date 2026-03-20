import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../common/utils/PreferenceManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { GlobalBottomNavBar } from './components/views/BottomNavBar';
import { common } from '@kit.AbilityKit';
import { ThemeCenter, ThemeMode } from '../common/utils/ThemeCenter';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { PlanStateMachine } from '../domain/statemachine/PlanStateMachine';
import { PlanTransitionEvent } from '../domain/statemachine/ExecutionContext';

const TAG = 'SettingsPage';

@Component
struct SettingSwitchItem {
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop loading: boolean = false;
  @Prop textPrimary: ResourceColor = '#222';
  @Prop textSecondary: ResourceColor = '#888';
  @Prop cardBg: ResourceColor = Color.White;
  @Link checked: boolean;

  onToggle: (value: boolean) => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Medium);

        Text(this.desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 6 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      if (this.loading) {
        Text('加载中...')
          .fontSize(12)
          .fontColor('#AAA');
      } else {
        Toggle({ type: ToggleType.Switch, isOn: this.checked })
          .onChange((value: boolean) => {
            this.checked = value;
            this.onToggle(value);
          });
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardBg)
    .borderRadius(12);
  }
}

@Component
struct SettingSelectItem {
  @Prop title: string = '';
  @Prop desc: string = '';
  @Prop valueText: string = '';
  @Prop textPrimary: ResourceColor = '#222';
  @Prop textSecondary: ResourceColor = '#888';
  @Prop cardBg: ResourceColor = Color.White;
  @Prop actionColor: ResourceColor = '#007DFF';

  onClickItem: () => void = () => {};

  build() {
    Row() {
      Column() {
        Text(this.title)
          .fontSize(16)
          .fontColor(this.textPrimary)
          .fontWeight(FontWeight.Medium);

        Text(this.desc)
          .fontSize(12)
          .fontColor(this.textSecondary)
          .margin({ top: 6 });
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1);

      Text(this.valueText)
        .fontSize(13)
        .fontColor(this.actionColor);

      Text('>')
        .fontSize(14)
        .fontColor(this.textSecondary)
        .margin({ left: 8 });
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.cardBg)
    .borderRadius(12)
    .onClick(() => {
      this.onClickItem();
    });
  }
}

@Entry
@Component
struct SettingsPage {
  @State enableAmapRouteApi: boolean = false;
  @State weatherFeatureEnabled: boolean = true;
  @State enableIdleGapDetection: boolean = true;
  @State idleGapTriggerMinutes: number = 45;
  @State idleGapTriggerInput: string = '45';
  @State showArchiveTip: boolean = true;
  @State showDeleteTip: boolean = true;
  @State minEventDuration: number = 30;
  @State minEventDurationInput: string = '30';
  @State loading: boolean = true;
  @State themeMode: ThemeMode = 'system';
  @State diagnosticsPlanIdInput: string = '';
  @State diagnosticsSummary: string = '未加载';
  @State diagnosticsLogs: string[] = [];
  @State diagnosticsExportPreview: string = '';
  @StorageLink('EffectiveTheme') effectiveTheme: string = 'light';
  private readonly planStateMachine: PlanStateMachine = PlanStateMachine.getInstance();

  private getThemePalette() {
    return ThemeCenter.getPalette(this.effectiveTheme);
  }

  private safeShowToast(message: string): void {
    try {
      promptAction.openToast({ message: message });
    } catch (error) {
      hilog.warn(0x0000, TAG, `[TOAST_FAIL] reason=${JSON.stringify(error)}`);
    }
  }

  private getThemeModeText(): string {
    if (this.themeMode === 'dark') {
      return '深色';
    }
    if (this.themeMode === 'light') {
      return '浅色';
    }
    return '跟随系统';
  }

  private showThemeModeDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '主题模式',
      message: '选择应用主题模式',
      buttons: [
        {
          value: '跟随系统',
          action: () => {
            void this.applyThemeMode('system');
          }
        },
        {
          value: '浅色',
          action: () => {
            void this.applyThemeMode('light');
          }
        },
        {
          value: '深色',
          action: () => {
            void this.applyThemeMode('dark');
          }
        }
      ],
      autoCancel: true,
      alignment: DialogAlignment.Center
    });
  }

  private async applyThemeMode(mode: ThemeMode): Promise<void> {
    const pref = PreferenceManager.getInstance();
    await pref.setThemeMode(mode);
    this.themeMode = mode;
    const context = this.getUIContext().getHostContext() as common.Context;
    const effective = ThemeCenter.applyThemeMode(context, mode);
    this.effectiveTheme = effective;
    this.safeShowToast(`主题已切换为${this.getThemeModeText()}`);
  }

  aboutToAppear(): void {
    this.loadSettingsSafely();
  }

  private async loadSettingsSafely(): Promise<void> {
    this.loading = true;
    try {
      await this.reloadSettingsState();
    } catch (error) {
      console.error(`SettingsPage load failed: ${JSON.stringify(error)}`);
      this.safeShowToast('设置加载失败，已使用默认值');
    } finally {
      this.loading = false;
    }
  }

  private async onAmapRouteApiChanged(value: boolean): Promise<void> {
    const oldValue = this.enableAmapRouteApi;
    this.enableAmapRouteApi = value;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setAmapRouteApiEnabled(value);

      this.enableAmapRouteApi = await pref.isAmapRouteApiEnabled();

      this.safeShowToast(this.enableAmapRouteApi ? '已开启高德路线 API' : '已关闭高德路线 API');
    } catch (error) {
      this.enableAmapRouteApi = oldValue;
      this.safeShowToast('高德路线 API 设置失败');
    }
  }

  private async onWeatherFeatureChanged(value: boolean): Promise<void> {
    const oldValue = this.weatherFeatureEnabled;
    this.weatherFeatureEnabled = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setWeatherFeatureEnabled(value);
      this.weatherFeatureEnabled = await pref.isWeatherFeatureEnabled();
      this.safeShowToast(this.weatherFeatureEnabled ? '已开启天气功能' : '已关闭天气功能');
    } catch (_error) {
      this.weatherFeatureEnabled = oldValue;
      this.safeShowToast('天气功能开关保存失败');
    }
  }

  private async onShowArchiveTipChanged(value: boolean): Promise<void> {
    const oldValue = this.showArchiveTip;
    this.showArchiveTip = value;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setValue(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, !value);

      const hideArchiveTip = await pref.getValue(
        PreferenceManager.KEY_HIDE_ARCHIVE_TIP,
        false
      );
      this.showArchiveTip = hideArchiveTip !== true;

      this.safeShowToast(this.showArchiveTip ? '已开启归档提示弹窗' : '已关闭归档提示弹窗');
    } catch (error) {
      this.showArchiveTip = oldValue;
      this.safeShowToast('归档提示弹窗设置失败');
    }
  }

  private async onShowDeleteTipChanged(value: boolean): Promise<void> {
    const oldValue = this.showDeleteTip;
    this.showDeleteTip = value;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setValue(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, !value);

      const hideDeleteTip = await pref.getValue(
        PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP,
        false
      );
      this.showDeleteTip = hideDeleteTip !== true;

      this.safeShowToast(this.showDeleteTip ? '已开启删除提示弹窗' : '已关闭删除提示弹窗');
    } catch (error) {
      this.showDeleteTip = oldValue;
      this.safeShowToast('删除提示弹窗设置失败');
    }
  }

  private async saveMinEventDuration(): Promise<void> {
    const oldValue = this.minEventDuration;
    const rawInput = parseInt(this.minEventDurationInput, 10);
    const nextValue = PreferenceManager.normalizeMinEventDuration(isNaN(rawInput) ? oldValue : rawInput);

    hilog.info(0x0000, TAG, `[SETTING_UI][min_duration_save_try] input=${this.minEventDurationInput}, normalized=${nextValue}, old=${oldValue}`);

    this.minEventDuration = nextValue;
    this.minEventDurationInput = `${nextValue}`;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setMinEventDuration(nextValue);
      const stored = await pref.getMinEventDuration();
      this.minEventDuration = stored;
      this.minEventDurationInput = `${stored}`;
      AppStorage.setOrCreate(AppStorageKeys.MIN_EVENT_DURATION, stored);
      hilog.info(0x0000, TAG, `[SETTING_UI][min_duration_saved] value=${stored}`);
      this.safeShowToast(`已设置最小时长 ${stored} 分钟`);
    } catch (error) {
      this.minEventDuration = oldValue;
      this.minEventDurationInput = `${oldValue}`;
      hilog.warn(0x0000, TAG, `[SETTING_UI][min_duration_save_failed] reason=${JSON.stringify(error)}`);
      this.safeShowToast('最小时长保存失败');
    }
  }

  private async onIdleGapDetectionChanged(value: boolean): Promise<void> {
    const oldValue = this.enableIdleGapDetection;
    this.enableIdleGapDetection = value;
    try {
      const pref = PreferenceManager.getInstance();
      await pref.setIdleGapDetectionEnabled(value);
      this.enableIdleGapDetection = await pref.getIdleGapDetectionEnabled();
      this.safeShowToast(this.enableIdleGapDetection ? '已开启空闲时间检测' : '已关闭空闲时间检测');
    } catch (error) {
      this.enableIdleGapDetection = oldValue;
      this.safeShowToast('空闲时间检测开关保存失败');
    }
  }

  private async saveIdleGapTriggerMinutes(): Promise<void> {
    const oldValue = this.idleGapTriggerMinutes;
    const rawInput = parseInt(this.idleGapTriggerInput, 10);
    const nextValue = PreferenceManager.normalizeIdleGapTriggerMinutes(isNaN(rawInput) ? oldValue : rawInput);

    this.idleGapTriggerMinutes = nextValue;
    this.idleGapTriggerInput = `${nextValue}`;

    try {
      const pref = PreferenceManager.getInstance();
      await pref.setIdleGapTriggerMinutes(nextValue);
      const stored = await pref.getIdleGapTriggerMinutes();
      this.idleGapTriggerMinutes = stored;
      this.idleGapTriggerInput = `${stored}`;
      this.safeShowToast(`空闲检测触发阈值已设置为 ${stored} 分钟`);
    } catch (error) {
      this.idleGapTriggerMinutes = oldValue;
      this.idleGapTriggerInput = `${oldValue}`;
      this.safeShowToast('空闲检测触发阈值保存失败');
    }
  }

  private async resetAllTips(): Promise<void> {
    try {
      const pref = PreferenceManager.getInstance();

      await pref.setValue(PreferenceManager.KEY_HIDE_ARCHIVE_TIP, false);
      await pref.setValue(PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP, false);

      await this.reloadSettingsState();

      this.safeShowToast('已恢复所有提示弹窗');
    } catch (error) {
      this.safeShowToast('恢复提示弹窗失败');
    }
  }

  private async reloadSettingsState(): Promise<void> {
    const pref = PreferenceManager.getInstance();
    this.themeMode = ThemeCenter.normalizeThemeMode(await pref.getThemeMode());
    const context = this.getUIContext().getHostContext() as common.Context;
    this.effectiveTheme = ThemeCenter.applyThemeMode(context, this.themeMode);

    this.enableAmapRouteApi = await pref.isAmapRouteApiEnabled();
    this.weatherFeatureEnabled = await pref.isWeatherFeatureEnabled();
    this.enableIdleGapDetection = await pref.getIdleGapDetectionEnabled();
    this.idleGapTriggerMinutes = await pref.getIdleGapTriggerMinutes();
    this.idleGapTriggerInput = `${this.idleGapTriggerMinutes}`;

    const hideArchiveTip = await pref.getValue(
      PreferenceManager.KEY_HIDE_ARCHIVE_TIP,
      false
    );
    const hideDeleteTip = await pref.getValue(
      PreferenceManager.KEY_HIDE_SOFT_DELETE_TIP,
      false
    );

    this.showArchiveTip = hideArchiveTip !== true;
    this.showDeleteTip = hideDeleteTip !== true;

    this.minEventDuration = await pref.getMinEventDuration();
    this.minEventDurationInput = `${this.minEventDuration}`;
    AppStorage.setOrCreate(AppStorageKeys.MIN_EVENT_DURATION, this.minEventDuration);
    hilog.info(0x0000, TAG, `[SETTING_UI][min_duration_loaded] value=${this.minEventDuration}`);
    if (this.diagnosticsPlanIdInput.trim().length > 0) {
      this.refreshStateMachineDiagnostics();
    }
  }

  private refreshStateMachineDiagnostics(): void {
    const planId = this.diagnosticsPlanIdInput.trim();
    if (planId.length === 0) {
      this.diagnosticsSummary = '请先输入计划ID';
      this.diagnosticsLogs = [];
      return;
    }
    const metrics = this.planStateMachine.getDailyMetrics(planId);
    const transitions: PlanTransitionEvent[] = this.planStateMachine.getRecentTransitions(planId, 12);
    const c = metrics.counters;
    this.diagnosticsSummary =
      `day=${metrics.dayKey} plan=${planId}\n` +
      `ready: ${c['auto_transition_attempt_ready'] ?? 0}/${c['auto_transition_success_ready'] ?? 0}/${c['auto_transition_fail_ready'] ?? 0}\n` +
      `in_progress: ${c['auto_transition_attempt_in_progress'] ?? 0}/${c['auto_transition_success_in_progress'] ?? 0}/${c['auto_transition_fail_in_progress'] ?? 0}\n` +
      `jitter_blocked: ${c['transition_jitter_blocked'] ?? 0}\n` +
      `recovery: ${c['recovery_attempt'] ?? 0}/${c['recovery_success'] ?? 0}/${c['recovery_fail'] ?? 0}`;
    this.diagnosticsLogs = transitions.map((event: PlanTransitionEvent) => {
      const ts = new Date(event.timestamp).toLocaleString();
      return `${ts} ${event.fromStatus} -> ${event.toStatus} (${event.triggerReason})`;
    }).reverse();
  }

  private exportStateMachineDiagnostics(): void {
    const planId = this.diagnosticsPlanIdInput.trim();
    if (planId.length === 0) {
      this.safeShowToast('请先输入计划ID');
      return;
    }
    const snapshot = this.planStateMachine.exportDiagnosticsSnapshot(planId);
    const json = JSON.stringify(snapshot, null, 2);
    AppStorage.setOrCreate(AppStorageKeys.PLAN_STATE_DIAGNOSTIC_EXPORT, json);
    this.diagnosticsExportPreview = json.length > 320
      ? `${json.slice(0, 320)}...`
      : json;
    this.safeShowToast('诊断快照已导出到本地（AppStorage）');
  }

  @Builder
  SettingSectionTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor(this.getThemePalette().textTertiary)
      .width('100%')
      .margin({ top: 20, bottom: 10 });
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('设置')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getThemePalette().textPrimary)
            .margin({ top: 12 });
        }
        .width('100%')
        .padding({ left: 16, top: 10, bottom: 10, right: 16 })
        .backgroundColor(this.getThemePalette().cardBg);

        Scroll() {
          Column() {
            this.SettingSectionTitle('服务与费用控制');
            SettingSelectItem({
              title: '主题模式',
              desc: '支持浅色、深色与跟随系统。',
              valueText: this.getThemeModeText(),
              textPrimary: this.getThemePalette().textPrimary,
              textSecondary: this.getThemePalette().textSecondary,
              cardBg: this.getThemePalette().cardBg,
              actionColor: this.getThemePalette().primary,
              onClickItem: () => {
                this.showThemeModeDialog();
              }
            });

            SettingSwitchItem({
              title: '允许调用高德路线 API',
              desc: '关闭后不再请求高德路线规划，失败或禁用时统一按 60 分钟处理，可降低调用费用。',
              loading: this.loading,
              checked: this.enableAmapRouteApi,
              textPrimary: this.getThemePalette().textPrimary,
              textSecondary: this.getThemePalette().textSecondary,
              cardBg: this.getThemePalette().cardBg,
              onToggle: async (value: boolean) => {
                await this.onAmapRouteApiChanged(value);
              }
            });

            SettingSwitchItem({
              title: '启用天气功能',
              desc: '关闭后隐藏天气展示、刷新与提醒能力，不再参与规划与执行建议。',
              loading: this.loading,
              checked: this.weatherFeatureEnabled,
              textPrimary: this.getThemePalette().textPrimary,
              textSecondary: this.getThemePalette().textSecondary,
              cardBg: this.getThemePalette().cardBg,
              onToggle: async (value: boolean) => {
                await this.onWeatherFeatureChanged(value);
              }
            });

            this.SettingSectionTitle('空闲时间检测');

            SettingSwitchItem({
              title: '启用空闲时间检测',
              desc: '关闭后，不再触发“检测到空闲时间”的优化提示入口。',
              loading: this.loading,
              checked: this.enableIdleGapDetection,
              textPrimary: this.getThemePalette().textPrimary,
              textSecondary: this.getThemePalette().textSecondary,
              cardBg: this.getThemePalette().cardBg,
              onToggle: async (value: boolean) => {
                await this.onIdleGapDetectionChanged(value);
              }
            });

            Column() {
              Text('空闲检测触发阈值 (分钟)')
                .fontSize(16)
                .fontColor(this.getThemePalette().textPrimary)
                .fontWeight(FontWeight.Medium)
                .width('100%');

              Text('当某段空闲时长达到该阈值时，才会计入空闲优化提示与分配入口。')
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%')
                .margin({ top: 6, bottom: 12 });

              Row() {
                TextInput({ text: this.idleGapTriggerInput, placeholder: '请输入分钟数' })
                  .type(InputType.Number)
                  .fontSize(16)
                  .textAlign(TextAlign.Center)
                  .width(90)
                  .height(40)
                  .backgroundColor(this.getThemePalette().cardBgSoft)
                  .borderRadius(8)
                  .enabled(this.enableIdleGapDetection)
                  .onChange((value: string) => {
                    this.idleGapTriggerInput = value;
                  });

                Text('分钟')
                  .fontSize(14)
                  .fontColor(this.getThemePalette().textSecondary)
                  .margin({ left: 8, right: 12 });

                Button('保存')
                  .height(40)
                  .padding({ left: 16, right: 16 })
                  .borderRadius(8)
                  .backgroundColor(this.getThemePalette().primary)
                  .fontColor(Color.White)
                  .enabled(this.enableIdleGapDetection)
                  .opacity(this.enableIdleGapDetection ? 1 : 0.5)
                  .onClick(async () => {
                    await this.saveIdleGapTriggerMinutes();
                  });
              }
              .width('100%');
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.getThemePalette().cardBg)
            .borderRadius(12)
            .margin({ top: 4, bottom: 4 });

            this.SettingSectionTitle('提示弹窗');

            SettingSwitchItem({
              title: '显示归档提示弹窗',
              desc: '关闭后，归档计划时将不再显示说明弹窗；之后仍可在设置中重新开启。',
              loading: this.loading,
              checked: this.showArchiveTip,
              textPrimary: this.getThemePalette().textPrimary,
              textSecondary: this.getThemePalette().textSecondary,
              cardBg: this.getThemePalette().cardBg,
              onToggle: async (value: boolean) => {
                await this.onShowArchiveTipChanged(value);
              }
            });

            SettingSwitchItem({
              title: '显示删除提示弹窗',
              desc: '关闭后，将计划移入回收站时不再显示说明弹窗；之后仍可在设置中重新开启。',
              loading: this.loading,
              checked: this.showDeleteTip,
              textPrimary: this.getThemePalette().textPrimary,
              textSecondary: this.getThemePalette().textSecondary,
              cardBg: this.getThemePalette().cardBg,
              onToggle: async (value: boolean) => {
                await this.onShowDeleteTipChanged(value);
              }
            });
            this.SettingSectionTitle('冲突压缩限制');

            Column() {
              Text('压缩方案最小时长 (分钟)')
                .fontSize(16)
                .fontColor(this.getThemePalette().textPrimary)
                .fontWeight(FontWeight.Medium)
                .width('100%');

              Text('当选择“压缩前序”时，单个地点不会被压缩到低于该值。')
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%')
                .margin({ top: 6, bottom: 12 });

              Row() {
                TextInput({ text: this.minEventDurationInput, placeholder: '请输入分钟数' })
                  .type(InputType.Number)
                  .fontSize(16)
                  .textAlign(TextAlign.Center)
                  .width(90)
                  .height(40)
                  .backgroundColor(this.getThemePalette().cardBgSoft)
                  .borderRadius(8)
                  .onChange((value: string) => {
                    this.minEventDurationInput = value;
                  });

                Text('分钟')
                  .fontSize(14)
                  .fontColor(this.getThemePalette().textSecondary)
                  .margin({ left: 8, right: 12 });

                Button('保存')
                  .height(40)
                  .padding({ left: 16, right: 16 })
                  .borderRadius(8)
                  .backgroundColor(this.getThemePalette().primary)
                  .fontColor(Color.White)
                  .onClick(async () => {
                    await this.saveMinEventDuration();
                  });
              }
              .width('100%');
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.getThemePalette().cardBg)
            .borderRadius(12)
            .margin({ top: 4, bottom: 4 });

            Button('恢复所有提示弹窗')
              .width('100%')
              .height(48)
              .margin({ top: 12 })
              .borderRadius(12)
              .backgroundColor(this.getThemePalette().cardBg)
              .fontColor(this.getThemePalette().textPrimary)
              .onClick(async () => {
                await this.resetAllTips();
              });

            this.SettingSectionTitle('状态机诊断');

            Column({ space: 10 }) {
              Row({ space: 8 }) {
                TextInput({ text: this.diagnosticsPlanIdInput, placeholder: '输入计划ID' })
                  .type(InputType.Number)
                  .fontSize(14)
                  .textAlign(TextAlign.Center)
                  .width(120)
                  .height(38)
                  .backgroundColor(this.getThemePalette().cardBgSoft)
                  .borderRadius(8)
                  .onChange((value: string) => {
                    this.diagnosticsPlanIdInput = value;
                  });
                Button('刷新诊断')
                  .height(38)
                  .padding({ left: 14, right: 14 })
                  .borderRadius(8)
                  .backgroundColor(this.getThemePalette().primary)
                  .fontColor(Color.White)
                  .onClick(() => {
                    this.refreshStateMachineDiagnostics();
                  });
                Button('导出JSON')
                  .height(38)
                  .padding({ left: 14, right: 14 })
                  .borderRadius(8)
                  .backgroundColor(this.getThemePalette().success)
                  .fontColor(Color.White)
                  .onClick(() => {
                    this.exportStateMachineDiagnostics();
                  });
              }
              .width('100%');

              Text(this.diagnosticsSummary)
                .fontSize(12)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%');

              ForEach(this.diagnosticsLogs, (line: string) => {
                Text(line)
                  .fontSize(12)
                  .fontColor(this.getThemePalette().textTertiary)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }, (line: string) => line);
              if (this.diagnosticsExportPreview.trim().length > 0) {
                Text('导出预览：')
                  .fontSize(12)
                  .fontColor(this.getThemePalette().textSecondary)
                  .width('100%')
                  .margin({ top: 8 });
                Text(this.diagnosticsExportPreview)
                  .fontSize(11)
                  .fontColor(this.getThemePalette().textTertiary)
                  .width('100%')
                  .maxLines(6)
                  .textOverflow({ overflow: TextOverflow.Ellipsis });
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.getThemePalette().cardBg)
            .borderRadius(12)
            .margin({ top: 4, bottom: 4 });

            this.SettingSectionTitle('说明');

            Column() {
              Text('这里是全局设置页，适合放应用级开关，而不是某个单独页面的临时选项。')
                .fontSize(13)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%');

              Text('当前“7 天后自动删除”属于进入列表页时触发的过期清理，不是系统后台定时任务。')
                .fontSize(13)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%')
                .margin({ top: 8 });

              Text('“彻底删除”这类强破坏性操作应继续保留确认弹窗，不建议提供关闭入口。')
                .fontSize(13)
                .fontColor(this.getThemePalette().textSecondary)
                .width('100%')
                .margin({ top: 8 });
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.getThemePalette().cardBg)
            .borderRadius(12)
            .margin({ top: 4, bottom: 20 });
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 90 });
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1);
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getThemePalette().pageBg);

      GlobalBottomNavBar({
        currentTab: 'settings',
        showCenterFab: false
      })
        .zIndex(9);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemePalette().pageBg);
  }
}






