import { hilog } from '@kit.PerformanceAnalysisKit';
import { EventEntity } from '../../model/entity/EventEntity';
import { TimelineViewModel } from '../../viewmodel/TimelineViewModel';
import { PlanRepositoryImpl, PlanItem } from '../persistence/PlanRepositoryImpl';
import { EventRepositoryImpl } from '../persistence/EventRepositoryImpl';
import type { TravelPlanItem } from '../../model/interface/IStandardEvent';
import {
  AMapLocation,
  AMapLocationErrorInfo,
  AMapLocationManagerImpl,
  AMapLocationOption,
  AMapLocationType,
  DPoint,
  GeoFence,
  GeoFenceClient,
  GeoFenceListener,
  IAMapLocationListener
} from '@amap/amap_lbs_location';
import geoLocationManager from '@ohos.geoLocationManager';
import { ArrivalLiveActivityBridge, ArrivalLiveStatus } from '../../common/utils/ArrivalLiveActivityBridge';
import { ArrivalReminderStore } from '../../common/utils/arrival/ArrivalReminderStore';
import { TimelineExecutionState } from '../../domain/policy/TimelineExecutionState';
import { TimelineDatePolicy } from '../../domain/policy/TimelineDatePolicy';
import { NotificationGateway } from '../adapters/NotificationGateway';
import { GeoFenceListLike } from './ArrivalReminderDeclarations';

const TAG = 'ArrivalReminderEngine';

export type ArrivalReminderAction = 'dismiss' | 'open_page' | 'start';

export interface ArrivalReminderPayload {
  seq: number;
  planId: number;
  eventId: number;
  placeName: string;
  distanceMeters: number;
  triggerAt: number;
}

interface CandidateScore {
  event: EventEntity;
  order: number;
  timeDelta: number;
  distance: number;
}

interface PlanCandidateCache {
  scheduleCount: number;
  pendingCount: number;
  activeCount: number;
  withCoordinateCount: number;
  eligibleCount: number;
  candidates: EventEntity[];
  timeDeltaByEventId: Map<number, number>;
}

export interface LastKnownLocationSnapshot {
  latitude: number;
  longitude: number;
  accuracy: number;
  speed: number;
  timestamp: number;
}

export class ArrivalReminderEngine {
  private static instance: ArrivalReminderEngine | null = null;

  private vm: TimelineViewModel | null = null;
  private context: Context | null = null;
  private activePagePlanId: number = -1;

  private locationManager: AMapLocationManagerImpl | null = null;
  private geoFenceClient: GeoFenceClient | null = null;
  private locationListener: IAMapLocationListener | null = null;
  private geoFenceListener: GeoFenceListener | null = null;

  private lastLocation: AMapLocation | null = null;
  private lastReminderEventId: number = -1;
  private reminderLockUntilTs: number = 0;
  private pendingBatchTimer: number = -1;
  private isRefreshingCandidates: boolean = false;
  private lastRefreshTs: number = 0;

  private readonly pendingCandidateIds: Set<number> = new Set<number>();
  private readonly geoFenceStatus: Map<string, number> = new Map<string, number>();
  private readonly geoFenceEnterTs: Map<string, number> = new Map<string, number>();
  private readonly directEnterTs: Map<number, number> = new Map<number, number>();
  private readonly lastReminderByEvent: Map<number, number> = new Map<number, number>();

  private monitoredEvents: EventEntity[] = [];
  private readonly eventPlanIdMap: Map<number, number> = new Map<number, number>();
  private readonly eventOrderMap: Map<number, number> = new Map<number, number>();
  private readonly eventTimeDeltaMap: Map<number, number> = new Map<number, number>();
  private fenceIdSnapshot: Set<string> = new Set<string>();
  private readonly planCandidateCache: Map<number, PlanCandidateCache> = new Map<number, PlanCandidateCache>();
  private activePlanSnapshot: Set<number> = new Set<number>();
  private lastFullResyncTs: number = 0;
  private hasAnyActiveEvent: boolean = false;

  private readonly fenceRadiusMeters: number = 220;
  private readonly dwellWindowMs: number = 0;
  private readonly batchWindowMs: number = 1_500;
  private readonly reminderSwitchLockMs: number = 30_000;
  private readonly eventCooldownMs: number = 60_000;
  private readonly dismissLockMs: number = 5 * 60_000;
  private readonly openPageLockMs: number = 90_000;
  private readonly startLockMs: number = 10 * 60_000;
  private readonly maxAllowedSpeedMetersPerSec: number = 20;
  private readonly maxAllowedAccuracyMeters: number = 400;
  private readonly refreshIntervalMs: number = 15_000;
  private readonly fullResyncIntervalMs: number = 5 * 60_000;
  private readonly currentTimeBandMs: number = 6 * 60 * 60 * 1000;

  public static isLocationSampleAccepted(
    latitude: number,
    longitude: number,
    accuracy: number,
    speed: number,
    maxAccuracyMeters: number,
    maxSpeedMetersPerSec: number
  ): boolean {
    const validCoordinate = Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      !(latitude === 0 && longitude === 0) &&
      latitude >= -90 && latitude <= 90 &&
      longitude >= -180 && longitude <= 180;
    if (!validCoordinate) {
      return false;
    }
    if (Number.isFinite(accuracy) && accuracy > maxAccuracyMeters) {
      return false;
    }
    if (Number.isFinite(speed) && speed > maxSpeedMetersPerSec) {
      return false;
    }
    return true;
  }

  public static isEventOutOfCooldown(lastTriggerTs: number, nowTs: number, cooldownMs: number): boolean {
    if (lastTriggerTs <= 0) {
      return true;
    }
    return nowTs - lastTriggerTs >= cooldownMs;
  }

  public static resolveCandidateTimeDelta(
    cachedTimeDelta: number | undefined,
    dynamicStartTime: number,
    nowTs: number
  ): number {
    if (Number.isFinite(cachedTimeDelta) && (cachedTimeDelta as number) >= 0) {
      return cachedTimeDelta as number;
    }
    if (dynamicStartTime > 0) {
      return Math.abs(dynamicStartTime - nowTs);
    }
    return Number.MAX_SAFE_INTEGER;
  }

  public static getInstance(): ArrivalReminderEngine {
    if (!ArrivalReminderEngine.instance) {
      ArrivalReminderEngine.instance = new ArrivalReminderEngine();
    }
    return ArrivalReminderEngine.instance;
  }

  public getLastKnownLocation(): LastKnownLocationSnapshot | null {
    if (!this.lastLocation) {
      return null;
    }
    return {
      latitude: this.lastLocation.latitude,
      longitude: this.lastLocation.longitude,
      accuracy: this.lastLocation.accuracy,
      speed: this.lastLocation.speed,
      timestamp: Date.now()
    };
  }

  public start(planId: number, vm: TimelineViewModel, context: Context): void {
    this.ensureStorageDefaults();
    this.activePagePlanId = planId > 0 ? planId : 0;
    this.vm = vm;
    this.context = context;

    if (!this.ensureClients()) {
      return;
    }

    void this.refreshFencesNow('start');
    this.ensureReminderConsistency();
    try {
      this.locationManager?.startUpdatingLocation();
      hilog.info(0x0000, TAG, `[ARRIVAL][start] activePagePlanId=${this.activePagePlanId}`);
    } catch (error) {
      hilog.error(0x0000, TAG, `[ARRIVAL][start_failed] reason=${JSON.stringify(error)}`);
    }
  }

  public stop(): void {
    if (this.lastReminderEventId > 0) {
      this.publishLiveActivityState(this.lastReminderEventId, 'ENDED');
    }
    if (this.pendingBatchTimer >= 0) {
      clearTimeout(this.pendingBatchTimer);
      this.pendingBatchTimer = -1;
    }
    this.pendingCandidateIds.clear();
    this.geoFenceStatus.clear();
    this.geoFenceEnterTs.clear();
    this.directEnterTs.clear();
    this.lastLocation = null;
    this.planCandidateCache.clear();
    this.activePlanSnapshot.clear();
    this.lastFullResyncTs = 0;
    this.hasAnyActiveEvent = false;

    try {
      this.locationManager?.stopUpdatingLocation();
    } catch (_error) {
    }
    try {
      this.geoFenceClient?.removeGeoFence();
    } catch (_error) {
    }
    hilog.info(0x0000, TAG, '[ARRIVAL][stop]');
  }

  public async refreshFencesNow(reason: string = 'manual'): Promise<void> {
    if (!this.geoFenceClient || this.isRefreshingCandidates) {
      return;
    }
    this.isRefreshingCandidates = true;
    try {
      const now = Date.now();
      const dirtyPlanIds: Set<number> = new Set<number>();
      const eventDirty = EventRepositoryImpl.consumeDirtyPlanIds();
      for (let i = 0; i < eventDirty.length; i++) {
        dirtyPlanIds.add(eventDirty[i]);
      }
      const planDirty = PlanRepositoryImpl.consumeDirtyPlanIds();
      for (let i = 0; i < planDirty.length; i++) {
        dirtyPlanIds.add(planDirty[i]);
      }

      const needFullResync = reason === 'start' || now - this.lastFullResyncTs >= this.fullResyncIntervalMs;
      let plansScanned = 0;
      let activePlanIdSet: Set<number> = new Set<number>();
      const canUseSnapshot = !needFullResync && this.activePlanSnapshot.size > 0;
      if (canUseSnapshot) {
        activePlanIdSet = new Set<number>(this.activePlanSnapshot);
        if (dirtyPlanIds.size > 0) {
          await this.applyDirtyPlansToActiveSnapshot(activePlanIdSet, dirtyPlanIds);
        }
      } else {
        const plans: PlanItem[] = await PlanRepositoryImpl.getPlanList();
        plansScanned = plans.length;
        for (let i = 0; i < plans.length; i++) {
          if (this.isPlanActiveForReminder(plans[i])) {
            activePlanIdSet.add(plans[i].id);
          }
        }
      }

      this.prunePlanCandidateCache(activePlanIdSet);

      const refreshPlanIds: number[] = [];
      const activePlanIdsForLoop = Array.from(activePlanIdSet.values());
      for (let i = 0; i < activePlanIdsForLoop.length; i++) {
        const planId = activePlanIdsForLoop[i];
        if (needFullResync || !this.planCandidateCache.has(planId) || dirtyPlanIds.has(planId)) {
          refreshPlanIds.push(planId);
        }
      }
      const isSamePlanSet = this.isSamePlanSet(activePlanIdSet, this.activePlanSnapshot);
      if (!needFullResync && refreshPlanIds.length === 0 && isSamePlanSet) {
        this.lastRefreshTs = now;
        hilog.info(0x0000, TAG, `[ARRIVAL][refresh_fences_skip] reason=${reason}, activePlans=${activePlanIdsForLoop.length}`);
        return;
      }
      if (refreshPlanIds.length > 0) {
        const planMap: Map<number, PlanItem> = new Map<number, PlanItem>();
        const activePlanIds = activePlanIdsForLoop;
        if (activePlanIds.length > 0) {
          const activePlanRows: (PlanItem | undefined)[] = await Promise.all(activePlanIds.map((planId: number): Promise<PlanItem | undefined> => PlanRepositoryImpl.getPlanById(planId)));
          for (let i = 0; i < activePlanRows.length; i++) {
            const plan = activePlanRows[i];
            if (!plan || !this.isPlanActiveForReminder(plan)) {
              continue;
            }
            planMap.set(plan.id, plan);
          }
        }
        const refreshedEvents = await Promise.all(refreshPlanIds.map((planId: number) => EventRepositoryImpl.getAllEvents(planId)));
        for (let i = 0; i < refreshPlanIds.length; i++) {
          const planId = refreshPlanIds[i];
          const plan = planMap.get(planId);
          if (!plan) {
            continue;
          }
          const cache = this.buildPlanCandidateCache(
            plan,
            refreshedEvents[i] ?? [],
            now
          );
          this.planCandidateCache.set(planId, cache);
        }
      }
      if (needFullResync) {
        this.lastFullResyncTs = now;
      }
      this.activePlanSnapshot = activePlanIdSet;

      let scheduleCount = 0;
      let pendingCount = 0;
      let activeCount = 0;
      let withCoordinateCount = 0;
      let eligibleCount = 0;
      const globalCandidates: EventEntity[] = [];
      const nextPlanMap: Map<number, number> = new Map<number, number>();
      const nextOrderMap: Map<number, number> = new Map<number, number>();
      const nextTimeDeltaMap: Map<number, number> = new Map<number, number>();
      const nextFenceIds: Set<string> = new Set<string>();

      let globalOrder = 0;
      for (let p = 0; p < activePlanIdsForLoop.length; p++) {
        const planId = activePlanIdsForLoop[p];
        const cache = this.planCandidateCache.get(planId);
        if (!cache) {
          continue;
        }
        scheduleCount += cache.scheduleCount;
        pendingCount += cache.pendingCount;
        activeCount += cache.activeCount;
        withCoordinateCount += cache.withCoordinateCount;
        eligibleCount += cache.eligibleCount;
        for (let i = 0; i < cache.candidates.length; i++) {
          const event = cache.candidates[i];
          const timeDelta = ArrivalReminderEngine.resolveCandidateTimeDelta(
            cache.timeDeltaByEventId.get(event.id),
            event.dynamic_start_time,
            now
          );
          globalCandidates.push(event);
          nextPlanMap.set(event.id, planId);
          nextOrderMap.set(event.id, globalOrder);
          nextTimeDeltaMap.set(event.id, timeDelta);
          nextFenceIds.add(`${planId}:${event.id}:${event.latitude.toFixed(5)}:${event.longitude.toFixed(5)}`);
          globalOrder += 1;
        }
      }

      this.monitoredEvents = globalCandidates;
      this.hasAnyActiveEvent = activeCount > 0;
      this.eventPlanIdMap.clear();
      this.eventOrderMap.clear();
      this.eventTimeDeltaMap.clear();
      nextPlanMap.forEach((value: number, key: number) => this.eventPlanIdMap.set(key, value));
      nextOrderMap.forEach((value: number, key: number) => this.eventOrderMap.set(key, value));
      nextTimeDeltaMap.forEach((value: number, key: number) => this.eventTimeDeltaMap.set(key, value));

      let needFenceRebuild = nextFenceIds.size !== this.fenceIdSnapshot.size;
      if (!needFenceRebuild) {
        const oldIds = Array.from(this.fenceIdSnapshot.values());
        for (let i = 0; i < oldIds.length; i++) {
          if (!nextFenceIds.has(oldIds[i])) {
            needFenceRebuild = true;
            break;
          }
        }
      }

      if (needFenceRebuild) {
        this.geoFenceStatus.clear();
        this.geoFenceEnterTs.clear();
        this.pendingCandidateIds.clear();
        this.directEnterTs.clear();

        this.geoFenceClient.removeGeoFence();
        for (let i = 0; i < this.monitoredEvents.length; i++) {
          const event = this.monitoredEvents[i];
          const customId = this.makeCustomId(event);
          const point = new DPoint(event.latitude, event.longitude);
          this.geoFenceClient.addRoundGeoFence(point, this.fenceRadiusMeters, customId);
          this.geoFenceStatus.set(customId, GeoFence.STATUS_OUT);
        }
        this.fenceIdSnapshot = nextFenceIds;
      }
      this.lastRefreshTs = now;
      hilog.info(
        0x0000,
        TAG,
        `[ARRIVAL][refresh_fences] reason=${reason}, schedule=${scheduleCount}, pending=${pendingCount}, active=${activeCount}, withCoordinate=${withCoordinateCount}, eligible=${eligibleCount}, plansScanned=${plansScanned}, activePlans=${activePlanIdsForLoop.length}, refreshedPlans=${refreshPlanIds.length}, fullResync=${needFullResync}, rebuild=${needFenceRebuild}, snapshot=${canUseSnapshot}, dirty=${dirtyPlanIds.size}`
      );
    } catch (error) {
      hilog.error(0x0000, TAG, `[ARRIVAL][refresh_fences_failed] reason=${JSON.stringify(error)}`);
      this.clearMonitoredStateAfterRefreshFailure();
    } finally {
      this.isRefreshingCandidates = false;
    }
  }

  public async requestImmediateDetection(reason: string = 'manual_refresh'): Promise<void> {
    await this.refreshFencesNow(reason);
    this.ensureReminderConsistency();
    if (!this.lastLocation) {
      return;
    }

    const geofenceReady = this.collectReadyCandidateIds();
    const directReady = this.collectDirectReadyCandidateIds(this.lastLocation);
    const readyIds = [...geofenceReady, ...directReady];
    for (let i = 0; i < readyIds.length; i++) {
      this.pendingCandidateIds.add(readyIds[i]);
    }
    this.evaluateCandidates(reason);
  }

  private clearMonitoredStateAfterRefreshFailure(): void {
    this.monitoredEvents = [];
    this.eventPlanIdMap.clear();
    this.eventOrderMap.clear();
    this.eventTimeDeltaMap.clear();
    this.pendingCandidateIds.clear();
    this.geoFenceStatus.clear();
    this.geoFenceEnterTs.clear();
    this.directEnterTs.clear();
    this.fenceIdSnapshot.clear();
    this.hasAnyActiveEvent = false;
    try {
      this.geoFenceClient?.removeGeoFence();
    } catch (_error) {
    }
  }

  private prunePlanCandidateCache(activePlanIds: Set<number>): void {
    const cachedPlanIds = Array.from(this.planCandidateCache.keys());
    for (let i = 0; i < cachedPlanIds.length; i++) {
      const planId = cachedPlanIds[i];
      if (!activePlanIds.has(planId)) {
        this.planCandidateCache.delete(planId);
      }
    }
  }

  private isPlanActiveForReminder(plan: PlanItem): boolean {
    if (!plan) {
      return false;
    }
    const isDeleted = (plan.delFlag ?? 0) === 1;
    const isArchived = (plan.status ?? 0) === 2;
    return !isDeleted && !isArchived;
  }

  private async applyDirtyPlansToActiveSnapshot(activePlanIds: Set<number>, dirtyPlanIds: Set<number>): Promise<void> {
    if (dirtyPlanIds.size === 0) {
      return;
    }
    const dirtyIds = Array.from(dirtyPlanIds.values());
    const dirtyPlans: (PlanItem | undefined)[] = await Promise.all(dirtyIds.map((planId: number): Promise<PlanItem | undefined> => PlanRepositoryImpl.getPlanById(planId)));
    for (let i = 0; i < dirtyIds.length; i++) {
      const planId = dirtyIds[i];
      const plan = dirtyPlans[i];
      if (plan && this.isPlanActiveForReminder(plan)) {
        activePlanIds.add(planId);
      } else {
        activePlanIds.delete(planId);
      }
    }
  }

  private isSamePlanSet(nextSet: Set<number>, prevSet: Set<number>): boolean {
    if (nextSet.size !== prevSet.size) {
      return false;
    }
    const ids = Array.from(nextSet.values());
    for (let i = 0; i < ids.length; i++) {
      if (!prevSet.has(ids[i])) {
        return false;
      }
    }
    return true;
  }

  private buildPlanCandidateCache(
    plan: PlanItem,
    events: TravelPlanItem[],
    now: number
  ): PlanCandidateCache {
    let scheduleCount = 0;
    let pendingCount = 0;
    let activeCount = 0;
    let withCoordinateCount = 0;
    let eligibleCount = 0;
    const candidates: EventEntity[] = [];
    const timeDeltaByEventId: Map<number, number> = new Map<number, number>();

    for (let i = 0; i < events.length; i++) {
      const event = EventEntity.fromInterface(events[i], plan.id);
      if (TimelineExecutionState.isScheduled(event)) {
        scheduleCount += 1;
      }
      if (TimelineExecutionState.isStartable(event)) {
        pendingCount += 1;
      }
      if (TimelineExecutionState.isActive(event)) {
        activeCount += 1;
      }
      if (TimelineExecutionState.isStartable(event) &&
        this.isValidCoordinate(event.latitude, event.longitude)) {
        withCoordinateCount += 1;
      }
      const timeDelta = this.getTimeDeltaByCurrentWindow(event, plan.startDate || 0, now);
      if (!this.isEligibleEvent(event, timeDelta)) {
        continue;
      }
      eligibleCount += 1;
      candidates.push(event);
      timeDeltaByEventId.set(event.id, timeDelta);
    }
    return {
      scheduleCount: scheduleCount,
      pendingCount: pendingCount,
      activeCount: activeCount,
      withCoordinateCount: withCoordinateCount,
      eligibleCount: eligibleCount,
      candidates: candidates,
      timeDeltaByEventId: timeDeltaByEventId
    };
  }

  public acknowledgeReminder(eventId: number, action: ArrivalReminderAction): void {
    const now = Date.now();
    this.lastReminderByEvent.set(eventId, now);
    if (this.lastReminderEventId === eventId) {
      this.lastReminderEventId = -1;
    }

    if (action === 'dismiss') {
      this.reminderLockUntilTs = now + this.dismissLockMs;
      this.publishLiveActivityState(eventId, 'ACKED');
    } else if (action === 'open_page') {
      this.reminderLockUntilTs = now + this.openPageLockMs;
      this.publishLiveActivityState(eventId, 'ACKED');
    } else {
      this.reminderLockUntilTs = now + this.startLockMs;
      this.publishLiveActivityState(eventId, 'STARTED');
    }
    this.clearReminderPayloadIfMatches(eventId);
  }

  private ensureStorageDefaults(): void {
    ArrivalReminderStore.ensureDefaults();
    ArrivalLiveActivityBridge.init();
  }

  private createGeoFenceClient(context: Context): GeoFenceClient {
    return new GeoFenceClient(context);
  }

  private createLocationManager(context: Context): AMapLocationManagerImpl {
    return new AMapLocationManagerImpl(context);
  }

  private ensureClients(): boolean {
    if (!this.context) {
      return false;
    }
    if (!this.geoFenceClient) {
      try {
        this.geoFenceClient = this.createGeoFenceClient(this.context);
        this.geoFenceClient.setActivateAction(GeoFenceClient.GEOFENCE_IN);
        this.geoFenceListener = {
          onGeoFenceCreateFinished: (_list, errorCode: number, customId: string) => {
            hilog.info(0x0000, TAG, `[ARRIVAL][fence_create] errorCode=${errorCode}, customId=${customId || 'none'}`);
          }
        };
        this.geoFenceClient.setGeoFenceListener(this.geoFenceListener);
      } catch (error) {
        hilog.error(0x0000, TAG, `[ARRIVAL][geofence_init_failed] reason=${JSON.stringify(error)}`);
        this.geoFenceClient = null;
      }
    }

    if (!this.locationManager) {
      try {
        this.locationManager = this.createLocationManager(this.context);
        const option: AMapLocationOption = {
          priority: geoLocationManager.LocationRequestPriority.ACCURACY,
          scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
          isOffset: true,
          timeInterval: 2,
          distanceInterval: 0,
          maxAccuracy: 100,
          allowsBackgroundLocationUpdates: false
        };
        this.locationManager.setLocationOption(AMapLocationType.Updating, option);
        this.locationListener = {
          onLocationChanged: (location: AMapLocation): void => {
            this.onLocationChanged(location);
          },
          onLocationError: (errorInfo: AMapLocationErrorInfo): void => {
            hilog.warn(0x0000, TAG, `[ARRIVAL][location_error] reason=${JSON.stringify(errorInfo)}`);
          }
        };
        this.locationManager.setLocationListener(AMapLocationType.Updating, this.locationListener);
      } catch (error) {
        hilog.error(0x0000, TAG, `[ARRIVAL][location_init_failed] reason=${JSON.stringify(error)}`);
        this.locationManager = null;
      }
    }
    return this.geoFenceClient !== null && this.locationManager !== null;
  }

  private onLocationChanged(location: AMapLocation): void {
    if (!this.geoFenceClient) {
      return;
    }
    hilog.info(
      0x0000,
      TAG,
      `[ARRIVAL][location] lat=${location.latitude}, lng=${location.longitude}, accuracy=${location.accuracy}, speed=${location.speed}`
    );
    const accepted = ArrivalReminderEngine.isLocationSampleAccepted(
      location.latitude,
      location.longitude,
      location.accuracy,
      location.speed,
      this.maxAllowedAccuracyMeters,
      this.maxAllowedSpeedMetersPerSec
    );
    if (!accepted) {
      hilog.warn(
        0x0000,
        TAG,
        `[ARRIVAL][location_drop] lat=${location.latitude},lng=${location.longitude},accuracy=${location.accuracy},speed=${location.speed}`
      );
      return;
    }
    this.lastLocation = location;

    if (Date.now() - this.lastRefreshTs > this.refreshIntervalMs) {
      void this.refreshFencesNow('periodic_tick');
      this.ensureReminderConsistency();
    }

    try {
      this.geoFenceClient.doCheckFence(location);
    } catch (error) {
      hilog.warn(0x0000, TAG, `[ARRIVAL][fence_check_failed] reason=${JSON.stringify(error)}`);
      return;
    }

    const geofenceReady = this.collectReadyCandidateIds();
    const directReady = this.collectDirectReadyCandidateIds(location);
    const readyIds = [...geofenceReady, ...directReady];
    hilog.info(
      0x0000,
      TAG,
      `[ARRIVAL][candidate] geofence=${geofenceReady.length}, direct=${directReady.length}, merged=${readyIds.length}`
    );
    if (readyIds.length <= 0) {
      return;
    }
    for (let i = 0; i < readyIds.length; i++) {
      this.pendingCandidateIds.add(readyIds[i]);
    }
    this.scheduleCandidateEvaluation('geo_in_or_direct');
  }

  private collectReadyCandidateIds(): number[] {
    if (!this.geoFenceClient) {
      return [];
    }
    const rawList = this.geoFenceClient.getAllGeoFence();
    const fenceList = this.toGeoFenceArray(rawList as Object);
    const now = Date.now();
    const ready: number[] = [];

    for (let i = 0; i < fenceList.length; i++) {
      const fence = fenceList[i];
      const customId = fence.getCustomId();
      if (!customId || customId.length === 0) {
        continue;
      }

      const status = fence.getStatus();
      this.geoFenceStatus.set(customId, status);

      if (status === GeoFence.STATUS_IN) {
        if (!this.geoFenceEnterTs.has(customId)) {
          this.geoFenceEnterTs.set(customId, now);
        }
        const enterTs = this.geoFenceEnterTs.get(customId) ?? now;
        if (now - enterTs >= this.dwellWindowMs) {
          const eventId = this.parseEventId(customId);
          if (eventId > 0) {
            ready.push(eventId);
          }
        }
      } else {
        this.geoFenceEnterTs.delete(customId);
      }
    }

    return ready;
  }

  private collectDirectReadyCandidateIds(location: AMapLocation): number[] {
    const now = Date.now();
    const ready: number[] = [];
    const eligible = this.getEligibleEvents();
    const aliveIds: Set<number> = new Set<number>();

    for (let i = 0; i < eligible.length; i++) {
      const event = eligible[i];
      aliveIds.add(event.id);
      const distance = this.measureDistanceMeters(
        location.latitude,
        location.longitude,
        event.latitude,
        event.longitude
      );
      if (distance <= this.fenceRadiusMeters) {
        if (!this.directEnterTs.has(event.id)) {
          this.directEnterTs.set(event.id, now);
        }
        const enterTs = this.directEnterTs.get(event.id) ?? now;
        if (now - enterTs >= this.dwellWindowMs) {
          ready.push(event.id);
        }
      } else {
        this.directEnterTs.delete(event.id);
      }
    }

    const allDirectKeys = Array.from(this.directEnterTs.keys());
    for (let i = 0; i < allDirectKeys.length; i++) {
      const id = allDirectKeys[i];
      if (!aliveIds.has(id)) {
        this.directEnterTs.delete(id);
      }
    }
    return ready;
  }

  private scheduleCandidateEvaluation(reason: string): void {
    if (this.pendingBatchTimer >= 0) {
      return;
    }
    this.pendingBatchTimer = setTimeout(() => {
      this.pendingBatchTimer = -1;
      this.evaluateCandidates(reason);
    }, this.batchWindowMs);
  }

  private evaluateCandidates(reason: string): void {
    if (!this.lastLocation) {
      this.pendingCandidateIds.clear();
      return;
    }
    const now = Date.now();
    if (now < this.reminderLockUntilTs) {
      this.pendingCandidateIds.clear();
      return;
    }
    if (this.hasActiveEvent()) {
      this.pendingCandidateIds.clear();
      return;
    }

    const candidateIds = Array.from(this.pendingCandidateIds.values());
    this.pendingCandidateIds.clear();
    if (candidateIds.length <= 0) {
      return;
    }

    const selected = this.pickBestCandidate(candidateIds, this.lastLocation, now);
    if (!selected) {
      return;
    }
    this.fireReminder(selected, this.lastLocation, reason);
  }

  private pickBestCandidate(candidateIds: number[], location: AMapLocation, now: number): EventEntity | null {
    const scoreList: CandidateScore[] = [];
    for (let i = 0; i < candidateIds.length; i++) {
      const eventId = candidateIds[i];
      const event = this.findEventById(eventId);
      if (!event || !this.isEligibleEvent(event, this.eventTimeDeltaMap.get(event.id) ?? Number.MAX_SAFE_INTEGER)) {
        continue;
      }
      const lastTrigger = this.lastReminderByEvent.get(event.id) ?? 0;
      if (!ArrivalReminderEngine.isEventOutOfCooldown(lastTrigger, now, this.eventCooldownMs)) {
        continue;
      }
      const distance = this.measureDistanceMeters(
        location.latitude,
        location.longitude,
        event.latitude,
        event.longitude
      );
      const order = this.eventOrderMap.get(event.id) ?? 99_999;
      const timeDelta = this.eventTimeDeltaMap.get(event.id) ?? Number.MAX_SAFE_INTEGER;
      scoreList.push({ event, order, timeDelta, distance });
    }

    if (scoreList.length <= 0) {
      return null;
    }

    scoreList.sort((a: CandidateScore, b: CandidateScore) => {
      if (a.timeDelta !== b.timeDelta) {
        return a.timeDelta - b.timeDelta;
      }
      if (a.order !== b.order) {
        return a.order - b.order;
      }
      return a.distance - b.distance;
    });
    return scoreList[0].event;
  }

  private fireReminder(event: EventEntity, location: AMapLocation, reason: string): void {
    const now = Date.now();
    const nextSeq = ArrivalReminderStore.nextSeq();
    const distance = Math.round(
      this.measureDistanceMeters(location.latitude, location.longitude, event.latitude, event.longitude)
    );
    const planId = this.eventPlanIdMap.get(event.id) ?? this.activePagePlanId;
    const payload: ArrivalReminderPayload = {
      seq: nextSeq,
      planId: planId,
      eventId: event.id,
      placeName: event.name,
      distanceMeters: distance,
      triggerAt: now
    };

    ArrivalReminderStore.writePayload(payload);

    this.lastReminderEventId = event.id;
    this.lastReminderByEvent.set(event.id, now);
    this.reminderLockUntilTs = now + this.reminderSwitchLockMs;

    this.publishLiveActivityState(event.id, 'REMINDING');
    this.publishSystemNotification(payload);
    hilog.info(
      0x0000,
      TAG,
      `[ARRIVAL][trigger] planId=${planId}, eventId=${event.id}, name=${event.name}, distance=${distance}, reason=${reason}`
    );
  }

  private publishSystemNotification(payload: ArrivalReminderPayload): void {
    const content = `已进入 ${payload.placeName} 附近（约${Math.max(1, payload.distanceMeters)}米），可立即开始行程`;
    void NotificationGateway.updateScheduleNotification(
      `到达提醒：${payload.placeName}`,
      content,
      payload.planId,
      payload.eventId,
      true
    );
  }

  private publishLiveActivityState(eventId: number, status: ArrivalLiveStatus): void {
    const event = this.findEventById(eventId);
    const placeName = event ? event.name : '';
    const planId = this.eventPlanIdMap.get(eventId) ?? this.activePagePlanId;
    if (status === 'REMINDING') {
      ArrivalLiveActivityBridge.start(planId, eventId, placeName);
      return;
    }
    if (status === 'ENDED') {
      ArrivalLiveActivityBridge.end(planId, eventId, placeName);
      return;
    }
    ArrivalLiveActivityBridge.update(planId, eventId, placeName, status);
  }

  private ensureReminderConsistency(): void {
    if (this.lastReminderEventId <= 0) {
      return;
    }
    const event = this.findEventById(this.lastReminderEventId);
    if (!event || !this.isEligibleEvent(event, this.eventTimeDeltaMap.get(event.id) ?? Number.MAX_SAFE_INTEGER)) {
      this.publishLiveActivityState(this.lastReminderEventId, 'ENDED');
      this.clearReminderPayloadIfMatches(this.lastReminderEventId);
      this.lastReminderEventId = -1;
    }
  }

  private clearReminderPayloadIfMatches(eventId: number): void {
    ArrivalReminderStore.clearPayloadIfEventMatches(eventId);
  }

  private hasActiveEvent(): boolean {
    return this.hasAnyActiveEvent;
  }

  private getEligibleEvents(): EventEntity[] {
    return this.monitoredEvents.filter((event: EventEntity) =>
      this.isEligibleEvent(event, this.eventTimeDeltaMap.get(event.id) ?? Number.MAX_SAFE_INTEGER)
    );
  }

  private isEligibleEvent(event: EventEntity, timeDelta: number): boolean {
    return TimelineExecutionState.isStartable(event) &&
      this.isValidCoordinate(event.latitude, event.longitude) &&
      timeDelta <= this.currentTimeBandMs;
  }

  private findEventById(eventId: number): EventEntity | null {
    const found = this.monitoredEvents.find((event: EventEntity) => event.id === eventId);
    return found ? found : null;
  }

  private makeCustomId(event: EventEntity): string {
    const planId = this.eventPlanIdMap.get(event.id) ?? event.plan_id;
    return `${planId}:${event.id}`;
  }

  private parseEventId(customId: string): number {
    const parts = customId.split(':');
    if (parts.length < 2) {
      return -1;
    }
    const eventId = Number(parts[1]);
    return Number.isFinite(eventId) ? eventId : -1;
  }

  private getTimeDeltaByCurrentWindow(event: EventEntity, planStartDate: number, now: number): number {
    if (planStartDate <= 0) {
      return 0;
    }
    const dayBase = new Date(planStartDate);
    dayBase.setHours(0, 0, 0, 0);
    const eventDayStart = dayBase.getTime() +
      TimelineDatePolicy.resolveEventDayOffset(event) * 24 * 60 * 60 * 1000;

    const fixed = event.fixed_start_time ? event.fixed_start_time.trim() : '';
    if (fixed.length >= 4 && fixed.includes(':')) {
      const parts = fixed.split(':');
      const hour = Number(parts[0]);
      const minute = Number(parts[1]);
      if (Number.isFinite(hour) && Number.isFinite(minute) && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
        const fixedTs = eventDayStart + hour * 60 * 60 * 1000 + minute * 60 * 1000;
        return Math.abs(now - fixedTs);
      }
    }
    const eventDayEnd = eventDayStart + 24 * 60 * 60 * 1000 - 1;
    if (now >= eventDayStart && now <= eventDayEnd) {
      return 0;
    }
    if (now < eventDayStart) {
      return eventDayStart - now;
    }
    return now - eventDayEnd;
  }

  private isValidCoordinate(latitude: number, longitude: number): boolean {
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
      return false;
    }
    if (latitude === 0 && longitude === 0) {
      return false;
    }
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  private measureDistanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const rad = (deg: number): number => deg * Math.PI / 180;
    const earthRadius = 6378137;
    const dLat = rad(lat2 - lat1);
    const dLng = rad(lng2 - lng1);
    const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadius * c;
  }

  private toGeoFenceArray(rawList: Object | undefined): GeoFence[] {
    if (!rawList) {
      return [];
    }
    const list = rawList as GeoFenceListLike;
    const result: GeoFence[] = [];

    let count = -1;
    if (typeof list.length === 'number') {
      count = list.length;
    } else if (typeof list.size === 'number') {
      count = list.size;
    } else if (typeof list.size === 'function') {
      count = list.size();
    }

    if (count >= 0 && typeof list.get === 'function') {
      for (let i = 0; i < count; i++) {
        const fence = list.get(i);
        if (fence) {
          result.push(fence);
        }
      }
      return result;
    }

    if (typeof list.forEach === 'function') {
      list.forEach((value: GeoFence) => {
        if (value) {
          result.push(value);
        }
      });
      return result;
    }
    return result;
  }
}

