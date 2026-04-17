import { common } from '@kit.AbilityKit';
import { describe, expect, it } from '@ohos/hypium';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { IUserProfileRepository } from '../main/ets/domain/ports/IUserProfileRepository';
import { NotificationGateway } from '../main/ets/infrastructure/adapters/NotificationGateway';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { IProfileCacheStore, ProfileViewModel } from '../main/ets/viewmodel/ProfileViewModel';
import { ReminderFacade } from '../main/ets/viewmodel/internal/ReminderFacade';
import { ITimelineCompanionHost, TimelineCompanionManager } from '../main/ets/viewmodel/managers/TimelineCompanionManager';
import { ReflowHint } from '../main/ets/viewmodel/types/TimelineTypes';

function cloneProfileAX(profile: UserProfileEntity): UserProfileEntity {
  const clone = new UserProfileEntity();
  clone.profileId = profile.profileId;
  clone.accountId = profile.accountId;
  clone.username = profile.username;
  clone.avatarPath = profile.avatarPath;
  clone.avatarVersion = profile.avatarVersion;
  clone.isInitialized = profile.isInitialized;
  clone.createdAt = profile.createdAt;
  clone.updatedAt = profile.updatedAt;
  return clone;
}

function makeProfileAX(accountId: string, username: string): UserProfileEntity {
  const profile = new UserProfileEntity();
  profile.profileId = `${accountId}_profile`;
  profile.accountId = accountId;
  profile.username = username;
  profile.avatarPath = UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH;
  profile.avatarVersion = 1;
  profile.isInitialized = true;
  profile.createdAt = 1;
  profile.updatedAt = 1;
  return profile;
}

class ProfileRepositoryImplStubAX implements IUserProfileRepository {
  public bindCount: number = 0;
  public getByCalls: number = 0;
  public createCalls: number = 0;
  public updateUsernameCalls: number = 0;
  public updateAvatarCalls: number = 0;
  public throwBind: boolean = false;
  public failGetByAccountId: boolean = false;
  public failCreateDefaultProfile: boolean = false;
  public failUpdateUsername: boolean = false;
  public failUpdateAvatar: boolean = false;
  public cloudProfile: UserProfileEntity | null = null;

  public bindContext(_context: common.Context): void {
    if (this.throwBind) {
      throw new Error('bind_context_failed_ax');
    }
    this.bindCount += 1;
  }

  public async getByAccountId(_accountId: string): Promise<UserProfileEntity | null> {
    this.getByCalls += 1;
    if (this.failGetByAccountId) {
      throw new Error('cloud_get_failed_ax');
    }
    return this.cloudProfile ? cloneProfileAX(this.cloudProfile) : null;
  }

  public async createDefaultProfile(accountId: string): Promise<UserProfileEntity> {
    this.createCalls += 1;
    if (this.failCreateDefaultProfile) {
      throw new Error('cloud_create_failed_ax');
    }
    const profile = makeProfileAX(accountId, `Traveler_${accountId}`);
    this.cloudProfile = cloneProfileAX(profile);
    return cloneProfileAX(profile);
  }

  public async updateUsername(accountId: string, username: string): Promise<UserProfileEntity> {
    this.updateUsernameCalls += 1;
    if (this.failUpdateUsername) {
      throw new Error('update_username_failed_ax');
    }
    const profile = this.cloudProfile ? cloneProfileAX(this.cloudProfile) : makeProfileAX(accountId, 'origin_name_ax');
    profile.accountId = accountId;
    profile.username = username;
    profile.updatedAt = 200;
    this.cloudProfile = cloneProfileAX(profile);
    return cloneProfileAX(profile);
  }

  public async updateAvatar(accountId: string, avatarPath: string, avatarVersion: number): Promise<UserProfileEntity> {
    this.updateAvatarCalls += 1;
    if (this.failUpdateAvatar) {
      throw new Error('update_avatar_failed_ax');
    }
    const profile = this.cloudProfile ? cloneProfileAX(this.cloudProfile) : makeProfileAX(accountId, 'origin_avatar_ax');
    profile.accountId = accountId;
    profile.avatarPath = avatarPath;
    profile.avatarVersion = avatarVersion;
    profile.updatedAt = 300;
    this.cloudProfile = cloneProfileAX(profile);
    return cloneProfileAX(profile);
  }
}

class ProfileCacheBaseAX implements IProfileCacheStore {
  private readonly profileMap: Map<string, UserProfileEntity> = new Map<string, UserProfileEntity>();
  public readCount: number = 0;
  public writeCount: number = 0;
  public clearCount: number = 0;
  public clearAllCount: number = 0;
  public failRead: boolean = false;

  public async readProfile(accountId: string): Promise<UserProfileEntity | null> {
    this.readCount += 1;
    if (this.failRead) {
      throw new Error('cache_read_failed_ax');
    }
    const profile = this.profileMap.get(accountId);
    return profile ? cloneProfileAX(profile) : null;
  }

  public async writeProfile(profile: UserProfileEntity): Promise<void> {
    this.writeCount += 1;
    this.profileMap.set(profile.accountId, cloneProfileAX(profile));
  }

  public async clearProfile(accountId: string): Promise<void> {
    this.clearCount += 1;
    this.profileMap.delete(accountId);
  }

  public clearAllMemory(): void {
    this.clearAllCount += 1;
    this.profileMap.clear();
  }

  public peekProfile(accountId: string): UserProfileEntity | null {
    const profile = this.profileMap.get(accountId);
    return profile ? cloneProfileAX(profile) : null;
  }
}

class ProfileCacheWithBindAX extends ProfileCacheBaseAX {
  public bindCount: number = 0;

  public bindContext(_context: common.Context): void {
    this.bindCount += 1;
  }
}

class ProfileCacheWithoutBindAX extends ProfileCacheBaseAX {}

class CompanionStageViewAX {
  canPause: boolean = false;
  canResume: boolean = false;
}

class CompanionStateMachineAX {
  public readonly stage: CompanionStageViewAX = new CompanionStageViewAX();

  public getPlanStageViewModel(_planId: string): CompanionStageViewAX {
    return this.stage;
  }
}

class CompanionHostAX implements ITimelineCompanionHost {
  public planId: number = 1;
  public latestReflowHint: ReflowHint | null = null;
  public planStateMachine: CompanionStateMachineAX = new CompanionStateMachineAX();
  private schedule: EventEntity[] = [];
  private readonly nextMap: Map<number, EventEntity> = new Map<number, EventEntity>();

  public setSchedule(schedule: EventEntity[]): void {
    this.schedule = schedule;
  }

  public setNext(afterId: number, next: EventEntity): void {
    this.nextMap.set(afterId, next);
  }

  public getOrderedScheduleEvents(): EventEntity[] {
    return this.schedule;
  }

  public getNextExecutableEvent(afterId: number, _schedule?: EventEntity[]): EventEntity | null {
    return this.nextMap.get(afterId) ?? null;
  }
}

function createCompanionEventAX(id: number, name: string): EventEntity {
  const event = new EventEntity(name, 1);
  event.id = id;
  event.status = 1;
  event.completion_status = EventEntity.STATE_PENDING;
  event.actual_start_time = 0;
  event.actual_end_time = 0;
  event.dynamic_start_time = 0;
  event.dynamic_end_time = 0;
  return event;
}

class NotificationGatewayHooksAX {
  private readonly originUpdate: Object;

  constructor() {
    this.originUpdate = Reflect.get(NotificationGateway, 'updateScheduleNotification') as Object;
  }

  public restore(): void {
    Reflect.set(NotificationGateway, 'updateScheduleNotification', this.originUpdate);
  }
}

class NotificationCaptureAX {
  title: string = '';
  content: string = '';
  targetPlanId: number = 0;
  targetEventId: number = 0;
  forceCompanionMode: boolean = false;
}

class FakeContextAX {}

function createFakeContextAX(): common.Context {
  return new FakeContextAX() as Object as common.Context;
}

function createProfileViewModelAX(
  repo: ProfileRepositoryImplStubAX,
  cache: IProfileCacheStore
): ProfileViewModel {
  return new ProfileViewModel(
    repo as Object as UserProfileRepositoryImpl,
    repo as Object as IUserProfileRepository,
    cache
  );
}

export default function phase2BatchAXTest() {
  describe('phase2BatchAX_profile_viewmodel', () => {
    it('normal: bind_context_should_forward_to_repository_and_cache_when_cache_supports_bind', 0, () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      const context = createFakeContextAX();
      // Act
      vm.bindContext(context);
      // Assert
      expect(repo.bindCount).assertEqual(1);
      expect(cache.bindCount).assertEqual(1);
    });

    it('boundary: bind_context_should_skip_cache_binding_when_cache_has_no_bind_method', 0, () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      const context = createFakeContextAX();
      // Act
      vm.bindContext(context);
      // Assert
      expect(repo.bindCount).assertEqual(1);
      expect(cache.writeCount).assertEqual(0);
    });

    it('invalid: bind_context_should_bubble_repository_error', 0, () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.throwBind = true;
      const cache = new ProfileCacheWithBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      const context = createFakeContextAX();
      // Act
      let message = '';
      try {
        vm.bindContext(context);
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      }
      // Assert
      expect(message).assertEqual('bind_context_failed_ax');
    });

    it('normal: get_profile_should_return_a_cloned_snapshot', 0, () => {
      // Arrange
      const vm = createProfileViewModelAX(new ProfileRepositoryImplStubAX(), new ProfileCacheWithoutBindAX());
      Reflect.set(vm as Object, 'profile', makeProfileAX('acc_clone_ax', 'origin_user_ax'));
      // Act
      const snapshot = vm.getProfile() as UserProfileEntity;
      snapshot.username = 'mutated_user_ax';
      const latest = vm.getProfile();
      // Assert
      expect(snapshot.username).assertEqual('mutated_user_ax');
      expect(String(latest?.username || '')).assertEqual('origin_user_ax');
    });

    it('boundary: get_profile_should_return_null_when_no_profile_loaded', 0, () => {
      // Arrange
      const vm = createProfileViewModelAX(new ProfileRepositoryImplStubAX(), new ProfileCacheWithoutBindAX());
      // Act
      const profile = vm.getProfile();
      // Assert
      expect(profile === null).assertTrue();
    });

    it('normal: reset_should_clear_loaded_state_profile_and_cache', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      await vm.bootstrap('acc_reset_ax');
      // Act
      vm.reset();
      const currentAccountId = Reflect.get(vm as Object, 'currentAccountId') as string;
      // Assert
      expect(vm.getState()).assertEqual('loading');
      expect(vm.getProfile() === null).assertTrue();
      expect(currentAccountId).assertEqual('');
      expect(cache.clearAllCount).assertEqual(1);
    });

    it('normal: bootstrap_should_create_default_profile_when_cloud_profile_missing', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.bootstrap('acc_bootstrap_ax');
      const cached = cache.peekProfile('acc_bootstrap_ax');
      // Assert
      expect(repo.createCalls).assertEqual(1);
      expect(String(profile?.accountId || '')).assertEqual('acc_bootstrap_ax');
      expect(String(cached?.accountId || '')).assertEqual('acc_bootstrap_ax');
      expect(vm.getState()).assertEqual('ready');
    });

    it('boundary: bootstrap_should_reset_and_return_null_when_account_is_blank', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      Reflect.set(vm as Object, 'state', 'ready');
      Reflect.set(vm as Object, 'profile', makeProfileAX('acc_blank_ax', 'keep_user_ax'));
      Reflect.set(vm as Object, 'currentAccountId', 'acc_blank_ax');
      // Act
      const profile = await vm.bootstrap('   ');
      const currentAccountId = Reflect.get(vm as Object, 'currentAccountId') as string;
      // Assert
      expect(profile === null).assertTrue();
      expect(vm.getState()).assertEqual('loading');
      expect(vm.getProfile() === null).assertTrue();
      expect(currentAccountId).assertEqual('');
    });

    it('invalid: bootstrap_should_enter_error_state_when_cloud_fails_without_cache', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.failGetByAccountId = true;
      repo.failCreateDefaultProfile = true;
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.bootstrap('acc_bootstrap_fail_ax');
      // Assert
      expect(profile === null).assertTrue();
      expect(vm.getState()).assertEqual('error');
    });

    it('normal: ensure_profile_should_create_cache_and_return_ready_profile', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.ensureProfile('acc_ensure_ax');
      const cached = cache.peekProfile('acc_ensure_ax');
      // Assert
      expect(repo.createCalls).assertEqual(1);
      expect(String(profile?.accountId || '')).assertEqual('acc_ensure_ax');
      expect(String(cached?.accountId || '')).assertEqual('acc_ensure_ax');
      expect(vm.getState()).assertEqual('ready');
    });

    it('boundary: ensure_profile_should_return_null_when_account_is_blank', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.ensureProfile('  ');
      // Assert
      expect(profile === null).assertTrue();
      expect(repo.createCalls).assertEqual(0);
    });

    it('invalid: ensure_profile_should_fallback_to_cached_profile_when_cloud_create_fails', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.failCreateDefaultProfile = true;
      const cache = new ProfileCacheWithoutBindAX();
      await cache.writeProfile(makeProfileAX('acc_cached_ax', 'cached_user_ax'));
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.ensureProfile('acc_cached_ax');
      // Assert
      expect(String(profile?.username || '')).assertEqual('cached_user_ax');
      expect(vm.getState()).assertEqual('offline');
    });

    it('invalid: ensure_profile_should_enter_error_when_cloud_create_fails_without_cache', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.failCreateDefaultProfile = true;
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.ensureProfile('acc_ensure_fail_ax');
      // Assert
      expect(profile === null).assertTrue();
      expect(vm.getState()).assertEqual('error');
    });

    it('normal: update_username_should_persist_profile_and_refresh_cache', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.updateUsername('acc_name_ax', 'Alice_AX');
      const cached = cache.peekProfile('acc_name_ax');
      // Assert
      expect(repo.updateUsernameCalls).assertEqual(1);
      expect(String(profile?.username || '')).assertEqual('Alice_AX');
      expect(String(cached?.username || '')).assertEqual('Alice_AX');
      expect(vm.getState()).assertEqual('ready');
    });

    it('boundary: update_username_should_return_null_for_blank_account', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const vm = createProfileViewModelAX(repo, new ProfileCacheWithoutBindAX());
      // Act
      const profile = await vm.updateUsername('', 'Ignored_AX');
      // Assert
      expect(profile === null).assertTrue();
      expect(repo.updateUsernameCalls).assertEqual(0);
    });

    it('invalid: update_username_should_fallback_to_bootstrap_when_repository_update_fails', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.failUpdateUsername = true;
      repo.cloudProfile = makeProfileAX('acc_name_fallback_ax', 'cloud_name_ax');
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.updateUsername('acc_name_fallback_ax', 'Ignored_AX');
      // Assert
      expect(String(profile?.username || '')).assertEqual('cloud_name_ax');
      expect(repo.getByCalls).assertEqual(1);
    });

    it('normal: update_avatar_should_persist_avatar_fields_and_cache', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.updateAvatar('acc_avatar_ax', 'avatar/new_ax.png', 5);
      const cached = cache.peekProfile('acc_avatar_ax');
      // Assert
      expect(repo.updateAvatarCalls).assertEqual(1);
      expect(String(profile?.avatarPath || '')).assertEqual('avatar/new_ax.png');
      expect(Number(profile?.avatarVersion || 0)).assertEqual(5);
      expect(String(cached?.avatarPath || '')).assertEqual('avatar/new_ax.png');
    });

    it('boundary: update_avatar_should_return_null_for_blank_account', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const vm = createProfileViewModelAX(repo, new ProfileCacheWithoutBindAX());
      // Act
      const profile = await vm.updateAvatar('   ', 'avatar/ignored_ax.png', 7);
      // Assert
      expect(profile === null).assertTrue();
      expect(repo.updateAvatarCalls).assertEqual(0);
    });

    it('invalid: update_avatar_should_fallback_to_bootstrap_when_repository_update_fails', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.failUpdateAvatar = true;
      const fallback = makeProfileAX('acc_avatar_fallback_ax', 'avatar_user_ax');
      fallback.avatarPath = 'avatar/cloud_ax.png';
      fallback.avatarVersion = 9;
      repo.cloudProfile = fallback;
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.updateAvatar('acc_avatar_fallback_ax', 'avatar/ignored_ax.png', 3);
      // Assert
      expect(String(profile?.avatarPath || '')).assertEqual('avatar/cloud_ax.png');
      expect(Number(profile?.avatarVersion || 0)).assertEqual(9);
      expect(repo.getByCalls).assertEqual(1);
    });

    it('conflict: bootstrap_should_prefer_cached_profile_when_cloud_read_and_create_both_fail', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      repo.failGetByAccountId = true;
      repo.failCreateDefaultProfile = true;
      const cache = new ProfileCacheWithoutBindAX();
      await cache.writeProfile(makeProfileAX('acc_conflict_ax', 'cached_conflict_ax'));
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      const profile = await vm.bootstrap('acc_conflict_ax');
      // Assert
      expect(String(profile?.username || '')).assertEqual('cached_conflict_ax');
      expect(vm.getState()).assertEqual('offline');
      expect(repo.createCalls).assertEqual(0);
    });

    it('regression: reset_should_keep_cache_clear_count_incrementing_on_repeat_calls', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      await vm.bootstrap('acc_repeat_reset_ax');
      // Act
      vm.reset();
      vm.reset();
      // Assert
      expect(vm.getState()).assertEqual('loading');
      expect(cache.clearAllCount).assertEqual(2);
      expect(vm.getProfile() === null).assertTrue();
    });

    it('combined: update_profile_flows_should_keep_latest_username_and_avatar_in_cache', 0, async () => {
      // Arrange
      const repo = new ProfileRepositoryImplStubAX();
      const cache = new ProfileCacheWithoutBindAX();
      const vm = createProfileViewModelAX(repo, cache);
      // Act
      await vm.updateUsername('acc_combined_ax', 'combined_user_ax');
      const profile = await vm.updateAvatar('acc_combined_ax', 'avatar/combined_ax.png', 8);
      const cached = cache.peekProfile('acc_combined_ax');
      // Assert
      expect(String(profile?.username || '')).assertEqual('combined_user_ax');
      expect(String(profile?.avatarPath || '')).assertEqual('avatar/combined_ax.png');
      expect(Number(cached?.avatarVersion || 0)).assertEqual(8);
    });
  });

  describe('phase2BatchAX_timeline_companion_manager', () => {
    it('boundary: get_companion_context_should_return_idle_when_schedule_has_no_active_or_startable_event', 0, () => {
      // Arrange
      const completed = createCompanionEventAX(1, 'completed_ax');
      completed.completion_status = EventEntity.STATE_COMPLETED;
      const backlog = createCompanionEventAX(2, 'backlog_ax');
      backlog.status = 0;
      const host = new CompanionHostAX();
      host.setSchedule([completed, backlog]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext();
      // Assert
      expect(context.runtimeState).assertEqual('IDLE');
      expect(context.actions.canStart).assertFalse();
      expect(context.currentEvent === null).assertTrue();
    });

    it('invalid: get_companion_context_should_generate_overdue_ready_hint_when_start_time_has_passed', 0, () => {
      // Arrange
      const pending = createCompanionEventAX(3, 'pending_overdue_ax');
      const nowTs = Date.now();
      pending.dynamic_start_time = nowTs - 15 * 60 * 1000;
      const host = new CompanionHostAX();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext(nowTs);
      // Assert
      expect(context.runtimeState).assertEqual('READY');
      expect((context.hint?.message || '').includes('已超过计划开始')).assertTrue();
      expect(context.actions.canStart).assertTrue();
    });

    it('boundary: get_companion_context_should_keep_hint_null_when_pending_has_no_dynamic_start', 0, () => {
      // Arrange
      const pending = createCompanionEventAX(4, 'pending_no_hint_ax');
      const host = new CompanionHostAX();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const context = manager.getCompanionContext();
      // Assert
      expect(context.runtimeState).assertEqual('READY');
      expect(context.hint === null).assertTrue();
    });

    it('normal: get_real_active_event_should_prefer_explicit_schedule_argument', 0, () => {
      // Arrange
      const hostPending = createCompanionEventAX(5, 'host_pending_ax');
      hostPending.dynamic_end_time = Date.now() + 60000;
      const active = createCompanionEventAX(6, 'active_arg_ax');
      active.actual_start_time = Date.now() - 1000;
      const host = new CompanionHostAX();
      host.setSchedule([hostPending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const event = manager.getRealActiveEvent([active]);
      // Assert
      expect(event !== null).assertTrue();
      expect(event?.id || 0).assertEqual(6);
    });

    it('boundary: get_real_active_event_should_return_pending_when_future_end_time_is_available', 0, () => {
      // Arrange
      const pending = createCompanionEventAX(7, 'pending_window_ax');
      pending.dynamic_end_time = Date.now() + 120000;
      const host = new CompanionHostAX();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const event = manager.getRealActiveEvent();
      // Assert
      expect(event !== null).assertTrue();
      expect(event?.id || 0).assertEqual(7);
    });

    it('invalid: get_real_active_event_should_return_null_when_pending_window_has_expired', 0, () => {
      // Arrange
      const pending = createCompanionEventAX(8, 'pending_expired_ax');
      pending.dynamic_end_time = Date.now() - 1;
      const host = new CompanionHostAX();
      host.setSchedule([pending]);
      const manager = new TimelineCompanionManager(host);
      // Act
      const event = manager.getRealActiveEvent();
      // Assert
      expect(event === null).assertTrue();
    });
  });

  describe('phase2BatchAX_reminder_facade', () => {
    it('normal: update_schedule_notification_should_forward_all_optional_fields_to_gateway', 0, async () => {
      // Arrange
      const hooks = new NotificationGatewayHooksAX();
      const facade = new ReminderFacade();
      const captured = new NotificationCaptureAX();
      ReminderFacade.setDispatcherForTest(null);
      try {
        Reflect.set(
          NotificationGateway,
          'updateScheduleNotification',
          async (
            title: string,
            content: string,
            targetPlanId?: number,
            targetEventId?: number,
            forceCompanionMode?: boolean
          ): Promise<void> => {
            captured.title = title;
            captured.content = content;
            captured.targetPlanId = targetPlanId ?? 0;
            captured.targetEventId = targetEventId ?? 0;
            captured.forceCompanionMode = forceCompanionMode ?? false;
          }
        );
        // Act
        await facade.updateScheduleNotification('current_ax', 'next_ax', 11, 22, true);
      } finally {
        hooks.restore();
        ReminderFacade.setDispatcherForTest(null);
      }
      // Assert
      expect(captured.title).assertEqual('current_ax');
      expect(captured.content).assertEqual('next_ax');
      expect(captured.targetPlanId).assertEqual(11);
      expect(captured.targetEventId).assertEqual(22);
      expect(captured.forceCompanionMode).assertTrue();
    });

    it('boundary: set_dispatcher_for_test_null_should_restore_gateway_branch', 0, async () => {
      // Arrange
      const hooks = new NotificationGatewayHooksAX();
      const facade = new ReminderFacade();
      let dispatcherCalls = 0;
      let gatewayCalls = 0;
      ReminderFacade.setDispatcherForTest(async (): Promise<void> => {
        dispatcherCalls += 1;
      });
      try {
        Reflect.set(NotificationGateway, 'updateScheduleNotification', async (): Promise<void> => {
          gatewayCalls += 1;
        });
        ReminderFacade.setDispatcherForTest(null);
        // Act
        await facade.updateScheduleNotification('restore_ax', 'gateway_ax');
      } finally {
        hooks.restore();
        ReminderFacade.setDispatcherForTest(null);
      }
      // Assert
      expect(dispatcherCalls).assertEqual(0);
      expect(gatewayCalls).assertEqual(1);
    });

    it('invalid: update_schedule_notification_should_bubble_dispatcher_error', 0, async () => {
      // Arrange
      const facade = new ReminderFacade();
      ReminderFacade.setDispatcherForTest(async (): Promise<void> => {
        throw new Error('dispatcher_failed_ax');
      });
      // Act
      let message = '';
      try {
        await facade.updateScheduleNotification('x', 'y');
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        ReminderFacade.setDispatcherForTest(null);
      }
      // Assert
      expect(message).assertEqual('dispatcher_failed_ax');
    });
  });
}
