import { describe, expect, it } from '@ohos/hypium';
import { UserProfileEntity } from '../main/ets/domain/entity/UserProfileEntity';
import { IUserProfileRepository } from '../main/ets/domain/ports/IUserProfileRepository';
import { PlanItem, PlanRepositoryImpl } from '../main/ets/infrastructure/persistence/PlanRepositoryImpl';
import { UserProfileRepositoryImpl } from '../main/ets/infrastructure/persistence/UserProfileRepositoryImpl';
import { EventEntity } from '../main/ets/model/entity/EventEntity';
import { TimelineDatePolicy } from '../main/ets/domain/policy/TimelineDatePolicy';
import { PlanAppService } from '../main/ets/viewmodel/PlanAppService';
import { IProfileCacheStore, ProfileViewModel } from '../main/ets/viewmodel/ProfileViewModel';
import { TimelineViewModel } from '../main/ets/viewmodel/TimelineViewModel';
import { TimelineInteractionHelper } from '../main/ets/viewmodel/TimelineInteractionHelper';
import { ReminderFacade } from '../main/ets/viewmodel/internal/ReminderFacade';

interface UpdateCallItemBG {
  id: number;
  status: number;
}

interface ReminderDispatchCaptureBG {
  title: string;
  content: string;
  targetPlanId: number;
  targetEventId: number;
  forceCompanionMode: boolean;
}

class PlanRepoHooksBG {
  private readonly originCreatePlan: Object;
  private readonly originPurgeOldTrash: Object;
  private readonly originGetPlanList: Object;
  private readonly originGetArchivedPlans: Object;
  private readonly originGetTrashPlans: Object;
  private readonly originUpdatePlanStatus: Object;
  private readonly originSoftDeletePlan: Object;
  private readonly originRestorePlan: Object;
  private readonly originHardDeletePlan: Object;

  constructor() {
    this.originCreatePlan = Reflect.get(PlanRepositoryImpl, 'createPlan') as Object;
    this.originPurgeOldTrash = Reflect.get(PlanRepositoryImpl, 'purgeOldTrash') as Object;
    this.originGetPlanList = Reflect.get(PlanRepositoryImpl, 'getPlanList') as Object;
    this.originGetArchivedPlans = Reflect.get(PlanRepositoryImpl, 'getArchivedPlans') as Object;
    this.originGetTrashPlans = Reflect.get(PlanRepositoryImpl, 'getTrashPlans') as Object;
    this.originUpdatePlanStatus = Reflect.get(PlanRepositoryImpl, 'updatePlanStatus') as Object;
    this.originSoftDeletePlan = Reflect.get(PlanRepositoryImpl, 'softDeletePlan') as Object;
    this.originRestorePlan = Reflect.get(PlanRepositoryImpl, 'restorePlan') as Object;
    this.originHardDeletePlan = Reflect.get(PlanRepositoryImpl, 'hardDeletePlan') as Object;
  }

  public restore(): void {
    Reflect.set(PlanRepositoryImpl, 'createPlan', this.originCreatePlan);
    Reflect.set(PlanRepositoryImpl, 'purgeOldTrash', this.originPurgeOldTrash);
    Reflect.set(PlanRepositoryImpl, 'getPlanList', this.originGetPlanList);
    Reflect.set(PlanRepositoryImpl, 'getArchivedPlans', this.originGetArchivedPlans);
    Reflect.set(PlanRepositoryImpl, 'getTrashPlans', this.originGetTrashPlans);
    Reflect.set(PlanRepositoryImpl, 'updatePlanStatus', this.originUpdatePlanStatus);
    Reflect.set(PlanRepositoryImpl, 'softDeletePlan', this.originSoftDeletePlan);
    Reflect.set(PlanRepositoryImpl, 'restorePlan', this.originRestorePlan);
    Reflect.set(PlanRepositoryImpl, 'hardDeletePlan', this.originHardDeletePlan);
  }
}

class ProfileRepoStubBG implements IUserProfileRepository {
  public createCalls: number = 0;
  public getByCalls: number = 0;
  public failCreate: boolean = false;
  public failGetBy: boolean = false;
  public profileFromCloud: UserProfileEntity | null = null;

  public bindContext(_context: Object): void {
    return;
  }

  public async getByAccountId(_accountId: string): Promise<UserProfileEntity | null> {
    this.getByCalls += 1;
    if (this.failGetBy) {
      throw new Error('cloud_get_failed_bg');
    }
    return this.profileFromCloud ? cloneProfileBG(this.profileFromCloud) : null;
  }

  public async createDefaultProfile(accountId: string): Promise<UserProfileEntity> {
    this.createCalls += 1;
    if (this.failCreate) {
      throw new Error('cloud_create_failed_bg');
    }
    const profile = createProfileBG(accountId, `default_${accountId}`);
    this.profileFromCloud = cloneProfileBG(profile);
    return cloneProfileBG(profile);
  }

  public async updateUsername(accountId: string, username: string): Promise<UserProfileEntity> {
    const profile = createProfileBG(accountId, username);
    this.profileFromCloud = cloneProfileBG(profile);
    return profile;
  }

  public async updateAvatar(accountId: string, avatarPath: string, avatarVersion: number): Promise<UserProfileEntity> {
    const profile = createProfileBG(accountId, `avatar_${accountId}`);
    profile.avatarPath = avatarPath;
    profile.avatarVersion = avatarVersion;
    this.profileFromCloud = cloneProfileBG(profile);
    return profile;
  }
}

class ProfileCacheStubBG implements IProfileCacheStore {
  public failRead: boolean = false;
  public failWrite: boolean = false;
  public readCalls: number = 0;
  public clearAllCalls: number = 0;
  private readonly map: Map<string, UserProfileEntity> = new Map<string, UserProfileEntity>();

  public async readProfile(accountId: string): Promise<UserProfileEntity | null> {
    this.readCalls += 1;
    if (this.failRead) {
      throw new Error('cache_read_failed_bg');
    }
    const value = this.map.get(accountId);
    return value ? cloneProfileBG(value) : null;
  }

  public async writeProfile(profile: UserProfileEntity): Promise<void> {
    if (this.failWrite) {
      throw new Error('cache_write_failed_bg');
    }
    this.map.set(profile.accountId, cloneProfileBG(profile));
  }

  public async clearProfile(accountId: string): Promise<void> {
    this.map.delete(accountId);
  }

  public clearAllMemory(): void {
    this.clearAllCalls += 1;
    this.map.clear();
  }
}

interface ProfileViewModelPrivateBG {
  normalizeError: (error: Object) => string;
}

class MessageHolderBG {
  message: string = '';
}

class CyclicErrorBG {
  self: Object | null = null;
}

class TimelineVmPlanStartStubBG {
  planStartDate: number = 0;
}

function createPlanItemBG(id: number, status: number): PlanItem {
  return {
    id: id,
    title: `plan_${id}`,
    createdAt: 1700000000000 + id,
    startDate: 1700000000000,
    status: status,
    deleteTime: 0,
    enableAutoAmapRoute: 1
  };
}

function createProfileBG(accountId: string, username: string): UserProfileEntity {
  const profile = new UserProfileEntity();
  profile.profileId = `profile_${accountId}`;
  profile.accountId = accountId;
  profile.username = username;
  profile.avatarPath = UserProfileRepositoryImpl.DEFAULT_AVATAR_PATH;
  profile.avatarVersion = 1;
  profile.isInitialized = true;
  profile.createdAt = 1;
  profile.updatedAt = 1;
  return profile;
}

function cloneProfileBG(profile: UserProfileEntity): UserProfileEntity {
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

function invokeResolvePlannedStartTsBG(vm: TimelineViewModel, item: EventEntity): number {
  const fn = Reflect.get(TimelineInteractionHelper as Object, 'resolvePlannedStartTs') as (a: TimelineViewModel, b: EventEntity) => number;
  return fn(vm, item);
}

export default function phase2BatchBGTest() {
  describe('phase2BatchBG_plan_app_service', () => {
    it('normal: default_repository_path_should_delegate_all_operations_to_plan_repository_impl', 0, async () => {
      // Arrange
      const hooks = new PlanRepoHooksBG();
      PlanAppService.setPlanRepositoryForTest(null);
      const service = PlanAppService.getInstance();
      let createArgs = '';
      const statusCalls: UpdateCallItemBG[] = [];
      const softDeleteCalls: number[] = [];
      const restoreCalls: number[] = [];
      const hardDeleteCalls: number[] = [];
      let purgeCount = 0;
      try {
        Reflect.set(PlanRepositoryImpl, 'createPlan', async (title: string, startDate: number): Promise<number> => {
          createArgs = `${title}_${startDate}`;
          return 2026;
        });
        Reflect.set(PlanRepositoryImpl, 'purgeOldTrash', async (): Promise<number> => {
          purgeCount += 1;
          return 0;
        });
        Reflect.set(PlanRepositoryImpl, 'getPlanList', async (): Promise<PlanItem[]> => {
          return [createPlanItemBG(1, 0), createPlanItemBG(2, 2)];
        });
        Reflect.set(PlanRepositoryImpl, 'getArchivedPlans', async (): Promise<PlanItem[]> => {
          return [createPlanItemBG(3, 2)];
        });
        Reflect.set(PlanRepositoryImpl, 'getTrashPlans', async (): Promise<PlanItem[]> => {
          return [createPlanItemBG(4, 0)];
        });
        Reflect.set(PlanRepositoryImpl, 'updatePlanStatus', async (id: number, status: number): Promise<void> => {
          statusCalls.push({ id: id, status: status });
        });
        Reflect.set(PlanRepositoryImpl, 'softDeletePlan', async (id: number): Promise<void> => {
          softDeleteCalls.push(id);
        });
        Reflect.set(PlanRepositoryImpl, 'restorePlan', async (id: number): Promise<void> => {
          restoreCalls.push(id);
        });
        Reflect.set(PlanRepositoryImpl, 'hardDeletePlan', async (id: number): Promise<void> => {
          hardDeleteCalls.push(id);
        });

        // Act
        const planId = await service.createPlan('bg_plan', 1700000000100);
        const visible = await service.loadVisiblePlans();
        const archived = await service.loadArchivedPlans();
        const trash = await service.loadTrashPlans();
        await service.archivePlan(11);
        await service.activatePlan(12);
        await service.softDeletePlan(13);
        await service.restorePlan(14);
        await service.hardDeletePlan(15);

        // Assert
        expect(planId).assertEqual(2026);
        expect(createArgs).assertEqual('bg_plan_1700000000100');
        expect(visible.length).assertEqual(1);
        expect(archived.length).assertEqual(1);
        expect(trash.length).assertEqual(1);
        expect(purgeCount).assertEqual(3);
        expect(statusCalls.length).assertEqual(2);
        expect(statusCalls[0].id).assertEqual(11);
        expect(statusCalls[0].status).assertEqual(2);
        expect(statusCalls[1].id).assertEqual(12);
        expect(statusCalls[1].status).assertEqual(0);
        expect(softDeleteCalls[0]).assertEqual(13);
        expect(restoreCalls[0]).assertEqual(14);
        expect(hardDeleteCalls[0]).assertEqual(15);
      } finally {
        hooks.restore();
        PlanAppService.setPlanRepositoryForTest(null);
      }
    });

    it('combined: singleton_should_keep_same_instance_when_swapping_test_repo', 0, () => {
      // Arrange
      const before = PlanAppService.getInstance();
      PlanAppService.setPlanRepositoryForTest(null);
      // Act
      const after = PlanAppService.getInstance();
      // Assert
      expect(before === after).assertTrue();
    });
  });

  describe('phase2BatchBG_reminder_facade', () => {
    it('normal: update_schedule_notification_should_use_dispatcher_for_test_when_present', 0, async () => {
      // Arrange
      const facade = new ReminderFacade();
      const capture: ReminderDispatchCaptureBG = {
        title: '',
        content: '',
        targetPlanId: -1,
        targetEventId: -1,
        forceCompanionMode: false
      };
      ReminderFacade.setDispatcherForTest(
        async (
          title: string,
          content: string,
          targetPlanId?: number,
          targetEventId?: number,
          forceCompanionMode?: boolean
        ): Promise<void> => {
          capture.title = title;
          capture.content = content;
          capture.targetPlanId = targetPlanId ?? -1;
          capture.targetEventId = targetEventId ?? -1;
          capture.forceCompanionMode = forceCompanionMode ?? false;
        }
      );

      try {
        // Act
        await facade.updateScheduleNotification('title_bg', 'content_bg', 6, 7, true);
      } finally {
        ReminderFacade.setDispatcherForTest(null);
      }

      // Assert
      expect(capture.title).assertEqual('title_bg');
      expect(capture.content).assertEqual('content_bg');
      expect(capture.targetPlanId).assertEqual(6);
      expect(capture.targetEventId).assertEqual(7);
      expect(capture.forceCompanionMode).assertTrue();
    });
  });

  describe('phase2BatchBG_profile_viewmodel', () => {
    it('normal: get_instance_should_return_singleton_reference', 0, () => {
      // Arrange
      // Act
      const first = ProfileViewModel.getInstance();
      const second = ProfileViewModel.getInstance();
      // Assert
      expect(first === second).assertTrue();
    });

    it('boundary: bootstrap_should_use_existing_cloud_profile_without_creating_default', 0, async () => {
      // Arrange
      const repo = new ProfileRepoStubBG();
      repo.profileFromCloud = createProfileBG('acc_bg', 'cloud_user_bg');
      const cache = new ProfileCacheStubBG();
      const vm = new ProfileViewModel(
        repo as Object as UserProfileRepositoryImpl,
        repo,
        cache
      );

      // Act
      const profile = await vm.bootstrap('acc_bg');

      // Assert
      expect(String(profile?.username || '')).assertEqual('cloud_user_bg');
      expect(repo.getByCalls).assertEqual(1);
      expect(repo.createCalls).assertEqual(0);
      expect(vm.getState()).assertEqual('ready');
    });

    it('invalid: bootstrap_should_ignore_cache_read_error_and_still_return_cloud_profile', 0, async () => {
      // Arrange
      const repo = new ProfileRepoStubBG();
      repo.profileFromCloud = createProfileBG('acc_cache_error_bg', 'cloud_after_cache_error_bg');
      const cache = new ProfileCacheStubBG();
      cache.failRead = true;
      const vm = new ProfileViewModel(
        repo as Object as UserProfileRepositoryImpl,
        repo,
        cache
      );

      // Act
      const profile = await vm.bootstrap('acc_cache_error_bg');

      // Assert
      expect(String(profile?.username || '')).assertEqual('cloud_after_cache_error_bg');
      expect(vm.getState()).assertEqual('ready');
      expect(cache.readCalls).assertEqual(1);
    });

    it('invalid: ensure_profile_should_enter_error_when_cloud_create_and_cache_read_both_fail', 0, async () => {
      // Arrange
      const repo = new ProfileRepoStubBG();
      repo.failCreate = true;
      const cache = new ProfileCacheStubBG();
      cache.failRead = true;
      const vm = new ProfileViewModel(
        repo as Object as UserProfileRepositoryImpl,
        repo,
        cache
      );

      // Act
      const profile = await vm.ensureProfile('acc_ensure_error_bg');

      // Assert
      expect(profile === null).assertTrue();
      expect(vm.getState()).assertEqual('error');
      expect(cache.readCalls).assertEqual(1);
    });

    it('normal: normalize_error_should_extract_message_from_plain_object', 0, () => {
      // Arrange
      const vm = new ProfileViewModel() as Object as ProfileViewModelPrivateBG;
      const errorInfo = new MessageHolderBG();
      errorInfo.message = 'plain_object_error_bg';

      // Act
      const message = vm.normalizeError(errorInfo as Object);

      // Assert
      expect(message).assertEqual('plain_object_error_bg');
    });

    it('regression: normalize_error_should_return_error_message_for_error_instance', 0, () => {
      // Arrange
      const vm = new ProfileViewModel() as Object as ProfileViewModelPrivateBG;
      // Act
      const message = vm.normalizeError(new Error('error_instance_bg') as Object);
      // Assert
      expect(message).assertEqual('error_instance_bg');
    });

    it('invalid: normalize_error_should_fallback_when_json_stringify_throws', 0, () => {
      // Arrange
      const vm = new ProfileViewModel() as Object as ProfileViewModelPrivateBG;
      const cyclic = new CyclicErrorBG();
      cyclic.self = cyclic as Object;

      // Act
      const message = vm.normalizeError(cyclic as Object);

      // Assert
      expect(message).assertEqual('profile_error');
    });
  });

  describe('phase2BatchBG_timeline_interaction_helper', () => {
    it('boundary: resolve_planned_start_ts_should_return_zero_when_plan_start_date_invalid', 0, () => {
      // Arrange
      const vm = new TimelineVmPlanStartStubBG() as Object as TimelineViewModel;
      const item = new EventEntity('spot_bg', 1);
      item.computed_time = '09:00';

      // Act
      const ts = invokeResolvePlannedStartTsBG(vm, item);

      // Assert
      expect(ts).assertEqual(0);
    });

    it('invalid: resolve_planned_start_ts_should_return_zero_when_time_text_invalid', 0, () => {
      // Arrange
      const vmState = new TimelineVmPlanStartStubBG();
      vmState.planStartDate = 1700000000000;
      const vm = vmState as Object as TimelineViewModel;
      const item = new EventEntity('spot_invalid_bg', 1);
      item.computed_time = 'bad_time';
      item.fixed_start_time = '10:00';

      // Act
      const ts = invokeResolvePlannedStartTsBG(vm, item);

      // Assert
      expect(ts).assertEqual(0);
    });

    it('normal: resolve_planned_start_ts_should_prefer_computed_time_over_fixed_time', 0, () => {
      // Arrange
      const vmState = new TimelineVmPlanStartStubBG();
      vmState.planStartDate = 1700000000000;
      const vm = vmState as Object as TimelineViewModel;
      const item = new EventEntity('spot_ok_bg', 1);
      item.day_offset = 2;
      item.dynamic_day_offset = 3;
      item.computed_time = '09:30';
      item.fixed_start_time = '12:00';
      const expected = TimelineDatePolicy.buildPlannedTimestamp(vm.planStartDate, 3, '09:30');

      // Act
      const ts = invokeResolvePlannedStartTsBG(vm, item);

      // Assert
      expect(ts).assertEqual(expected);
    });

    it('conflict: resolve_planned_start_ts_should_fallback_to_fixed_time_when_computed_empty', 0, () => {
      // Arrange
      const vmState = new TimelineVmPlanStartStubBG();
      vmState.planStartDate = 1700000000000;
      const vm = vmState as Object as TimelineViewModel;
      const item = new EventEntity('spot_fixed_bg', 1);
      item.day_offset = 1;
      item.dynamic_day_offset = -1;
      item.computed_time = '';
      item.fixed_start_time = '08:15';
      const expected = TimelineDatePolicy.buildPlannedTimestamp(vm.planStartDate, -1, '08:15');
      // Act
      const ts = invokeResolvePlannedStartTsBG(vm, item);
      // Assert
      expect(ts).assertEqual(expected);
    });
  });
}
