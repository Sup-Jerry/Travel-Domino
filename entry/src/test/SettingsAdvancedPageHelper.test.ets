import { describe, it, expect } from '@ohos/hypium';
import {
  buildDiagnosticsTransitionLogLine,
  normalizeDiagnosticsPlanIdInput,
  resolveDiagnosticsExportPreview,
  shouldLoadStateMachineDiagnostics
} from '../main/ets/pages/SettingsAdvancedPage';
import { PlanTransitionEvent } from '../main/ets/domain/statemachine/ExecutionContext';

class MockTransitionEvent {
  timestamp: number = 0;
  fromStatus: string = '';
  toStatus: string = '';
  triggerReason: string = '';
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
  });
}
