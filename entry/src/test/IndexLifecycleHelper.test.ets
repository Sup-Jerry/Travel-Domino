import { describe, it, expect } from '@ohos/hypium';
import { AppStorageKeys } from '../main/ets/common/constants/AppStorageKeys';
import { IndexLifecycleHelper } from '../main/ets/pages/index/IndexLifecycleHelper';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';

interface RouterLike {
  getParams(): Record<string, Object>;
}

interface UiContextLike {
  getRouter(): RouterLike;
}

class RouterMock implements RouterLike {
  private readonly params: Object;

  constructor(params: Object) {
    this.params = params;
  }

  getParams(): Record<string, Object> {
    return this.params as Record<string, Object>;
  }
}

class UiContextMock implements UiContextLike {
  private readonly router: RouterLike;

  constructor(params: Object) {
    this.router = new RouterMock(params);
  }

  getRouter(): RouterLike {
    return this.router;
  }
}

class RouteParamsMock {
  planId?: Object;
  title?: Object;
  isNewPlan?: Object;
  autoStartFromReminder?: Object;
  forceCompanionMode?: Object;
  reminderEventId?: Object;
}

class LifecycleVmMock {
  public loadPlanId: number = -1;
  public unsavedKey: string = '';
  public stopExecutionSchedulerCount: number = 0;
  public refreshPlanningCount: number = 0;
  public refreshExecutionCount: number = 0;
  public strategyMode: number = 2;
  public weatherEnabled: boolean = true;
  public autoRefreshPlanning: boolean = true;
  public executionWeatherStage: boolean = true;
  public shouldRejectLoad: boolean = false;
  public rejectReason: string | null = null;

  setHasUnsavedPostponeStorageKey(key: string): void {
    this.unsavedKey = key;
  }

  loadData(planId: number): Promise<void> {
    this.loadPlanId = planId;
    if (this.rejectReason !== null) {
      return Promise.reject(new Error(this.rejectReason));
    }
    if (this.shouldRejectLoad) {
      return Promise.reject(new Error('load_failed'));
    }
    return Promise.resolve();
  }

  getStrategyMode(): number {
    return this.strategyMode;
  }

  isWeatherFeatureEnabled(): boolean {
    return this.weatherEnabled;
  }

  shouldAutoRefreshPlanningWeather(): boolean {
    return this.autoRefreshPlanning;
  }

  refreshPlanningWeather(_force: boolean): Promise<void> {
    this.refreshPlanningCount += 1;
    return Promise.resolve();
  }

  isExecutionWeatherStage(): boolean {
    return this.executionWeatherStage;
  }

  refreshExecutionWeather(_force: boolean, _source: string): Promise<void> {
    this.refreshExecutionCount += 1;
    return Promise.resolve();
  }

  stopExecutionWeatherScheduler(): void {
    this.stopExecutionSchedulerCount += 1;
  }
}

export default function indexLifecycleHelperTest() {
  describe('unit_test_case_generator_autofill_IndexLifecycleHelper', () => {
    it('normal: handle_about_to_appear_should_load_data_and_start_engines', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      let setPlanId = -1;
      let strategyMode = -1;
      let startArrivalCount = 0;
      let startAdaptCount = 0;
      let initPlanId = -1;
      let initIsNewPlan = false;
      const routeParams = new RouteParamsMock();
      routeParams.planId = 11;
      routeParams.title = 'trip';
      routeParams.isNewPlan = true;
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (planId: number) => {
          setPlanId = planId;
        },
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (mode: number) => {
          strategyMode = mode;
        },
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {
          startArrivalCount += 1;
        },
        onStartStrategyAdaptationCheck: () => {
          startAdaptCount += 1;
        },
        onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean) => {
          initPlanId = planId;
          initIsNewPlan = isNewPlan;
        },
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(setPlanId).assertEqual(11);
      expect(vm.loadPlanId).assertEqual(11);
      expect(vm.unsavedKey).assertContain(AppStorageKeys.HAS_UNSAVED_POSTPONE);
      expect(strategyMode).assertEqual(2);
      expect(vm.refreshPlanningCount).assertEqual(1);
      expect(startArrivalCount).assertEqual(1);
      expect(startAdaptCount).assertEqual(1);
      expect(initPlanId).assertEqual(11);
      expect(initIsNewPlan).assertTrue();
      done();
    });

    it('boundary: handle_about_to_appear_should_return_when_plan_id_missing', 0, () => {
      // Arrange
      const vm = new LifecycleVmMock();
      let setPlanIdCount = 0;
      const routeParams = new RouteParamsMock();
      routeParams.title = 'no_plan';
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {
          setPlanIdCount += 1;
        },
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      // Assert
      expect(setPlanIdCount).assertEqual(0);
      expect(vm.loadPlanId).assertEqual(-1);
    });

    it('invalid: handle_about_to_appear_should_report_load_error', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      vm.shouldRejectLoad = true;
      let loadError = '';
      const routeParams = new RouteParamsMock();
      routeParams.planId = 12;
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (reason: string) => {
          loadError = reason;
        }
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(loadError).assertEqual('load_failed');
      done();
    });

    it('conflict: handle_about_to_appear_should_auto_start_companion_from_reminder', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      let companionModeCount = 0;
      let startedEventId = -1;
      const routeParams = new RouteParamsMock();
      routeParams.planId = 13;
      routeParams.autoStartFromReminder = true;
      routeParams.reminderEventId = 99;
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {
          companionModeCount += 1;
        },
        onTryStartEvent: async (eventId: number) => {
          startedEventId = eventId;
          return true;
        },
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(companionModeCount).assertEqual(1);
      expect(startedEventId).assertEqual(99);
      done();
    });

    it('regression: handle_about_to_appear_should_stop_execution_scheduler_when_weather_disabled', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      vm.weatherEnabled = false;
      const routeParams = new RouteParamsMock();
      routeParams.planId = 14;
      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });
      // Assert
      expect(vm.stopExecutionSchedulerCount).assertEqual(1);
      expect(vm.refreshPlanningCount).assertEqual(0);
      done();
    });

    it('combined: handle_about_to_disappear_should_cleanup_and_reset_timer', 0, () => {
      // Arrange
      let unbindReminderCount = 0;
      let stopArrivalCount = 0;
      let stopWeatherCount = 0;
      let unbindPlanStateCount = 0;
      let clearDraftCount = 0;
      let timerValue = 99;
      // Act
      IndexLifecycleHelper.handleAboutToDisappear({
        strategyAdaptationCheckTimer: 1,
        onUnbindReminderSubscriptions: () => {
          unbindReminderCount += 1;
        },
        onStopArrivalEngine: () => {
          stopArrivalCount += 1;
        },
        onStopExecutionWeatherScheduler: () => {
          stopWeatherCount += 1;
        },
        onUnbindPlanState: () => {
          unbindPlanStateCount += 1;
        },
        onClearDialogDraftStorage: () => {
          clearDraftCount += 1;
        },
        onSetStrategyAdaptationCheckTimer: (timer: number) => {
          timerValue = timer;
        }
      });
      // Assert
      expect(unbindReminderCount).assertEqual(1);
      expect(stopArrivalCount).assertEqual(1);
      expect(stopWeatherCount).assertEqual(1);
      expect(unbindPlanStateCount).assertEqual(1);
      expect(clearDraftCount).assertEqual(1);
      expect(timerValue).assertEqual(-1);
    });

    it('normal: handle_about_to_appear_should_enable_companion_mode_when_forced', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      const routeParams = new RouteParamsMock();
      routeParams.planId = 15;
      routeParams.forceCompanionMode = true;
      let companionModeCount = 0;
      let tryStartCount = 0;

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {
          companionModeCount += 1;
        },
        onTryStartEvent: async (_eventId: number) => {
          tryStartCount += 1;
          return true;
        },
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(companionModeCount).assertEqual(1);
      expect(tryStartCount).assertEqual(0);
      done();
    });

    it('invalid: handle_about_to_appear_should_report_unknown_error_when_message_empty', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      vm.rejectReason = '';
      const routeParams = new RouteParamsMock();
      routeParams.planId = 16;
      let errorReason = '';

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (reason: string) => {
          errorReason = reason;
        }
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(errorReason).assertEqual('unknown_error');
      done();
    });

    it('boundary: handle_about_to_disappear_should_keep_timer_when_already_unset', 0, () => {
      // Arrange
      let timerValue = 123;

      // Act
      IndexLifecycleHelper.handleAboutToDisappear({
        strategyAdaptationCheckTimer: -1,
        onUnbindReminderSubscriptions: () => {},
        onStopArrivalEngine: () => {},
        onStopExecutionWeatherScheduler: () => {},
        onUnbindPlanState: () => {},
        onClearDialogDraftStorage: () => {},
        onSetStrategyAdaptationCheckTimer: (timer: number) => {
          timerValue = timer;
        }
      });

      // Assert
      expect(timerValue).assertEqual(123);
    });

    it('boundary: handle_about_to_appear_should_fallback_to_default_title_when_missing', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      const routeParams = new RouteParamsMock();
      routeParams.planId = 17;
      let planTitle = '';

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (title: string) => {
          planTitle = title;
        },
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(planTitle.length > 0).assertTrue();
      done();
    });

    it('combined: handle_about_to_appear_should_skip_planning_refresh_when_auto_refresh_disabled', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      vm.autoRefreshPlanning = false;
      const routeParams = new RouteParamsMock();
      routeParams.planId = 18;
      let startArrivalCount = 0;
      let startAdaptCount = 0;

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {
          startArrivalCount += 1;
        },
        onStartStrategyAdaptationCheck: () => {
          startAdaptCount += 1;
        },
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(vm.refreshPlanningCount).assertEqual(0);
      expect(startArrivalCount).assertEqual(1);
      expect(startAdaptCount).assertEqual(1);
      done();
    });

    it('conflict: handle_about_to_appear_should_fallback_to_forced_companion_when_reminder_id_invalid', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      const routeParams = new RouteParamsMock();
      routeParams.planId = 19;
      routeParams.autoStartFromReminder = true;
      routeParams.forceCompanionMode = true;
      routeParams.reminderEventId = 0;
      let companionModeCount = 0;
      let tryStartCount = 0;

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {
          companionModeCount += 1;
        },
        onTryStartEvent: async (_eventId: number) => {
          tryStartCount += 1;
          return true;
        },
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(companionModeCount).assertEqual(1);
      expect(tryStartCount).assertEqual(0);
      done();
    });

    it('boundary: handle_about_to_appear_should_pass_false_when_is_new_plan_absent', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      const routeParams = new RouteParamsMock();
      routeParams.planId = 20;
      let initPlanId = -1;
      let initIsNewPlan = true;

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (_title: string) => {},
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (planId: number, isNewPlan: boolean) => {
          initPlanId = planId;
          initIsNewPlan = isNewPlan;
        },
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(initPlanId).assertEqual(20);
      expect(initIsNewPlan).assertFalse();
      done();
    });

    it('regression: handle_about_to_appear_should_use_default_title_when_title_is_empty_string', 0, async (done: Function) => {
      // Arrange
      const vm = new LifecycleVmMock();
      const routeParams = new RouteParamsMock();
      routeParams.planId = 21;
      routeParams.title = '';
      let planTitle = '';

      // Act
      IndexLifecycleHelper.handleAboutToAppear({
        uiContext: new UiContextMock(routeParams) as Object as UIContext,
        vm: vm as Object as TimelineViewModel,
        onSetCurrentPlanId: (_planId: number) => {},
        onSetManualWeatherRefresh: (_value: boolean) => {},
        onRefreshUnsavedFlag: () => {},
        onSetPlanTitle: (title: string) => {
          planTitle = title;
        },
        onBindReminderSubscriptions: () => {},
        onSetStrategyMode: (_mode: number) => {},
        onLoadStrategyExplanation: () => {},
        onSetCompanionMode: (_value: boolean) => {},
        onTryStartEvent: async (_eventId: number) => true,
        onStartArrivalReminderEngine: () => {},
        onStartStrategyAdaptationCheck: () => {},
        onInitBacklogExpandedState: async (_planId: number, _isNewPlan: boolean) => {},
        onLoadDataError: (_reason: string) => {}
      });
      await new Promise<void>((resolve: (value: void | PromiseLike<void>) => void) => {
        setTimeout(() => resolve(), 30);
      });

      // Assert
      expect(planTitle).assertEqual('行程详情');
      done();
    });
  });
}
