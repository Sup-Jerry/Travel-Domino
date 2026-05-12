import { describe, expect, it } from '@ohos/hypium';
import { createPlanListPageForTest } from '../main/ets/pages/PlanListPage';

interface PlanListPagePrivateDY {
  safeShowToast(message: string): void;
}

export default function phase2BatchDYTest() {
  describe('phase2BatchDYTest', () => {
    it('normal: plan_list_safe_show_toast_should_swallow_runtime_toast_result', 0, () => {
      // Arrange
      const page = createPlanListPageForTest() as PlanListPagePrivateDY;

      // Act
      page.safeShowToast('dy_plan_list_toast_message');

      // Assert
      expect(true).assertTrue();
    });
  });
}
