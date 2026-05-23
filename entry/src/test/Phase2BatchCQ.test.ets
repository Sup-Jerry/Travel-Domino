import { describe, expect, it } from '@ohos/hypium';
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

class TransitionEventCQ {
  timestamp: number = 0;
  fromStatus: string = '';
  toStatus: string = '';
  triggerReason: string = '';
}

interface SettingsAdvancedPagePrivateCQ {
  diagnosticsPlanIdInput: string;
  diagnosticsSummary: string;
  diagnosticsLogs: string[];
  diagnosticsExportPreview: string;
  effectiveTheme: string;
  refreshStateMachineDiagnostics(): void;
  exportStateMachineDiagnostics(): void;
  initialRender(): void;
}

class SettingsAdvancedStateMachineMockCQ {
  public exportPlanIds: string[] = [];

  getDailyMetrics(planId: string): PlanStateMetricsSnapshot {
    const counters: Record<string, number> = {};
    counters['auto_transition_attempt_ready'] = 1;
    counters['auto_transition_success_ready'] = 1;
    counters['auto_transition_fail_ready'] = 0;
    return {
      dayKey: '2026-04-23',
      planId: planId,
      counters: counters,
      reasons: {},
      updatedAt: 1710000000000
    };
  }

  getRecentTransitions(_planId: string, _limit: number): PlanTransitionEvent[] {
    const first = new TransitionEventCQ();
    first.timestamp = 1710000000000;
    first.fromStatus = 'READY';
    first.toStatus = 'IN_PROGRESS';
    first.triggerReason = 'auto';
    const second = new TransitionEventCQ();
    second.timestamp = 1710000001000;
    second.fromStatus = 'IN_PROGRESS';
    second.toStatus = 'DONE';
    second.triggerReason = 'manual';
    return [first as Object as PlanTransitionEvent, second as Object as PlanTransitionEvent];
  }

  exportDiagnosticsSnapshot(planId: string): PlanStateDiagnosticsSnapshot {
    this.exportPlanIds.push(planId);
    return {
      planId: planId,
      dayKey: '2026-04-23',
      generatedAt: 1710000000000,
      metrics: this.getDailyMetrics(planId),
      transitions: this.getRecentTransitions(planId, 50)
    };
  }
}

function createSettingsAdvancedPageCQ(machine: SettingsAdvancedStateMachineMockCQ): SettingsAdvancedPagePrivateCQ {
  const page = createSettingsAdvancedPageForTest() as SettingsAdvancedPagePrivateCQ;
  Reflect.set(page as Object, 'planStateMachine', machine);
  return page;
}

export default function phase2BatchCQTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchCQ_settings_advanced_extra', () => {
    it('normal: diagnostics_plan_id_should_trim_numeric_and_text_ids', 0, () => {
      // Arrange
      const numeric = '  42  ';
      const text = ' plan-42 ';

      // Act
      const numericResult = normalizeDiagnosticsPlanIdInput(numeric);
      const textResult = normalizeDiagnosticsPlanIdInput(text);

      // Assert
      expect(numericResult).assertEqual('42');
      expect(textResult).assertEqual('plan-42');
    });

    it('boundary: diagnostics_preview_should_return_original_when_length_equals_max', 0, () => {
      // Arrange
      const json = '12345';

      // Act
      const preview = resolveDiagnosticsExportPreview(json, 5);

      // Assert
      expect(preview).assertEqual('12345');
    });

    it('boundary: diagnostics_preview_should_truncate_when_length_exceeds_max_by_one', 0, () => {
      // Arrange
      const json = '123456';

      // Act
      const preview = resolveDiagnosticsExportPreview(json, 5);

      // Assert
      expect(preview).assertEqual('12345...');
    });

    it('invalid: diagnostics_should_not_load_for_blank_after_string_normalization', 0, () => {
      // Arrange
      const input = '   ';

      // Act
      const normalized = normalizeDiagnosticsPlanIdInput(input);
      const shouldLoad = shouldLoadStateMachineDiagnostics(normalized);

      // Assert
      expect(normalized).assertEqual('');
      expect(shouldLoad).assertFalse();
    });

    it('normal: diagnostics_transition_log_line_should_include_status_flow_and_reason', 0, () => {
      // Arrange
      const event = new TransitionEventCQ();
      event.timestamp = 1710000000000;
      event.fromStatus = 'READY';
      event.toStatus = 'IN_PROGRESS';
      event.triggerReason = 'auto';

      // Act
      const line = buildDiagnosticsTransitionLogLine(event as Object as PlanTransitionEvent);

      // Assert
      expect(line.indexOf('READY') >= 0).assertTrue();
      expect(line.indexOf('IN_PROGRESS') >= 0).assertTrue();
      expect(line.indexOf('auto') >= 0).assertTrue();
    });

    it('conflict: diagnostics_preview_should_append_only_one_ellipsis_marker_after_truncation', 0, () => {
      // Arrange
      const json = 'abcdefghij';

      // Act
      const preview = resolveDiagnosticsExportPreview(json, 4);

      // Assert
      expect(preview).assertEqual('abcd...');
      expect(preview.indexOf('......') < 0).assertTrue();
    });

    it('regression: diagnostics_transition_log_line_should_keep_from_to_and_reason', 0, () => {
      // Arrange
      const event = new TransitionEventCQ();
      event.timestamp = 1710000000000;
      event.fromStatus = 'READY';
      event.toStatus = 'DONE';
      event.triggerReason = 'manual';

      // Act
      const line = buildDiagnosticsTransitionLogLine(event as Object as PlanTransitionEvent);

      // Assert
      expect(line.indexOf('READY') >= 0).assertTrue();
      expect(line.indexOf('DONE') >= 0).assertTrue();
      expect(line.indexOf('manual') >= 0).assertTrue();
      expect(line.indexOf('->') >= 0).assertTrue();
    });

    it('combined: settings_advanced_refresh_should_reverse_recent_transition_logs', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockCQ();
      const page = createSettingsAdvancedPageCQ(machine);

      // Act
      page.diagnosticsPlanIdInput = ' plan-cq ';
      page.refreshStateMachineDiagnostics();

      // Assert
      expect(page.diagnosticsSummary.indexOf('plan=plan-cq') >= 0).assertTrue();
      expect(page.diagnosticsLogs.length).assertEqual(2);
      expect(page.diagnosticsLogs[0].indexOf('DONE') >= 0).assertTrue();
    });

    it('invalid: settings_advanced_refresh_should_clear_logs_for_blank_plan_id', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockCQ();
      const page = createSettingsAdvancedPageCQ(machine);
      page.diagnosticsPlanIdInput = 'plan-before';
      page.refreshStateMachineDiagnostics();
      page.diagnosticsPlanIdInput = '   ';

      // Act
      page.refreshStateMachineDiagnostics();

      // Assert
      expect(page.diagnosticsSummary.length > 0).assertTrue();
      expect(page.diagnosticsLogs.length).assertEqual(0);
    });

    it('combined: settings_advanced_export_should_skip_blank_plan_id_and_preserve_empty_preview', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockCQ();
      const page = createSettingsAdvancedPageCQ(machine);

      // Act
      page.diagnosticsPlanIdInput = '   ';
      page.exportStateMachineDiagnostics();

      // Assert
      expect(machine.exportPlanIds.length).assertEqual(0);
      expect(page.diagnosticsExportPreview).assertEqual('');
    });

    it('combined: settings_advanced_render_should_cover_summary_logs_and_preview_states', 0, () => {
      // Arrange
      const machine = new SettingsAdvancedStateMachineMockCQ();
      const page = createSettingsAdvancedPageCQ(machine);

      // Act
      page.effectiveTheme = 'light';
      page.diagnosticsSummary = 'summary';
      page.diagnosticsLogs = ['a -> b'];
      page.diagnosticsExportPreview = '{"planId":"cq"}';
      page.initialRender();
      page.effectiveTheme = 'dark';
      page.diagnosticsExportPreview = '';
      page.initialRender();

      // Assert
      expect(page.diagnosticsLogs.length).assertEqual(1);
      expect(page.diagnosticsSummary).assertEqual('summary');
    });
  });
}
