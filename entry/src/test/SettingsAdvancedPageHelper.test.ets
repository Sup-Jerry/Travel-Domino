import { describe, it, expect } from '@ohos/hypium';
import {
  buildDiagnosticsTransitionLogLine,
  createSettingsAdvancedPageForTest,
  normalizeDiagnosticsPlanIdInput,
  resolveDiagnosticsExportPreview,
  shouldLoadStateMachineDiagnostics
} from '../main/ets/pages/SettingsAdvancedPage';
import { PlanTransitionEvent } from '../main/ets/domain/statemachine/ExecutionContext';
import { PlanStateDiagnosticsSnapshot } from '../main/ets/domain/statemachine/PlanStateMachine';
import { PlanStateMetricsSnapshot } from '../main/ets/domain/statemachine/PlanStateMetricsStore';

class MockTransitionEvent {
  timestamp: number = 0;
  fromStatus: string = '';
  toStatus: string = '';
  triggerReason: string = '';
}

interface SettingsAdvancedPagePrivateTest {
  diagnosticsPlanIdInput: string;
  diagnosticsSummary: string;
  diagnosticsLogs: string[];
  diagnosticsExportPreview: string;
  effectiveTheme: string;
  getThemePalette(): Object;
  safeShowToast(message: string): void;
  refreshStateMachineDiagnostics(): void;
  exportStateMachineDiagnostics(): void;
  initialRender(): void;
}

interface SettingsAdvancedStateMachineTest {
  getDailyMetrics(planId: string): PlanStateMetricsSnapshot;
  getRecentTransitions(planId: string, limit: number): PlanTransitionEvent[];
  exportDiagnosticsSnapshot(planId: string): PlanStateDiagnosticsSnapshot;
}

class SettingsAdvancedStateMachineMockTest implements SettingsAdvancedStateMachineTest {
  public metricsPlanId: string = '';
  public transitionsPlanId: string = '';
  public transitionLimit: number = 0;
  public exportPlanId: string = '';

  getDailyMetrics(planId: string): PlanStateMetricsSnapshot {
    this.metricsPlanId = planId;
    const counters: Record<string, number> = {};
    counters['auto_transition_attempt_ready'] = 3;
    counters['auto_transition_success_ready'] = 2;
    counters['auto_transition_fail_ready'] = 1;
    counters['auto_transition_attempt_in_progress'] = 4;
    counters['auto_transition_success_in_progress'] = 3;
    counters['auto_transition_fail_in_progress'] = 1;
    counters['transition_jitter_blocked'] = 5;
    counters['recovery_attempt'] = 2;
    counters['recovery_success'] = 1;
    counters['recovery_fail'] = 1;
    const reasons: Record<string, number> = {};
    return {
      dayKey: '2026-04-22',
      planId: planId,
      counters: counters,
      reasons: reasons,
      updatedAt: 1710000000000
    };
  }

  getRecentTransitions(planId: string, limit: number): PlanTransitionEvent[] {
    this.transitionsPlanId = planId;
    this.transitionLimit = limit;
    const event = new MockTransitionEvent();
    event.timestamp = 1710000000000;
    event.fromStatus = 'READY';
    event.toStatus = 'IN_PROGRESS';
    event.triggerReason = 'auto';
    return [event as Object as PlanTransitionEvent];
  }

  exportDiagnosticsSnapshot(planId: string): PlanStateDiagnosticsSnapshot {
    this.exportPlanId = planId;
    return {
      planId: planId,
      dayKey: '2026-04-22',
      generatedAt: 1710000000000,
      metrics: this.getDailyMetrics(planId),
      transitions: this.getRecentTransitions(planId, 50)
    };
  }
}

function createSettingsAdvancedPrivateForTest(
  stateMachine: SettingsAdvancedStateMachineTest
): SettingsAdvancedPagePrivateTest {
  const page = createSettingsAdvancedPageForTest() as SettingsAdvancedPagePrivateTest;
  Reflect.set(page as Object, 'planStateMachine', stateMachine);
  return page;
}

export default function settingsAdvancedPageHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsAdvancedPageHelper', () => {
    it('normal: diagnostics_should_trim_plan_id_input', 0, () => {
      // Arrange
      const input = '  42  ';
      // Act
      const text = normalizeDiagnosticsPlanIdInput(input);
      // Assert
      expect(text).assertEqual('42');
    });

    it('boundary: diagnostics_should_not_load_when_plan_id_empty', 0, () => {
      // Arrange
      const input = '   ';
      // Act
      const canLoad = shouldLoadStateMachineDiagnostics(input);
      // Assert
      expect(canLoad).assertFalse();
    });

    it('invalid: diagnostics_preview_should_keep_short_json_unchanged', 0, () => {
      // Arrange
      const json = '{"a":1}';
      // Act
      const preview = resolveDiagnosticsExportPreview(json, 10);
      // Assert
      expect(preview).assertEqual('{"a":1}');
    });

    it('conflict: diagnostics_preview_should_append_ellipsis_when_too_long', 0, () => {
      // Arrange
      const json = '1234567890';
      // Act
      const preview = resolveDiagnosticsExportPreview(json, 5);
      // Assert
      expect(preview).assertEqual('12345...');
    });

    it('regression: td-20260412-diagnostics_transition_line_should_keep_arrow_separator', 0, () => {
      // Arrange
      const event = new MockTransitionEvent();
      event.timestamp = 1710000000000;
      event.fromStatus = 'READY';
      event.toStatus = 'IN_PROGRESS';
      event.triggerReason = 'auto';
      // Act
      const line = buildDiagnosticsTransitionLogLine(event as Object as PlanTransitionEvent);
      // Assert
      expect(line.indexOf('->') >= 0).assertTrue();
    });

    it('combined: diagnostics_normalize_and_load_should_chain', 0, () => {
      // Arrange
      const input = '  plan-7 ';
      // Act
      const normalized = normalizeDiagnosticsPlanIdInput(input);
      const canLoad = shouldLoadStateMachineDiagnostics(normalized);
      // Assert
      expect(canLoad).assertTrue();
    });

    it('boundary: settings_advanced_refresh_should_prompt_when_plan_id_empty', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockTest();
      const page = createSettingsAdvancedPrivateForTest(machine);

      // Act
      page.diagnosticsPlanIdInput = '   ';
      page.refreshStateMachineDiagnostics();

      // Assert
      expect(page.diagnosticsSummary).assertEqual('请先输入计划ID');
      expect(page.diagnosticsLogs.length).assertEqual(0);
      expect(machine.metricsPlanId).assertEqual('');
    });

    it('normal: settings_advanced_refresh_should_build_summary_and_reverse_logs', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockTest();
      const page = createSettingsAdvancedPrivateForTest(machine);

      // Act
      page.diagnosticsPlanIdInput = '  plan-42 ';
      page.refreshStateMachineDiagnostics();

      // Assert
      expect(machine.metricsPlanId).assertEqual('plan-42');
      expect(machine.transitionsPlanId).assertEqual('plan-42');
      expect(machine.transitionLimit).assertEqual(12);
      expect(page.diagnosticsSummary.indexOf('plan=plan-42') >= 0).assertTrue();
      expect(page.diagnosticsSummary.indexOf('ready: 3/2/1') >= 0).assertTrue();
      expect(page.diagnosticsLogs.length).assertEqual(1);
      expect(page.diagnosticsLogs[0].indexOf('->') >= 0).assertTrue();
    });

    it('combined: settings_advanced_export_and_render_should_cover_preview_branch', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockTest();
      const page = createSettingsAdvancedPrivateForTest(machine);
      let toastMessage = '';
      Reflect.set(page as Object, 'safeShowToast', (message: string): void => {
        toastMessage = message;
      });

      // Act
      page.diagnosticsPlanIdInput = ' plan-99 ';
      page.exportStateMachineDiagnostics();
      page.effectiveTheme = 'dark';
      page.initialRender();
      const palette = page.getThemePalette();

      // Assert
      expect(machine.exportPlanId).assertEqual('plan-99');
      expect(page.diagnosticsExportPreview.indexOf('plan-99') >= 0).assertTrue();
      expect(toastMessage.length > 0).assertTrue();
      expect(palette !== null).assertTrue();
    });
  });
}
