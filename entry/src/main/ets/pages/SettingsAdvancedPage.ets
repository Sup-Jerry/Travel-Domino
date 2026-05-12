import { promptAction } from '@kit.ArkUI';
import { AppStorageKeys } from '../common/constants/AppStorageKeys';
import { ThemeCenter } from '../common/utils/ThemeCenter';
import { PlanStateMachine } from '../domain/statemachine/PlanStateMachine';
import { PlanTransitionEvent } from '../domain/statemachine/ExecutionContext';
import { SettingsSubPageHeader } from './components/views/SettingsItems';

export function normalizeDiagnosticsPlanIdInput(value: string): string {
  return String(value || '').trim();
}

export function shouldLoadStateMachineDiagnostics(planIdInput: string): boolean {
  return normalizeDiagnosticsPlanIdInput(planIdInput).length > 0;
}

export function resolveDiagnosticsExportPreview(json: string, maxLength: number = 320): string {
  if (json.length <= maxLength) {
    return json;
  }
  return `${json.slice(0, maxLength)}...`;
}

export function buildDiagnosticsTransitionLogLine(event: PlanTransitionEvent): string {
  const ts = new Date(event.timestamp).toLocaleString();
  return `${ts} ${event.fromStatus} -> ${event.toStatus} (${event.triggerReason})`;
}

@Entry
@Component
struct SettingsAdvancedPage {
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
    } catch (_error) {
    }
  }

  private refreshStateMachineDiagnostics(): void {
    const planId = normalizeDiagnosticsPlanIdInput(this.diagnosticsPlanIdInput);
    if (!shouldLoadStateMachineDiagnostics(planId)) {
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
    this.diagnosticsLogs = transitions.map((event: PlanTransitionEvent) => buildDiagnosticsTransitionLogLine(event)).reverse();
  }

  private exportStateMachineDiagnostics(): void {
    const planId = normalizeDiagnosticsPlanIdInput(this.diagnosticsPlanIdInput);
    if (!shouldLoadStateMachineDiagnostics(planId)) {
      this.safeShowToast('请先输入计划ID');
      return;
    }
    const snapshot = this.planStateMachine.exportDiagnosticsSnapshot(planId);
    const json = JSON.stringify(snapshot, null, 2);
    AppStorage.setOrCreate(AppStorageKeys.PLAN_STATE_DIAGNOSTIC_EXPORT, json);
    this.diagnosticsExportPreview = resolveDiagnosticsExportPreview(json);
    this.safeShowToast('诊断快照已导出到本地（AppStorage）');
  }

  build() {
    Column({ space: 10 }) {
      SettingsSubPageHeader({ title: '高级与诊断' });

      Row({ space: 8 }) {
        TextInput({ text: this.diagnosticsPlanIdInput, placeholder: '输入计划ID' })
          .type(InputType.Number)
          .fontSize(14)
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
          .height(38)
          .backgroundColor(this.getThemePalette().cardBgSoft)
          .borderRadius(8)
          .onChange((value: string) => {
            this.diagnosticsPlanIdInput = value;
          });

        Button('刷新诊断')
          .height(38)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .backgroundColor(this.getThemePalette().primary)
          .fontColor(Color.White)
          .onClick(() => {
            this.refreshStateMachineDiagnostics();
          });

        Button('导出JSON')
          .height(38)
          .padding({ left: 12, right: 12 })
          .borderRadius(8)
          .backgroundColor(this.getThemePalette().success)
          .fontColor(Color.White)
          .onClick(() => {
            this.exportStateMachineDiagnostics();
          });
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.getThemePalette().cardBg)
      .borderRadius(12);

      Text(this.diagnosticsSummary)
        .fontSize(12)
        .fontColor(this.getThemePalette().textSecondary)
        .width('100%')
        .padding(12)
        .backgroundColor(this.getThemePalette().cardBg)
        .borderRadius(12);

      ForEach(this.diagnosticsLogs, (line: string) => {
        Text(line)
          .fontSize(12)
          .fontColor(this.getThemePalette().textTertiary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }, (line: string) => line);

      if (this.diagnosticsExportPreview.trim().length > 0) {
        Text(this.diagnosticsExportPreview)
          .fontSize(11)
          .fontColor(this.getThemePalette().textTertiary)
          .width('100%')
          .maxLines(8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding(12)
          .backgroundColor(this.getThemePalette().cardBg)
          .borderRadius(12);
      }

      Blank().layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, bottom: 20 })
    .backgroundColor(this.getThemePalette().pageBg);
  }
}

export function createSettingsAdvancedPageForTest(): Object {
  return new SettingsAdvancedPage(undefined, {} as LocalStorage);
}
