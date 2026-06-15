import { describe, it, expect } from '@ohos/hypium';
import { TimeConstraintSolver } from '../main/ets/domain/solver/TimeConstraintSolver';

interface TimeConstraintSolverPrivateForTest {
  resolveGlobalStartMin(globalStartTimeStr: string): number;
}

export default function timeConstraintSolverResolveGlobalStartMinCoverageTest() {
  describe('timeConstraintSolverResolveGlobalStartMinCoverageTest', () => {
    it('normal: resolve_global_start_min_should_accept_plain_time', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;

      // Act
      const resolved = privateApi.resolveGlobalStartMin('07:45');

      // Assert
      expect(resolved).assertEqual(465);
    });

    it('invalid: resolve_global_start_min_should_fallback_for_invalid_extracted_time', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;

      // Act
      const resolved = privateApi.resolveGlobalStartMin('2026-01-01 25:99');

      // Assert
      expect(resolved).assertEqual(480);
    });

    it('boundary: resolve_global_start_min_should_fallback_when_no_time_can_be_extracted', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;

      // Act
      const resolved = privateApi.resolveGlobalStartMin('start sometime tomorrow');

      // Assert
      expect(resolved).assertEqual(480);
    });

    it('conflict: resolve_global_start_min_should_keep_plain_time_priority_over_embedded_context', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;

      // Act
      const resolved = privateApi.resolveGlobalStartMin('07:30 start at 09:00');

      // Assert
      expect(resolved).assertEqual(450);
    });

    it('regression: resolve_global_start_min_should_extract_pure_time_from_datetime_text', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;

      // Act
      const resolved = privateApi.resolveGlobalStartMin('2026-01-01 07:30');

      // Assert
      expect(resolved).assertEqual(450);
    });

    it('combined: resolve_global_start_min_should_distinguish_valid_invalid_and_missing_inputs', 0, () => {
      // Arrange
      const privateApi = TimeConstraintSolver as Object as TimeConstraintSolverPrivateForTest;

      // Act
      const plainResolved = privateApi.resolveGlobalStartMin('08:15');
      const invalidResolved = privateApi.resolveGlobalStartMin('2026-01-01 99:99');
      const missingResolved = privateApi.resolveGlobalStartMin('no time provided');

      // Assert
      expect(plainResolved).assertEqual(495);
      expect(invalidResolved).assertEqual(480);
      expect(missingResolved).assertEqual(480);
    });
  });
}
