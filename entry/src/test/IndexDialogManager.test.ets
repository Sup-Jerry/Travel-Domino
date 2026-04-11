import { describe, it, expect } from '@ohos/hypium';
import { IndexDialogManager } from '../main/ets/pages/index/IndexDialogManager';

interface DatePickerDialogOptionsLike {
  start: Date;
  end: Date;
  selected: Date;
  onAccept: (value: DatePickerResult) => void;
}

class DatePickerResultMock {
  year: number;
  month: number;
  day: number;

  constructor(year: number, month: number, day: number) {
    this.year = year;
    this.month = month;
    this.day = day;
  }
}

class PickerUiContextMock {
  showCount: number = 0;
  dialogs: DatePickerDialogOptionsLike[] = [];

  showDatePickerDialog(options: DatePickerDialogOptionsLike): void {
    this.showCount += 1;
    this.dialogs.push(options);
  }
}

export default function indexDialogManagerTest() {
  describe('unit_test_case_generator_autofill_IndexDialogManager', () => {
    it('normal: open_plan_date_picker_should_emit_day_start_timestamp', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let actualDateMs = -1;

      // Act
      IndexDialogManager.openPlanDatePicker(uiContext as Object as UIContext, 0, (dateMs: number) => {
        actualDateMs = dateMs;
      });
      const accept = new DatePickerResultMock(2026, 3, 8);
      uiContext.dialogs[0].onAccept(accept as Object as DatePickerResult);

      // Assert
      const expected = new Date();
      expected.setFullYear(2026, 3, 8);
      expected.setHours(0, 0, 0, 0);
      expect(actualDateMs).assertEqual(expected.getTime());
    });

    it('boundary: open_range_end_picker_should_emit_end_of_day_timestamp', 0, () => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      const startDate = new Date(2026, 3, 9, 0, 0, 0, 0);
      let actualStartMs = -1;
      let actualEndMs = -1;

      // Act
      IndexDialogManager.openRangeEndDatePicker(uiContext as Object as UIContext, startDate, (startMs: number, endMs: number) => {
        actualStartMs = startMs;
        actualEndMs = endMs;
      });
      const accept = new DatePickerResultMock(2026, 3, 10);
      uiContext.dialogs[0].onAccept(accept as Object as DatePickerResult);

      // Assert
      const expectedEnd = new Date();
      expectedEnd.setFullYear(2026, 3, 10);
      expectedEnd.setHours(23, 59, 59, 999);
      expect(actualStartMs).assertEqual(startDate.getTime());
      expect(actualEndMs).assertEqual(expectedEnd.getTime());
    });

    it('invalid: open_single_date_filter_picker_should_work_when_plan_start_is_zero', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let actualDateMs = -1;

      // Act
      IndexDialogManager.openSingleDateFilterPicker(uiContext as Object as UIContext, 0, (dateMs: number) => {
        actualDateMs = dateMs;
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      const accept = new DatePickerResultMock(2026, 4, 1);
      uiContext.dialogs[0].onAccept(accept as Object as DatePickerResult);

      // Assert
      const expected = new Date();
      expected.setFullYear(2026, 4, 1);
      expected.setHours(0, 0, 0, 0);
      expect(uiContext.showCount).assertEqual(1);
      expect(actualDateMs).assertEqual(expected.getTime());
      done();
    });

    it('conflict: open_range_date_filter_picker_should_open_end_picker_after_start_selection', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let startMs = -1;
      let endMs = -1;

      // Act
      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 3, 5).getTime(),
        (s: number, e: number) => {
          startMs = s;
          endMs = e;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      const firstAccept = new DatePickerResultMock(2026, 3, 11);
      uiContext.dialogs[0].onAccept(firstAccept as Object as DatePickerResult);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 360);
      });

      // Assert
      expect(uiContext.showCount).assertEqual(2);
      const expectedStart = new Date();
      expectedStart.setFullYear(2026, 3, 11);
      expectedStart.setHours(0, 0, 0, 0);
      expect(uiContext.dialogs[1].start.getTime()).assertEqual(expectedStart.getTime());
      expect(startMs).assertEqual(-1);
      expect(endMs).assertEqual(-1);
      done();
    });

    it('regression: open_range_date_filter_picker_should_emit_selected_range_when_end_accepted', 0, async (done: Function) => {
      // Arrange
      const uiContext = new PickerUiContextMock();
      let actualStartMs = -1;
      let actualEndMs = -1;

      // Act
      IndexDialogManager.openRangeDateFilterPicker(
        uiContext as Object as UIContext,
        new Date(2026, 3, 5).getTime(),
        (startMs: number, endMs: number) => {
          actualStartMs = startMs;
          actualEndMs = endMs;
        }
      );
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      const firstAccept = new DatePickerResultMock(2026, 3, 14);
      uiContext.dialogs[0].onAccept(firstAccept as Object as DatePickerResult);
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 360);
      });
      const secondAccept = new DatePickerResultMock(2026, 3, 16);
      uiContext.dialogs[1].onAccept(secondAccept as Object as DatePickerResult);

      // Assert
      const expectedStart = new Date();
      expectedStart.setFullYear(2026, 3, 14);
      expectedStart.setHours(0, 0, 0, 0);
      const expectedEnd = new Date();
      expectedEnd.setFullYear(2026, 3, 16);
      expectedEnd.setHours(23, 59, 59, 999);
      expect(actualStartMs).assertEqual(expectedStart.getTime());
      expect(actualEndMs).assertEqual(expectedEnd.getTime());
      done();
    });

    it('combined: single_and_plan_picker_should_keep_callbacks_isolated', 0, async (done: Function) => {
      // Arrange
      const singleUi = new PickerUiContextMock();
      const planUi = new PickerUiContextMock();
      let singleDateMs = -1;
      let planDateMs = -1;

      // Act
      IndexDialogManager.openSingleDateFilterPicker(singleUi as Object as UIContext, new Date(2026, 0, 1).getTime(), (dateMs: number) => {
        singleDateMs = dateMs;
      });
      IndexDialogManager.openPlanDatePicker(planUi as Object as UIContext, new Date(2026, 0, 2).getTime(), (dateMs: number) => {
        planDateMs = dateMs;
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 130);
      });
      singleUi.dialogs[0].onAccept(new DatePickerResultMock(2026, 0, 5) as Object as DatePickerResult);
      planUi.dialogs[0].onAccept(new DatePickerResultMock(2026, 0, 6) as Object as DatePickerResult);

      // Assert
      const expectedSingle = new Date();
      expectedSingle.setFullYear(2026, 0, 5);
      expectedSingle.setHours(0, 0, 0, 0);
      const expectedPlan = new Date();
      expectedPlan.setFullYear(2026, 0, 6);
      expectedPlan.setHours(0, 0, 0, 0);
      expect(singleDateMs).assertEqual(expectedSingle.getTime());
      expect(planDateMs).assertEqual(expectedPlan.getTime());
      done();
    });
  });
}
