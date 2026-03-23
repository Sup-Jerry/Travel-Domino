import { EventEntity } from '../../model/entity/EventEntity';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WeatherStagePolicy } from '../policy/WeatherStagePolicy';
import { AmapWeatherService } from '../../infrastructure/services/AmapWeatherService';
import { WeatherRiskEvaluator } from './WeatherRiskEvaluator';
import { WeatherGeoPointRequest } from '../../infrastructure/adapters/IWeatherAdapter';
import { TimelineDatePolicy } from '../policy/TimelineDatePolicy';
import { TimelineExecutionState } from '../policy/TimelineExecutionState';
import { ExecutionContext } from '../statemachine/ExecutionContext';
import { PlanStatus } from '../statemachine/PlanStatus';
import { WeatherPolicyResolver, WeatherRefreshResult } from '../statemachine/WeatherPolicyResolver';
import {
  CityWeatherBucket,
  DEFAULT_WEATHER_USER_PREFERENCE,
  GeoPointInput,
  PlanNodeWeatherBinding,
  WeatherCollabContext,
  WeatherCollabOptions,
  WeatherContext,
  WeatherContextBuildResult,
  WeatherDayWindow,
  WeatherSnapshot,
  WeatherStageType,
  WeatherSuggestion,
  WeatherSuggestionAlternativeCandidate,
  WeatherTrendTag,
  WeatherUserPreference
} from './WeatherModels';

interface CityBucketBuildResult {
  buckets: CityWeatherBucket[];
  missCount: number;
  cappedCount: number;
}

export class WeatherContextBuilder {
  private static readonly TAG: string = 'WeatherContextBuilder';
  private static readonly MAX_CITY_BUCKETS: number = 5;
  private readonly weatherService: AmapWeatherService;
  private readonly riskEvaluator: WeatherRiskEvaluator;
  private readonly weatherPolicyResolver: WeatherPolicyResolver;

  constructor(weatherService?: AmapWeatherService, riskEvaluator?: WeatherRiskEvaluator, weatherPolicyResolver?: WeatherPolicyResolver) {
    this.weatherService = weatherService ?? new AmapWeatherService();
    this.riskEvaluator = riskEvaluator ?? new WeatherRiskEvaluator();
    this.weatherPolicyResolver = weatherPolicyResolver ?? new WeatherPolicyResolver();
  }

  public resolveWeatherFetchPolicy(status: PlanStatus) {
    return this.weatherPolicyResolver.resolveWeatherFetchPolicy(status);
  }

  public buildWeatherTargets(
    planId: string,
    status: PlanStatus,
    events: EventEntity[],
    context?: ExecutionContext
  ) {
    return this.weatherPolicyResolver.buildWeatherTargets(planId, status, events, context);
  }

  public async refreshWeatherByStatus(
    planId: string,
    status: PlanStatus,
    events: EventEntity[],
    context?: ExecutionContext,
    forceRefresh: boolean = false,
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions
  ): Promise<WeatherRefreshResult> {
    const targets = this.buildWeatherTargets(planId, status, events, context);
    try {
      if (status === PlanStatus.DRAFT || status === PlanStatus.CONFIRMED) {
        const result = await this.buildPlanningContext(events, preference, options, status === PlanStatus.CONFIRMED ? 'CONFIRMED' : 'PLANNING');
        return {
          success: true,
          requestedTargets: targets,
          snapshotVersion: `${status}_${result.context.generatedAt}`,
          degraded: false
        };
      }

      if (status === PlanStatus.READY || status === PlanStatus.IN_PROGRESS || status === PlanStatus.PAUSED) {
        const currentLocation = this.resolveExecutionGeoByContext(context);
        const stage = status === PlanStatus.READY ? 'READY' : (status === PlanStatus.PAUSED ? 'PAUSED' : 'IN_PROGRESS');
        const result = await this.buildExecutionContext(events, currentLocation, forceRefresh, preference, options, stage);
        return {
          success: true,
          requestedTargets: targets,
          snapshotVersion: `${status}_${result.context.generatedAt}`,
          degraded: false
        };
      }

      return {
        success: true,
        requestedTargets: targets,
        snapshotVersion: `${status}_${Date.now()}`,
        degraded: false
      };
    } catch (error) {
      hilog.warn(0x0000, WeatherContextBuilder.TAG, `[WEATHER_CTX][refresh_by_status] failed status=${status}, reason=${JSON.stringify(error)}`);
      return {
        success: false,
        requestedTargets: targets,
        degraded: true,
        errorMessage: error instanceof Error ? error.message : 'refresh_failed'
      };
    }
  }
  public async buildPlanningContext(
    events: EventEntity[],
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    const collabOptions = this.normalizeCollabOptions(options);
    const sourceEvents = (events || []).filter((event: EventEntity) =>
      event.status === 1 &&
      Number.isFinite(event.latitude) &&
      Number.isFinite(event.longitude) &&
      !(event.latitude === 0 && event.longitude === 0)
    );

    const queryPoints: WeatherGeoPointRequest[] = [];
    const pointKeyByEventId: Map<number, string> = new Map<number, string>();
    sourceEvents.forEach((event: EventEntity) => {
      const targetTime = event.dynamic_start_time > 0 ? event.dynamic_start_time : Date.now();
      const point: WeatherGeoPointRequest = {
        latitude: event.latitude,
        longitude: event.longitude,
        targetTime: targetTime
      };
      queryPoints.push(point);
      pointKeyByEventId.set(event.id, AmapWeatherService.toPointKey(event.latitude, event.longitude, targetTime));
    });
    const weatherMap = await this.weatherService.batchGetWeather(queryPoints);
    hilog.info(0x0000, WeatherContextBuilder.TAG, `[WEATHER_CTX][planning] sourceEvents=${sourceEvents.length}, queryPoints=${queryPoints.length}, weatherMap=${weatherMap.size}`);

    const bindings: PlanNodeWeatherBinding[] = [];
    const eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
    sourceEvents.forEach((event: EventEntity) => {
      const pointKey = pointKeyByEventId.get(event.id) ??
        AmapWeatherService.toPointKey(event.latitude, event.longitude, event.dynamic_start_time > 0 ? event.dynamic_start_time : Date.now());
      const info = weatherMap.get(pointKey);
      const snapshot = info ? this.weatherService.toSnapshotByPoint(pointKey, info) : undefined;
      const risk = this.riskEvaluator.evaluateNodeSuitability(event, snapshot, pref);
      const binding: PlanNodeWeatherBinding = {
        nodeId: `${event.id}`,
        eventId: event.id,
        nodeName: event.name,
        weather: snapshot,
        suitabilityScore: risk.score,
        riskTags: risk.riskTags
      };
      bindings.push(binding);
      eventMap.set(event.id, binding);
    });

    const collabContext = this.buildCollabContext(sourceEvents, bindings, collabOptions);
    const routeSuitability = this.riskEvaluator.evaluateRouteSuitability(bindings, pref, collabContext);
    const context: WeatherContext = {
      stage: stage ?? WeatherStagePolicy.resolveDetailedStage(undefined, events),
      generatedAt: Date.now(),
      bindings: bindings,
      routeSuitability: routeSuitability,
      collabContext: collabContext
    };

    return {
      context: context,
      eventMap: eventMap,
      sourceEvents: sourceEvents
    };
  }

  public async buildExecutionContext(
    events: EventEntity[],
    currentLocation?: GeoPointInput,
    forceRefresh: boolean = false,
    preference?: WeatherUserPreference,
    options?: WeatherCollabOptions,
    stage?: WeatherStageType
  ): Promise<WeatherContextBuildResult> {
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    const collabOptions = this.normalizeCollabOptions(options);
    const now = Date.now();
    const ordered = this.getOrderedScheduledEvents(events);
    const pendingEvents = ordered.filter((event: EventEntity) =>
      event.completion_status === EventEntity.STATE_PENDING
    );
    const activeEvent = pendingEvents.find((event: EventEntity) => TimelineExecutionState.isActive(event));
    const nextNode = this.resolveNextNode(pendingEvents, activeEvent);
    const futureNodes = this.resolveFutureNodes(pendingEvents, nextNode, 3);

    const queryPoints: WeatherGeoPointRequest[] = [];
    futureNodes.forEach((event: EventEntity) => {
      queryPoints.push({
        latitude: event.latitude,
        longitude: event.longitude,
        targetTime: event.dynamic_start_time > 0 ? event.dynamic_start_time : now,
        sourceType: 'PLAN_LOCATION',
        forceRefresh: forceRefresh
      });
    });
    const futureWeatherMap = await this.weatherService.batchGetWeather(queryPoints);
    hilog.info(0x0000, WeatherContextBuilder.TAG, `[WEATHER_CTX][execution] futureNodes=${futureNodes.length}, queryPoints=${queryPoints.length}, weatherMap=${futureWeatherMap.size}`);

    const bindings: PlanNodeWeatherBinding[] = [];
    const eventMap: Map<number, PlanNodeWeatherBinding> = new Map<number, PlanNodeWeatherBinding>();
    futureNodes.forEach((event: EventEntity) => {
      const pointKey = AmapWeatherService.toPointKey(
        event.latitude,
        event.longitude,
        event.dynamic_start_time > 0 ? event.dynamic_start_time : now
      );
      const info = futureWeatherMap.get(pointKey);
      const snapshot = info ? this.weatherService.toSnapshotByPoint(pointKey, info) : undefined;
      const risk = this.riskEvaluator.evaluateNodeSuitability(event, snapshot, pref);
      const binding: PlanNodeWeatherBinding = {
        nodeId: `${event.id}`,
        eventId: event.id,
        nodeName: event.name,
        weather: snapshot,
        suitabilityScore: risk.score,
        riskTags: risk.riskTags
      };
      bindings.push(binding);
      eventMap.set(event.id, binding);
    });

    const currentGeo = this.resolveCurrentGeoPoint(currentLocation, activeEvent, nextNode);
    let currentLocationWeather: WeatherSnapshot | undefined = undefined;
    if (currentGeo) {
      const currentInfo = await this.weatherService.getWeatherByGeoPoint(
        currentGeo.latitude,
        currentGeo.longitude,
        now,
        'CURRENT_LOCATION',
        forceRefresh
      );
      if (currentInfo) {
        const currentKey = AmapWeatherService.toPointKey(currentGeo.latitude, currentGeo.longitude, now);
        currentLocationWeather = this.weatherService.toSnapshotByPoint(currentKey, currentInfo);
      }
    }

    let nextNodeWeather: WeatherSnapshot | undefined = undefined;
    if (nextNode) {
      const nextBinding = eventMap.get(nextNode.id);
      nextNodeWeather = nextBinding?.weather;
    }

    if (!currentLocationWeather && nextNodeWeather) {
      currentLocationWeather = nextNodeWeather;
    } else if (!currentLocationWeather && bindings.length > 0) {
      currentLocationWeather = bindings[0].weather;
    }

    const collabContext = this.buildCollabContext(futureNodes, bindings, collabOptions);
    const routeSuitability = this.riskEvaluator.evaluateRouteSuitability(bindings, pref, collabContext);
    const context: WeatherContext = {
      stage: stage ?? WeatherStagePolicy.resolveDetailedStage(undefined, events),
      generatedAt: now,
      bindings: bindings,
      routeSuitability: routeSuitability,
      currentLocationWeather: currentLocationWeather,
      nextNodeWeather: nextNodeWeather,
      futureNodeWeatherList: bindings,
      executionRiskScore: routeSuitability.routeScore,
      executionRiskTags: routeSuitability.riskTags,
      collabContext: collabContext
    };

    return {
      context: context,
      eventMap: eventMap,
      sourceEvents: futureNodes
    };
  }

  public buildExecutionSuggestions(
    context: WeatherContext,
    preference?: WeatherUserPreference
  ): WeatherSuggestion[] {
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    const suggestions: WeatherSuggestion[] = [];
    if (!context || !context.futureNodeWeatherList) {
      return suggestions;
    }
    const triggerType = this.resolveTriggerType(context.executionRiskTags);
    const targets = context.futureNodeWeatherList.slice(0, 3);
    const targetNodeIds = targets.map((item: PlanNodeWeatherBinding) => item.nodeId);
    const next = context.nextNodeWeather;
    const nextText = next?.conditionText ?? '天气未知';
    const prefText = this.preferenceSummary(pref);
    const score = context.executionRiskScore ?? 100;
    const now = Date.now();
    const expiresAt = now + 30 * 60 * 1000;

    if (triggerType === 'RAIN') {
      suggestions.push({
        suggestionId: `wx_reorder_${context.generatedAt}`,
        level: 'WARNING',
        triggerType: triggerType,
        actionType: 'REORDER',
        title: '降雨风险，建议调整顺序',
        message: `下一节点为${nextText}，建议优先执行室内点位（基于你的天气偏好：${prefText}）。`,
        relatedNodeIds: targetNodeIds,
        createdAt: now,
        reason: '检测到降雨/雷雨标签，户外节点暴露风险较高。',
        expectedBenefit: '优先室内节点可降低淋雨与等待成本。',
        canRollback: true,
        cooldownKey: `RAIN_REORDER_${targetNodeIds.join('_')}`,
        expiresAt: expiresAt,
        actionPayload: {
          targetNodeIds: targetNodeIds,
          targetOrderNodeIds: targetNodeIds.length >= 2 ? [targetNodeIds[1], targetNodeIds[0], ...targetNodeIds.slice(2)] : targetNodeIds
        }
      });
      suggestions.push({
        suggestionId: `wx_shorten_${context.generatedAt}`,
        level: 'NOTICE',
        triggerType: triggerType,
        actionType: 'SHORTEN_STAY',
        title: '降雨风险，建议缩短停留',
        message: `建议缩短下一站户外停留时长，减少暴露时间（基于你的天气偏好：${prefText}）。`,
        relatedNodeIds: targetNodeIds.slice(0, 1),
        createdAt: now + 1,
        reason: '雨天持续停留将增加执行偏差。',
        expectedBenefit: '缩短停留可提高后续节点准点率。',
        canRollback: true,
        cooldownKey: `RAIN_SHORTEN_${targetNodeIds[0] || 'NONE'}`,
        expiresAt: expiresAt,
        actionPayload: {
          targetNodeIds: targetNodeIds.slice(0, 1),
          suggestedStayMinutes: 45
        }
      });
    } else if (triggerType === 'HEAT') {
      suggestions.push({
        suggestionId: `wx_heat_shorten_${context.generatedAt}`,
        level: score < 70 ? 'WARNING' : 'NOTICE',
        triggerType: triggerType,
        actionType: 'SHORTEN_STAY',
        title: '高温风险，建议缩短停留',
        message: `下一节点${nextText}，建议缩短户外停留并补水（基于你的天气偏好：${prefText}）。`,
        relatedNodeIds: targetNodeIds.slice(0, 1),
        createdAt: now,
        reason: '检测到高温标签，长时间户外停留风险上升。',
        expectedBenefit: '减少体力消耗并降低中暑风险。',
        canRollback: true,
        cooldownKey: `HEAT_SHORTEN_${targetNodeIds[0] || 'NONE'}`,
        expiresAt: expiresAt,
        actionPayload: {
          targetNodeIds: targetNodeIds.slice(0, 1),
          suggestedStayMinutes: 40
        }
      });
      suggestions.push({
        suggestionId: `wx_heat_skip_${context.generatedAt}`,
        level: 'NOTICE',
        triggerType: triggerType,
        actionType: 'SKIP_NODE',
        title: '高温持续，建议跳过高风险节点',
        message: `若体感不适，可跳过下一户外节点并继续后续安排（基于你的天气偏好：${prefText}）。`,
        relatedNodeIds: targetNodeIds.slice(0, 1),
        createdAt: now + 1,
        reason: '持续高温下户外节点收益下降。',
        expectedBenefit: '优先保障体力与计划稳定性。',
        canRollback: false,
        cooldownKey: `HEAT_SKIP_${targetNodeIds[0] || 'NONE'}`,
        expiresAt: expiresAt,
        actionPayload: {
          targetNodeIds: targetNodeIds.slice(0, 1)
        }
      });
    } else if (triggerType === 'UNKNOWN') {
      const replacementCandidates = this.buildReplacementCandidates(targets);
      suggestions.push({
        suggestionId: `wx_unknown_alt_${context.generatedAt}`,
        level: 'INFO',
        triggerType: triggerType,
        actionType: 'REPLACE_NODE',
        title: '定位未命中，建议保守执行',
        message: `当前定位天气未命中，建议准备替代节点或优先室内点位（基于你的天气偏好：${prefText}）。`,
        relatedNodeIds: targetNodeIds,
        createdAt: now,
        reason: '天气信息不完整，执行不确定性上升。',
        expectedBenefit: '通过替代预案降低突发中断。',
        canRollback: true,
        cooldownKey: `UNKNOWN_ALT_${targetNodeIds.join('_')}`,
        expiresAt: expiresAt,
        actionPayload: {
          targetNodeIds: targetNodeIds,
          replacementCandidates: replacementCandidates
        }
      });
    } else if (context.executionRiskTags && context.executionRiskTags.length > 0) {
      suggestions.push({
        suggestionId: `wx_info_${context.generatedAt}`,
        level: 'INFO',
        triggerType: triggerType,
        actionType: 'NONE',
        title: '天气已更新',
        message: `当前天气${nextText}，行程可继续执行（基于你的天气偏好：${prefText}）。`,
        relatedNodeIds: [],
        createdAt: now,
        reason: '天气风险可控。',
        expectedBenefit: '维持当前执行节奏。',
        canRollback: false,
        cooldownKey: `INFO_${triggerType}`,
        expiresAt: expiresAt
      });
    }
    return suggestions;
  }

  public buildExecutionAdjustments(
    planId: number,
    context: WeatherContext,
    futureNodes: EventEntity[],
    preference?: WeatherUserPreference,
    collabContext?: WeatherCollabContext
  ): WeatherSuggestion[] {
    if (planId <= 0 || !context || !futureNodes || futureNodes.length === 0) {
      return [];
    }
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    const now = Date.now();
    const expiresAt = now + 30 * 60 * 1000;
    const scopedNodes = futureNodes.slice(0, 3);
    const scopedNodeIds = scopedNodes.map((item: EventEntity) => `${item.id}`);
    const allowedNodeIds = new Set<string>(scopedNodeIds);
    const bindingMap = new Map<string, PlanNodeWeatherBinding>();
    (context.futureNodeWeatherList ?? context.bindings ?? []).forEach((item: PlanNodeWeatherBinding) => {
      bindingMap.set(item.nodeId, item);
    });

    const dedupeKeys = new Set<string>();
    const suggestions: WeatherSuggestion[] = [];
    const appendSuggestion = (item: WeatherSuggestion): void => {
      const firstNodeId = item.relatedNodeIds && item.relatedNodeIds.length > 0 ? item.relatedNodeIds[0] : 'ALL';
      const dedupeKey = `${item.actionType}_${firstNodeId}`;
      if (dedupeKeys.has(dedupeKey)) {
        return;
      }
      dedupeKeys.add(dedupeKey);
      suggestions.push(item);
    };

    scopedNodes.forEach((event: EventEntity) => {
      const nodeId = `${event.id}`;
      const binding = bindingMap.get(nodeId);
      const weather = binding?.weather;
      const conditionCode = `${weather?.conditionCode ?? event.weather_condition ?? ''}`.toUpperCase();
      const conditionText = `${weather?.conditionText ?? event.weather_text ?? '天气未知'}`;
      const temperature = Number.isFinite(weather?.temperatureCelsius)
        ? Number(weather?.temperatureCelsius)
        : (Number.isFinite(event.weather_temperature) ? Number(event.weather_temperature) : undefined);
      const isOutdoor = this.isOutdoorEvent(event);
      const isRequired = event.priority === 1;
      const affectedNodes = scopedNodes.map((item: EventEntity) => item.name || `节点${item.id}`);

      if (this.isSevereWeather(conditionCode, conditionText)) {
        appendSuggestion({
          suggestionId: `wx_skip_${event.id}_${context.generatedAt}`,
          level: 'WARNING',
          triggerType: 'SEVERE_ALERT',
          actionType: 'SKIP_NODE',
          title: '极端天气，建议跳过节点',
          message: `${event.name} 预计${conditionText}，建议跳过该节点并继续后续行程。`,
          relatedNodeIds: [nodeId],
          createdAt: now,
          reason: `${event.name} 存在极端天气暴露风险。`,
          expectedBenefit: '优先保障安全并降低执行中断风险。',
          canRollback: false,
          cooldownKey: `SKIP_NODE_${nodeId}`,
          expiresAt: expiresAt,
          strategyHint: '建议降低行程密度，优先保留室内或刚需节点。',
          affectedNodes: affectedNodes,
          actionPayload: {
            targetNodeIds: [nodeId]
          }
        });
        return;
      }

      if (this.isRainWeather(conditionCode, conditionText) && isOutdoor) {
        const reordered = this.buildRainReorderTarget(scopedNodes);
        appendSuggestion({
          suggestionId: `wx_reorder_${event.id}_${context.generatedAt}`,
          level: isRequired ? 'WARNING' : 'NOTICE',
          triggerType: 'RAIN',
          actionType: 'REORDER',
          title: '降雨影响户外节点，建议调整顺序',
          message: `${event.name} 为户外活动且预计降雨，建议优先前往室内节点。`,
          relatedNodeIds: scopedNodeIds,
          createdAt: now,
          reason: `${event.name} 遇雨会显著降低体验并拉高时延风险。`,
          expectedBenefit: '先室内后室外可减少淋雨与等待时间。',
          canRollback: true,
          cooldownKey: `REORDER_${nodeId}`,
          expiresAt: expiresAt,
          strategyHint: '建议降低密度（density -1），把户外节点后置。',
          affectedNodes: affectedNodes,
          actionPayload: {
            targetNodeIds: scopedNodeIds,
            targetOrderNodeIds: reordered
          }
        });
      }

      if (isOutdoor && Number.isFinite(temperature) && (Number(temperature) > 35 || Number(temperature) < 5)) {
        const ratio = Number(temperature) > 35 ? 0.6 : 0.7;
        const minDuration = Number(temperature) > 35 ? 20 : 25;
        const suggestedStay = Math.max(minDuration, Math.floor(event.duration * ratio));
        const trigger: 'HEAT' | 'COLD' = Number(temperature) > 35 ? 'HEAT' : 'COLD';
        appendSuggestion({
          suggestionId: `wx_shorten_${event.id}_${context.generatedAt}`,
          level: Number(temperature) > 35 ? 'NOTICE' : 'INFO',
          triggerType: trigger,
          actionType: 'SHORTEN_STAY',
          title: Number(temperature) > 35 ? '高温风险，建议缩短停留' : '低温风险，建议缩短停留',
          message: `${event.name} 预计${Number(temperature)}°C，建议缩短停留至约 ${suggestedStay} 分钟。`,
          relatedNodeIds: [nodeId],
          createdAt: now,
          reason: `${event.name} 在当前气温下长时间停留的体感风险升高。`,
          expectedBenefit: '降低体力消耗并提升后续节点准点率。',
          canRollback: true,
          cooldownKey: `SHORTEN_STAY_${nodeId}`,
          expiresAt: expiresAt,
          strategyHint: Number(temperature) > 35
            ? '建议放慢节奏（pace -1）并降低体力负担（energy -1）。'
            : '建议放慢节奏（pace -1），减少低温暴露。',
          affectedNodes: [event.name || `节点${event.id}`],
          suggestedDurationMin: suggestedStay,
          actionPayload: {
            targetNodeIds: [nodeId],
            suggestedStayMinutes: suggestedStay
          }
        });
      }
    });

    if (suggestions.length === 0) {
      this.buildExecutionSuggestions(context, pref).forEach((item: WeatherSuggestion) => appendSuggestion(item));
    }

    const activeCollab = collabContext ?? context.collabContext;
    return suggestions.filter((item: WeatherSuggestion) => {
      if (!item.relatedNodeIds || item.relatedNodeIds.length === 0) {
        return true;
      }
      return item.relatedNodeIds.some((id: string) => allowedNodeIds.has(id));
    }).map((item: WeatherSuggestion) => {
      if (!activeCollab || activeCollab.collabSummary.trim().length === 0) {
        return item;
      }
      const copied: WeatherSuggestion = {
        suggestionId: item.suggestionId,
        level: item.level,
        triggerType: item.triggerType,
        actionType: item.actionType,
        title: item.title,
        message: `${item.message}（多日/多城协同：${activeCollab.collabSummary}）`,
        relatedNodeIds: item.relatedNodeIds,
        createdAt: item.createdAt,
        reason: item.reason,
        expectedBenefit: item.expectedBenefit,
        canRollback: item.canRollback,
        cooldownKey: item.cooldownKey,
        expiresAt: item.expiresAt,
        strategyHint: item.strategyHint,
        affectedNodes: item.affectedNodes,
        suggestedDurationMin: item.suggestedDurationMin,
        alternativeNodeId: item.alternativeNodeId,
        actionPayload: item.actionPayload
      };
      return copied;
    });
  }

  private isOutdoorEvent(event: EventEntity): boolean {
    if (!event) {
      return false;
    }
    // 约定: type=0 景点通常为户外场景，其他类型默认按室内/可遮蔽处理。
    return event.type === 0;
  }

  private buildRainReorderTarget(nodes: EventEntity[]): string[] {
    if (!nodes || nodes.length === 0) {
      return [];
    }
    const sorted = nodes.slice().sort((a: EventEntity, b: EventEntity) => {
      const aw = this.isOutdoorEvent(a) ? 1 : 0;
      const bw = this.isOutdoorEvent(b) ? 1 : 0;
      if (aw !== bw) {
        return aw - bw;
      }
      return a.sort_order - b.sort_order;
    });
    return sorted.map((item: EventEntity) => `${item.id}`);
  }

  private isRainWeather(code: string, text: string): boolean {
    const normalizedText = text.toUpperCase();
    return code.indexOf('RAIN') >= 0 ||
      code.indexOf('SHOWER') >= 0 ||
      normalizedText.indexOf('雨') >= 0;
  }

  private isSevereWeather(code: string, text: string): boolean {
    const normalizedText = text.toUpperCase();
    return code.indexOf('STORM') >= 0 ||
      code.indexOf('THUNDER') >= 0 ||
      code.indexOf('HEAVY_RAIN') >= 0 ||
      normalizedText.indexOf('雷暴') >= 0 ||
      normalizedText.indexOf('暴雨') >= 0;
  }

  public buildPromptSummary(context: WeatherContext, preference?: WeatherUserPreference): string {
    const pref = preference ?? DEFAULT_WEATHER_USER_PREFERENCE;
    if (!context.bindings || context.bindings.length === 0) {
      return '天气上下文：暂无可用天气数据，请保持路线可执行性。';
    }
    const lines: string[] = context.bindings.slice(0, 8).map((binding: PlanNodeWeatherBinding) => {
      const weatherText = binding.weather?.conditionText ?? '天气未知';
      const temperature = binding.weather?.temperatureCelsius;
      const tempText = Number.isFinite(temperature) ? `${temperature}°C` : '未知温度';
      return `- 节点${binding.nodeId}: ${weatherText}, ${tempText}, 适宜度${binding.suitabilityScore}`;
    });
    lines.push(`- 路线天气分: ${context.routeSuitability.routeScore}`);
    lines.push(`- 建议: ${context.routeSuitability.summaryText}`);
    lines.push(`- 偏好解释: ${this.preferenceSummary(pref)}`);
    if (context.collabContext && context.collabContext.collabSummary.trim().length > 0) {
      lines.push(`- 多日/多城: ${context.collabContext.collabSummary}`);
    }
    return `天气上下文：\n${lines.join('\n')}`;
  }

  private resolveExecutionGeoByContext(context?: ExecutionContext): GeoPointInput | undefined {
    if (!context) {
      return undefined;
    }
    if (!Number.isFinite(context.lastKnownLatitude) || !Number.isFinite(context.lastKnownLongitude)) {
      return undefined;
    }
    if (context.lastKnownLatitude === 0 && context.lastKnownLongitude === 0) {
      return undefined;
    }
    const latitude = context.lastKnownLatitude as number;
    const longitude = context.lastKnownLongitude as number;
    return {
      latitude: latitude,
      longitude: longitude
    };
  }
  private normalizeCollabOptions(options?: WeatherCollabOptions): Required<WeatherCollabOptions> {
    return {
      enableMultiDay: options?.enableMultiDay !== false,
      enableMultiCity: options?.enableMultiCity !== false
    };
  }

  private buildCollabContext(
    sourceEvents: EventEntity[],
    bindings: PlanNodeWeatherBinding[],
    options: Required<WeatherCollabOptions>
  ): WeatherCollabContext {
    const fallbackPath: string[] = [];
    const dayWindows = options.enableMultiDay ? this.buildDayWindows(sourceEvents, bindings) : [];
    if (options.enableMultiDay && dayWindows.length === 0) {
      fallbackPath.push('DAY_FALLBACK_SINGLE');
    }
    if (!options.enableMultiDay) {
      fallbackPath.push('DAY_DISABLED');
    }

    let cityBuildResult: CityBucketBuildResult;
    if (options.enableMultiCity) {
      cityBuildResult = this.buildCityBuckets(sourceEvents, bindings);
    } else {
      cityBuildResult = {
        buckets: [],
        missCount: 0,
        cappedCount: 0
      };
    }
    if (options.enableMultiCity && cityBuildResult.missCount > 0) {
      fallbackPath.push('CITY_FALLBACK_POINT');
    }
    if (!options.enableMultiCity) {
      fallbackPath.push('CITY_DISABLED');
    }

    const trendTag = this.resolveDominantTrend(dayWindows);
    const collabSummary = this.buildCollabSummary(dayWindows, cityBuildResult.buckets, trendTag);
    return {
      dayWindows: dayWindows,
      cityBuckets: cityBuildResult.buckets,
      collabSummary: collabSummary,
      dayWindowCount: dayWindows.length,
      cityGroupCount: cityBuildResult.buckets.length,
      cityCappedCount: cityBuildResult.cappedCount,
      cityMissCount: cityBuildResult.missCount,
      trendTag: trendTag,
      fallbackPath: fallbackPath.join('|')
    };
  }

  private buildReplacementCandidates(targets: PlanNodeWeatherBinding[]): WeatherSuggestionAlternativeCandidate[] {
    if (!targets || targets.length === 0) {
      return [];
    }
    const sorted = targets
      .slice(1)
      .sort((a: PlanNodeWeatherBinding, b: PlanNodeWeatherBinding) => b.suitabilityScore - a.suitabilityScore);
    return sorted.slice(0, 2).map((item: PlanNodeWeatherBinding) => {
      const candidate: WeatherSuggestionAlternativeCandidate = {
        eventId: item.eventId,
        nodeId: item.nodeId,
        name: item.nodeName || `节点${item.nodeId}`,
        matchReason: item.suitabilityScore >= 80 ? '天气适宜度较高，适合作为替代点' : '可作为保守执行的候选点',
        matchScore: item.suitabilityScore
      };
      return candidate;
    });
  }

  private buildDayWindows(events: EventEntity[], bindings: PlanNodeWeatherBinding[]): WeatherDayWindow[] {
    if (!events || !bindings || events.length === 0 || bindings.length === 0) {
      return [];
    }
    const eventById: Map<number, EventEntity> = new Map<number, EventEntity>();
    events.forEach((event: EventEntity) => {
      eventById.set(event.id, event);
    });

    const grouped = new Map<number, PlanNodeWeatherBinding[]>();
    bindings.forEach((binding: PlanNodeWeatherBinding) => {
      const event = eventById.get(binding.eventId);
      const dayOffset = event ? TimelineDatePolicy.resolveEventDayOffset(event) : 0;
      const list = grouped.get(dayOffset) ?? [];
      list.push(binding);
      grouped.set(dayOffset, list);
    });

    const sortedOffsets = Array.from(grouped.keys()).sort((a: number, b: number) => a - b);
    const windows: WeatherDayWindow[] = [];
    let prev: WeatherDayWindow | null = null;
    sortedOffsets.forEach((offset: number) => {
      const items = grouped.get(offset) ?? [];
      if (items.length === 0) {
        return;
      }
      const score = Math.round(items.reduce((sum: number, item: PlanNodeWeatherBinding) => sum + item.suitabilityScore, 0) / items.length);
      const riskTagSet = new Set<string>();
      items.forEach((item: PlanNodeWeatherBinding) => item.riskTags.forEach((tag: string) => riskTagSet.add(tag)));
      const trendTag = this.resolveDayTrendTag(prev, score, Array.from(riskTagSet.values()));
      const current: WeatherDayWindow = {
        dayOffset: offset,
        windowScore: score,
        riskTags: Array.from(riskTagSet.values()),
        trendTag: trendTag
      };
      windows.push(current);
      prev = current;
    });
    return windows;
  }

  private buildCityBuckets(
    events: EventEntity[],
    bindings: PlanNodeWeatherBinding[]
  ): CityBucketBuildResult {
    if (!events || !bindings || events.length === 0 || bindings.length === 0) {
      const emptyResult: CityBucketBuildResult = { buckets: [], missCount: 0, cappedCount: 0 };
      return emptyResult;
    }
    const eventById: Map<number, EventEntity> = new Map<number, EventEntity>();
    events.forEach((event: EventEntity) => {
      eventById.set(event.id, event);
    });

    let missCount = 0;
    const grouped = new Map<string, PlanNodeWeatherBinding[]>();
    const firstSeenOrderByCity = new Map<string, number>();
    let seenCounter = 0;
    bindings.forEach((binding: PlanNodeWeatherBinding) => {
      const event = eventById.get(binding.eventId);
      const cityCode = (binding.weather?.cityCode || '').trim();
      let cityKey = cityCode;
      if (cityKey.length === 0 && event) {
        cityKey = this.extractCityKeyFromAddress(event.address);
      }
      if (cityKey.length === 0) {
        missCount += 1;
        cityKey = `POINT_${binding.eventId}`;
      }
      const list = grouped.get(cityKey) ?? [];
      list.push(binding);
      grouped.set(cityKey, list);
      if (!firstSeenOrderByCity.has(cityKey)) {
        firstSeenOrderByCity.set(cityKey, seenCounter++);
      }
    });

    const entries = Array.from(grouped.entries());
    entries.sort((a: [string, PlanNodeWeatherBinding[]], b: [string, PlanNodeWeatherBinding[]]) => {
      const orderA = firstSeenOrderByCity.get(a[0]) ?? 0;
      const orderB = firstSeenOrderByCity.get(b[0]) ?? 0;
      return orderA - orderB;
    });
    const cappedCount = entries.length > WeatherContextBuilder.MAX_CITY_BUCKETS
      ? entries.length - WeatherContextBuilder.MAX_CITY_BUCKETS
      : 0;
    const cappedEntries = entries.slice(0, WeatherContextBuilder.MAX_CITY_BUCKETS);

    const buckets: CityWeatherBucket[] = [];
    cappedEntries.forEach((entry: [string, PlanNodeWeatherBinding[]]) => {
      const cityKey = entry[0];
      const items = entry[1];
      const score = Math.round(items.reduce((sum: number, item: PlanNodeWeatherBinding) => sum + item.suitabilityScore, 0) / items.length);
      buckets.push({
        cityKey: cityKey,
        nodeIds: items.map((item: PlanNodeWeatherBinding) => item.nodeId),
        bucketScore: score,
        summaryText: `${cityKey}均分${score}`
      });
    });
    hilog.info(
      0x0000,
      WeatherContextBuilder.TAG,
      `[WEATHER_CITY][bucket] cityGroupCount=${entries.length}, cityCappedCount=${cappedCount}, cityMissCount=${missCount}`
    );
    const result: CityBucketBuildResult = { buckets: buckets, missCount: missCount, cappedCount: cappedCount };
    return result;
  }

  private extractCityKeyFromAddress(address?: string): string {
    const text = (address || '').trim();
    if (text.length === 0) {
      return '';
    }
    const citySuffixIndex = text.indexOf('市');
    if (citySuffixIndex > 0) {
      return text.substring(0, citySuffixIndex + 1);
    }
    return '';
  }

  private resolveDayTrendTag(
    previous: WeatherDayWindow | null,
    currentScore: number,
    currentRiskTags: string[]
  ): WeatherTrendTag {
    if (!previous) {
      return currentRiskTags.indexOf('UNKNOWN') >= 0 ? 'UNKNOWN' : 'STABLE';
    }
    const hasRain = currentRiskTags.indexOf('RAIN') >= 0;
    const prevHasRain = previous.riskTags.indexOf('RAIN') >= 0;
    if (hasRain && prevHasRain) {
      return 'RAIN_PERSIST';
    }
    const delta = currentScore - previous.windowScore;
    if (delta <= -8) {
      return 'IMPROVING';
    }
    if (delta >= 8) {
      return currentRiskTags.indexOf('HEAT') >= 0 ? 'WARMING' : 'STABLE';
    }
    return currentRiskTags.indexOf('UNKNOWN') >= 0 ? 'UNKNOWN' : 'STABLE';
  }

  private resolveDominantTrend(dayWindows: WeatherDayWindow[]): WeatherTrendTag {
    if (!dayWindows || dayWindows.length === 0) {
      return 'UNKNOWN';
    }
    const tags = dayWindows.map((item: WeatherDayWindow) => item.trendTag);
    if (tags.indexOf('RAIN_PERSIST') >= 0) {
      return 'RAIN_PERSIST';
    }
    if (tags.indexOf('WARMING') >= 0) {
      return 'WARMING';
    }
    if (tags.indexOf('IMPROVING') >= 0) {
      return 'IMPROVING';
    }
    if (tags.indexOf('STABLE') >= 0) {
      return 'STABLE';
    }
    return 'UNKNOWN';
  }

  private buildCollabSummary(
    dayWindows: WeatherDayWindow[],
    cityBuckets: CityWeatherBucket[],
    trendTag: WeatherTrendTag
  ): string {
    const dayCount = dayWindows.length;
    const cityCount = cityBuckets.length;
    const trendText = trendTag === 'RAIN_PERSIST'
      ? '降雨持续'
      : (trendTag === 'WARMING'
        ? '升温'
        : (trendTag === 'IMPROVING' ? '改善' : '平稳'));
    if (dayCount <= 0 && cityCount <= 0) {
      return '';
    }
    if (dayCount > 0 && cityCount > 0) {
      return `${cityCount}城${dayCount}日：${trendText}`;
    }
    if (dayCount > 0) {
      return `${dayCount}日趋势：${trendText}`;
    }
    return `${cityCount}城协同已纳入`;
  }

  private preferenceSummary(preference: WeatherUserPreference): string {
    const levelText = (level: number): string => level === 2 ? '高' : (level === 0 ? '低' : '中');
    return `怕热${levelText(preference.heatSensitivity)}、怕雨${levelText(preference.rainSensitivity)}、风险容忍${levelText(preference.weatherRiskTolerance)}`;
  }

  private resolveCurrentGeoPoint(
    input?: GeoPointInput,
    activeEvent?: EventEntity,
    nextNode?: EventEntity
  ): GeoPointInput | undefined {
    if (input && this.isValidCoordinate(input.latitude, input.longitude)) {
      return input;
    }
    if (activeEvent && this.isValidCoordinate(activeEvent.latitude, activeEvent.longitude)) {
      return { latitude: activeEvent.latitude, longitude: activeEvent.longitude };
    }
    if (nextNode && this.isValidCoordinate(nextNode.latitude, nextNode.longitude)) {
      return { latitude: nextNode.latitude, longitude: nextNode.longitude };
    }
    return undefined;
  }

  private resolveNextNode(pendingEvents: EventEntity[], activeEvent?: EventEntity): EventEntity | undefined {
    if (!pendingEvents || pendingEvents.length === 0) {
      return undefined;
    }
    if (!activeEvent) {
      return pendingEvents[0];
    }
    const idx = pendingEvents.findIndex((event: EventEntity) => event.id === activeEvent.id);
    if (idx < 0) {
      return pendingEvents[0];
    }
    if (idx + 1 < pendingEvents.length) {
      return pendingEvents[idx + 1];
    }
    return activeEvent;
  }

  private resolveFutureNodes(pendingEvents: EventEntity[], nextNode?: EventEntity, maxCount: number = 3): EventEntity[] {
    if (!pendingEvents || pendingEvents.length === 0 || !nextNode) {
      return [];
    }
    const start = pendingEvents.findIndex((event: EventEntity) => event.id === nextNode.id);
    const safeStart = start >= 0 ? start : 0;
    return pendingEvents.slice(safeStart, safeStart + maxCount);
  }

  private getOrderedScheduledEvents(events: EventEntity[]): EventEntity[] {
    const source = (events || []).filter((event: EventEntity) => event.status === 1);
    source.sort((a: EventEntity, b: EventEntity) => {
      const dayA = TimelineDatePolicy.resolveEventDayOffset(a);
      const dayB = TimelineDatePolicy.resolveEventDayOffset(b);
      if (dayA !== dayB) {
        return dayA - dayB;
      }
      if (a.sort_order !== b.sort_order) {
        return a.sort_order - b.sort_order;
      }
      return a.id - b.id;
    });
    return source;
  }

  private isValidCoordinate(latitude: number, longitude: number): boolean {
    return Number.isFinite(latitude) &&
      Number.isFinite(longitude) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude === 0 && longitude === 0);
  }

  private resolveTriggerType(tags?: string[]): 'RAIN' | 'HEAT' | 'COLD' | 'WIND' | 'SEVERE_ALERT' | 'UNKNOWN' {
    if (!tags || tags.length === 0) {
      return 'UNKNOWN';
    }
    if (tags.indexOf('SEVERE_ALERT') >= 0 || tags.indexOf('THUNDER') >= 0 || tags.indexOf('STORM') >= 0) {
      return 'RAIN';
    }
    if (tags.indexOf('RAIN') >= 0) {
      return 'RAIN';
    }
    if (tags.indexOf('HEAT') >= 0) {
      return 'HEAT';
    }
    if (tags.indexOf('COLD') >= 0) {
      return 'COLD';
    }
    return 'UNKNOWN';
  }
}





