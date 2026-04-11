import { describe, it, expect } from '@ohos/hypium';
import { window } from '@kit.ArkUI';
import {
  applyCompanionSystemBarVisible,
  createCompanionZeroInsets
} from '../main/ets/pages/components/views/companion/CompanionWindowHelper';

class SystemBarWindowMock {
  calls: Array<string[]> = [];
  shouldReject: boolean = false;

  setWindowSystemBarEnable(types: string[]): Promise<void> {
    this.calls.push(types);
    if (this.shouldReject) {
      return Promise.reject(new Error('window_fail'));
    }
    return Promise.resolve();
  }
}

export default function companionWindowHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionWindowHelper', () => {
    it('normal: create_zero_insets_should_return_all_zero', 0, () => {
      // Arrange
      // Act
      const insets = createCompanionZeroInsets();

      // Assert
      expect(insets.top).assertEqual(0);
      expect(insets.bottom).assertEqual(0);
      expect(insets.left).assertEqual(0);
      expect(insets.right).assertEqual(0);
    });

    it('boundary: apply_system_bar_visible_true_should_enable_two_system_bars', 0, async (done: Function) => {
      // Arrange
      const target = new SystemBarWindowMock();

      // Act
      applyCompanionSystemBarVisible(target as Object as window.Window, true);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(target.calls.length).assertEqual(1);
      expect(target.calls[0].length).assertEqual(2);
      expect(target.calls[0][0]).assertEqual('status');
      expect(target.calls[0][1]).assertEqual('navigation');
      done();
    });

    it('invalid: apply_system_bar_should_not_throw_when_native_call_rejects', 0, async (done: Function) => {
      // Arrange
      const target = new SystemBarWindowMock();
      target.shouldReject = true;

      // Act
      applyCompanionSystemBarVisible(target as Object as window.Window, false);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(target.calls.length).assertEqual(1);
      done();
    });

    it('conflict: apply_visibility_toggle_should_keep_call_order_consistent', 0, async (done: Function) => {
      // Arrange
      const target = new SystemBarWindowMock();

      // Act
      applyCompanionSystemBarVisible(target as Object as window.Window, true);
      applyCompanionSystemBarVisible(target as Object as window.Window, false);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(target.calls.length).assertEqual(2);
      expect(target.calls[0].length).assertEqual(2);
      expect(target.calls[1].length).assertEqual(0);
      done();
    });

    it('regression: create_zero_insets_should_return_new_object_each_call', 0, () => {
      // Arrange
      const first = createCompanionZeroInsets();

      // Act
      const second = createCompanionZeroInsets();
      first.top = 10;

      // Assert
      expect(second.top).assertEqual(0);
      expect(first.top === second.top).assertFalse();
    });

    it('combined: zero_insets_and_apply_hidden_should_work_together', 0, async (done: Function) => {
      // Arrange
      const target = new SystemBarWindowMock();
      const insets = createCompanionZeroInsets();

      // Act
      applyCompanionSystemBarVisible(target as Object as window.Window, false);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 0);
      });

      // Assert
      expect(insets.top + insets.bottom + insets.left + insets.right).assertEqual(0);
      expect(target.calls.length).assertEqual(1);
      expect(target.calls[0].length).assertEqual(0);
      done();
    });
  });
}
