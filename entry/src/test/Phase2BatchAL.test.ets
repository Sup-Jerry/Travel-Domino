import { describe, it, expect } from '@ohos/hypium';
import { AiGenerateRequest } from '../main/ets/domain/strategy/AiGenerateRequest';
import { StrategyAdaptationEngine, BehaviorContext, DeletedEventInfo } from '../main/ets/domain/strategy/StrategyAdaptationEngine';
import { StrategyBuilder } from '../main/ets/domain/strategy/StrategyBuilder';
import { StrategyPresets } from '../main/ets/domain/strategy/StrategyPresets';
import { StrategyPromptBuilder } from '../main/ets/domain/strategy/StrategyPromptBuilder';
import { StrategyService } from '../main/ets/domain/strategy/StrategyService';
import { DensityLevel, PaceLevel, PreferenceType, EnergyLevel, ComposableStrategy } from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { TravelStrategyMode, TravelStrategyModeHelper } from '../main/ets/domain/strategy/TravelStrategyMode';
import { DailyPoiTarget, TravelStrategyProfile } from '../main/ets/domain/strategy/TravelStrategyProfile';
import { UserBehaviorTracker } from '../main/ets/domain/strategy/UserBehaviorTracker';
import { UserProfileService } from '../main/ets/domain/strategy/UserProfileService';
import { DEFAULT_USER_PROFILE, UserStrategyProfile } from '../main/ets/domain/strategy/UserStrategyProfile';
import { WeatherCollabContext, WeatherTrendTag } from '../main/ets/domain/services/WeatherModels';
import { PreferenceManager } from '../main/ets/common/utils/PreferenceManager';

function createStrategy(): ComposableStrategy {
  return {
    density: DensityLevel.MEDIUM,
    pace: PaceLevel.BALANCED,
    preference: PreferenceType.BALANCED,
    energy: EnergyLevel.MEDIUM
  };
}

function createDeletion(duration: number, trafficTime: number): DeletedEventInfo {
  return {
    eventType: 1,
    duration,
    trafficTime,
    timestamp: Date.now()
  };
}

class UserProfileServiceHooksAL {
  private readonly originLoad: Object;
  private readonly originSave: Object;

  constructor() {
    this.originLoad = Reflect.get(UserProfileService, 'loadProfile') as Object;
    this.originSave = Reflect.get(UserProfileService, 'saveProfile') as Object;
  }

  setLoad(fn: () => Promise<UserStrategyProfile>): void {
    Reflect.set(UserProfileService, 'loadProfile', fn);
  }

  setSave(fn: (profile: UserStrategyProfile) => Promise<void>): void {
    Reflect.set(UserProfileService, 'saveProfile', fn);
  }

  restore(): void {
    Reflect.set(UserProfileService, 'loadProfile', this.originLoad);
    Reflect.set(UserProfileService, 'saveProfile', this.originSave);
  }
}

class PreferenceManagerHooksAL {
  private readonly originGetInstance: Object;

  constructor() {
    this.originGetInstance = Reflect.get(PreferenceManager, 'getInstance') as Object;
  }

  setGetInstance(fn: () => Object): void {
    Reflect.set(PreferenceManager, 'getInstance', fn);
  }

  restore(): void {
    Reflect.set(PreferenceManager, 'getInstance', this.originGetInstance);
  }
}

class PreferenceManagerStubAL {
  private readonly getter: (() => Promise<UserStrategyProfile>) | null;
  private readonly setter: ((profile: UserStrategyProfile) => Promise<void>) | null;

  constructor(
    getter: (() => Promise<UserStrategyProfile>) | null = null,
    setter: ((profile: UserStrategyProfile) => Promise<void>) | null = null
  ) {
    this.getter = getter;
    this.setter = setter;
  }

  public async getUserStrategyProfile(): Promise<UserStrategyProfile> {
    if (this.getter) {
      return this.getter();
    }
    throw new Error('getter_not_set');
  }

  public async setUserStrategyProfile(profile: UserStrategyProfile): Promise<void> {
    if (this.setter) {
      await this.setter(profile);
      return;
    }
    throw new Error('setter_not_set');
  }
}

function cloneDefaultProfile(overrides?: UserStrategyProfile): UserStrategyProfile {
  const base: UserStrategyProfile = {
    avgDensity: DEFAULT_USER_PROFILE.avgDensity,
    avgPace: DEFAULT_USER_PROFILE.avgPace,
    avgPreference: DEFAULT_USER_PROFILE.avgPreference,
    avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
    modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
    sampleCount: DEFAULT_USER_PROFILE.sampleCount,
    updatedAt: DEFAULT_USER_PROFILE.updatedAt,
    manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
    consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
    consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
    lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
  };
  if (!overrides) {
    return base;
  }
  base.avgDensity = overrides.avgDensity;
  base.avgPace = overrides.avgPace;
  base.avgPreference = overrides.avgPreference;
  base.avgEnergy = overrides.avgEnergy;
  base.modeFrequency = overrides.modeFrequency;
  base.sampleCount = overrides.sampleCount;
  base.updatedAt = overrides.updatedAt;
  base.manualOverrideEnabled = overrides.manualOverrideEnabled;
  base.consistencyMatchCount = overrides.consistencyMatchCount;
  base.consistencyMismatchCount = overrides.consistencyMismatchCount;
  base.lastConsistencyCheckAt = overrides.lastConsistencyCheckAt;
  return base;
}

function createOutOfRangeStrategy(density: number, pace: number, preference: number, energy: number): ComposableStrategy {
  return {
    density: density as DensityLevel,
    pace: pace as PaceLevel,
    preference: preference as PreferenceType,
    energy: energy as EnergyLevel
  };
}

function createWeatherCollabContext(trendTag: WeatherTrendTag): WeatherCollabContext {
  return {
    dayWindows: [],
    cityBuckets: [],
    collabSummary: '',
    dayWindowCount: 0,
    cityGroupCount: 0,
    cityCappedCount: 0,
    cityMissCount: 0,
    trendTag: trendTag,
    fallbackPath: ''
  };
}

export default function phase2BatchALTest() {
  describe('phase2BatchAL_types_and_enums', () => {
    it('normal: ai_generate_request_should_hold_required_fields', 0, () => {
      // Arrange
      // Act
      // Assert
      const req: AiGenerateRequest = { userPrompt: 'beijing trip', planId: 1, strategyMode: TravelStrategyMode.DEFAULT };
      expect(req.userPrompt).assertEqual('beijing trip');
      expect(req.strategyMode).assertEqual(TravelStrategyMode.DEFAULT);
    });

    it('boundary: ai_generate_request_should_allow_zero_plan_id_and_optional_profile', 0, () => {
      // Arrange
      // Act
      // Assert
      const req: AiGenerateRequest = {
        userPrompt: '', planId: 0, strategyMode: TravelStrategyMode.SOLDIER,
        strategyProfile: { dailyPoiTarget: { min: 5, max: 8 }, moveTolerance: 45, slackRatio: 0.1, preferCompactSchedule: true, avoidBacktracking: false }
      };
      expect(req.planId).assertEqual(0);
      expect(req.strategyProfile !== undefined).assertTrue();
    });

    it('invalid: ai_generate_request_runtime_object_missing_fields_should_be_detectable', 0, () => {
      // Arrange
      // Act
      // Assert
      const invalidReq = { userPrompt: 'x' } as AiGenerateRequest;
      expect(invalidReq.planId === undefined).assertTrue();
      expect(invalidReq.strategyMode === undefined).assertTrue();
    });

    it('normal: strategy_dimensions_should_keep_core_enum_values', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(DensityLevel.MEDIUM).assertEqual(1);
      expect(PaceLevel.BALANCED).assertEqual(1);
      expect(PreferenceType.BALANCED).assertEqual(0);
      expect(EnergyLevel.MEDIUM).assertEqual(1);
    });

    it('boundary: strategy_dimensions_should_keep_upper_enum_bounds', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(DensityLevel.HIGH).assertEqual(2);
      expect(PaceLevel.COMPACT).assertEqual(2);
      expect(PreferenceType.NIGHT).assertEqual(4);
      expect(EnergyLevel.HIGH).assertEqual(2);
    });

    it('invalid: strategy_dimensions_unknown_value_should_not_match_defined_enums', 0, () => {
      // Arrange
      // Act
      // Assert
      const unknown: number = Number('99');
      const matched = unknown === DensityLevel.LOW || unknown === DensityLevel.MEDIUM || unknown === DensityLevel.HIGH;
      expect(matched).assertFalse();
    });

    it('normal: travel_strategy_profile_should_accept_optional_preference_and_energy', 0, () => {
      // Arrange
      // Act
      // Assert
      const profile: TravelStrategyProfile = {
        dailyPoiTarget: { min: 3, max: 5 }, moveTolerance: 35, slackRatio: 0.25,
        preferCompactSchedule: false, avoidBacktracking: false,
        preferenceType: PreferenceType.SCENIC, energyLevel: EnergyLevel.MEDIUM
      };
      expect(profile.dailyPoiTarget.min).assertEqual(3);
      expect(profile.preferenceType).assertEqual(PreferenceType.SCENIC);
    });

    it('boundary: travel_strategy_profile_should_allow_equal_min_max_target', 0, () => {
      // Arrange
      // Act
      // Assert
      const target: DailyPoiTarget = { min: 4, max: 4 };
      expect(target.min === target.max).assertTrue();
    });

    it('invalid: travel_strategy_profile_runtime_object_missing_target_should_be_detectable', 0, () => {
      // Arrange
      // Act
      // Assert
      const profile = { moveTolerance: 30 } as TravelStrategyProfile;
      expect(profile.dailyPoiTarget === undefined).assertTrue();
    });

    it('normal: user_strategy_profile_default_should_keep_baseline_values', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(DEFAULT_USER_PROFILE.avgDensity).assertEqual(1);
      expect(DEFAULT_USER_PROFILE.sampleCount).assertEqual(0);
    });

    it('boundary: user_strategy_profile_default_should_keep_counters_non_negative', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(Number(DEFAULT_USER_PROFILE.consistencyMatchCount) >= 0).assertTrue();
      expect(Number(DEFAULT_USER_PROFILE.consistencyMismatchCount) >= 0).assertTrue();
    });

    it('invalid: user_strategy_profile_copy_mutation_should_not_change_default_constant', 0, () => {
      // Arrange
      // Act
      // Assert
      const copied: UserStrategyProfile = cloneDefaultProfile();
      copied.sampleCount = 10;
      expect(DEFAULT_USER_PROFILE.sampleCount).assertEqual(0);
    });
  });

  describe('phase2BatchAL_strategy_core', () => {
    it('normal: analyze_and_decide_should_detect_high_intensity_deletions', 0, () => {
      // Arrange
      // Act
      // Assert
      const context: BehaviorContext = {
        recentDeletions: [createDeletion(120, 10), createDeletion(100, 20), createDeletion(95, 15)],
        recentSkips: 0,
        avgTrafficMinutes: 0,
        currentStrategy: createStrategy(),
        planId: 1
      };
      const decision = StrategyAdaptationEngine.analyzeAndDecide(context);
      expect(String(decision?.reason || '')).assertEqual('HIGH_INTENSITY_DELETIONS');
    });

    it('boundary: analyze_and_decide_should_return_null_when_deletions_less_than_three', 0, () => {
      // Arrange
      // Act
      // Assert
      const context: BehaviorContext = {
        recentDeletions: [createDeletion(120, 10), createDeletion(100, 20)],
        recentSkips: 0,
        avgTrafficMinutes: 0,
        currentStrategy: createStrategy(),
        planId: 1
      };
      expect(StrategyAdaptationEngine.analyzeAndDecide(context) === null).assertTrue();
    });

    it('invalid: analyze_and_decide_should_fallback_to_traffic_rule_for_non_intense_data', 0, () => {
      // Arrange
      // Act
      // Assert
      const context: BehaviorContext = {
        recentDeletions: [createDeletion(10, 55), createDeletion(20, 50), createDeletion(30, 45)],
        recentSkips: 0,
        avgTrafficMinutes: 0,
        currentStrategy: createStrategy(),
        planId: 1
      };
      const decision = StrategyAdaptationEngine.analyzeAndDecide(context);
      expect(String(decision?.reason || '')).assertEqual('EXCESSIVE_TRAFFIC');
    });

    it('boundary: analyze_and_decide_should_return_null_when_traffic_is_not_excessive', 0, () => {
      // Arrange
      // Act
      // Assert
      const context: BehaviorContext = {
        recentDeletions: [createDeletion(10, 15), createDeletion(20, 35), createDeletion(30, 40)],
        recentSkips: 0,
        avgTrafficMinutes: 0,
        currentStrategy: createStrategy(),
        planId: 1
      };
      expect(StrategyAdaptationEngine.analyzeAndDecide(context) === null).assertTrue();
    });

    it('normal: apply_adjustment_should_apply_and_clamp_values', 0, () => {
      // Arrange
      // Act
      // Assert
      const current: ComposableStrategy = { density: 0, pace: 1, preference: 0, energy: 0 };
      const adjusted = StrategyAdaptationEngine.applyAdjustment(current, {
        reason: 'USER_FEEDBACK',
        adjustments: { density: -1, pace: 1, energy: 1, preference: PreferenceType.CULTURE },
        message: 'x'
      });
      expect(adjusted.density).assertEqual(0);
      expect(adjusted.pace).assertEqual(2);
      expect(adjusted.energy).assertEqual(1);
      expect(adjusted.preference).assertEqual(PreferenceType.CULTURE);
    });

    it('boundary: apply_adjustment_without_changes_should_keep_original_values', 0, () => {
      // Arrange
      // Act
      // Assert
      const current = createStrategy();
      const adjusted = StrategyAdaptationEngine.applyAdjustment(current, { reason: 'USER_FEEDBACK', adjustments: {}, message: 'x' });
      expect(adjusted.density).assertEqual(current.density);
      expect(adjusted.pace).assertEqual(current.pace);
      expect(adjusted.energy).assertEqual(current.energy);
      expect(adjusted.preference).assertEqual(current.preference);
    });

    it('invalid: apply_adjustment_should_recover_invalid_current_values_by_clamp', 0, () => {
      // Arrange
      // Act
      // Assert
      const current = createOutOfRangeStrategy(-10, 100, 0, -5);
      const adjusted = StrategyAdaptationEngine.applyAdjustment(current, { reason: 'USER_FEEDBACK', adjustments: { density: 1, pace: -1, energy: 1 }, message: 'x' });
      expect(adjusted.density).assertEqual(0);
      expect(adjusted.pace).assertEqual(2);
      expect(adjusted.energy).assertEqual(0);
    });

    it('normal: adapt_to_weather_should_reduce_density_when_route_score_low', 0, () => {
      // Arrange
      // Act
      // Assert
      const decision = StrategyAdaptationEngine.adaptToWeather(undefined, 50, createStrategy());
      expect(String(decision?.reason || '')).assertEqual('WEATHER_RISK');
      expect(Number(decision?.adjustments.density)).assertEqual(-1);
    });

    it('boundary: adapt_to_weather_rain_persist_should_reduce_density_without_preference_change_when_score_is_70', 0, () => {
      // Arrange
      // Act
      // Assert
      const decision = StrategyAdaptationEngine.adaptToWeather(createWeatherCollabContext('RAIN_PERSIST'), 70, createStrategy());
      expect(String(decision?.reason || '')).assertEqual('WEATHER_RISK');
      expect(decision?.adjustments.preference === undefined).assertTrue();
    });

    it('normal: adapt_to_weather_rain_persist_should_keep_culture_preference_when_already_indoor_friendly', 0, () => {
      // Arrange
      // Act
      // Assert
      const current = createStrategy();
      current.preference = PreferenceType.CULTURE;
      const decision = StrategyAdaptationEngine.adaptToWeather(createWeatherCollabContext('RAIN_PERSIST'), 65, current);
      expect(String(decision?.reason || '')).assertEqual('WEATHER_RISK');
      expect(Number(decision?.adjustments.density)).assertEqual(-1);
      expect(Number(decision?.adjustments.preference)).assertEqual(PreferenceType.CULTURE);
    });

    it('invalid: adapt_to_weather_should_return_null_for_unknown_trend_and_safe_score', 0, () => {
      // Arrange
      // Act
      // Assert
      const decision = StrategyAdaptationEngine.adaptToWeather(createWeatherCollabContext('UNKNOWN'), 85, createStrategy());
      expect(decision === null).assertTrue();
    });

    it('normal: strategy_builder_build_profile_should_map_medium_levels', 0, () => {
      // Arrange
      // Act
      // Assert
      const profile = StrategyBuilder.buildProfile(createStrategy());
      expect(profile.dailyPoiTarget.min).assertEqual(3);
      expect(profile.dailyPoiTarget.max).assertEqual(5);
      expect(profile.moveTolerance).assertEqual(35);
      expect(profile.slackRatio).assertEqual(0.25);
    });

    it('boundary: strategy_builder_build_profile_should_map_low_and_high_edges', 0, () => {
      // Arrange
      // Act
      // Assert
      const strategy: ComposableStrategy = { density: 2, pace: 0, preference: 4, energy: 0 };
      const profile = StrategyBuilder.buildProfile(strategy);
      expect(profile.dailyPoiTarget.min).assertEqual(6);
      expect(profile.dailyPoiTarget.max).assertEqual(8);
      expect(profile.moveTolerance).assertEqual(30);
      expect(profile.slackRatio).assertEqual(0.4);
    });

    it('boundary: strategy_builder_build_profile_should_map_low_density_target_range', 0, () => {
      // Arrange
      const strategy: ComposableStrategy = { density: 0, pace: 1, preference: 2, energy: 1 };
      // Act
      const profile = StrategyBuilder.buildProfile(strategy);
      // Assert
      expect(profile.dailyPoiTarget.min).assertEqual(2);
      expect(profile.dailyPoiTarget.max).assertEqual(4);
    });

    it('invalid: strategy_builder_build_profile_should_fallback_for_out_of_range_levels', 0, () => {
      // Arrange
      // Act
      // Assert
      const strategy = createOutOfRangeStrategy(99, 99, 99, 99);
      const profile = StrategyBuilder.buildProfile(strategy);
      expect(profile.dailyPoiTarget.min).assertEqual(3);
      expect(profile.dailyPoiTarget.max).assertEqual(5);
      expect(profile.moveTolerance).assertEqual(35);
      expect(profile.slackRatio).assertEqual(0.25);
    });

    it('normal: strategy_presets_get_profile_should_return_soldier_profile', 0, () => {
      // Arrange
      // Act
      // Assert
      const profile = StrategyPresets.getProfile(TravelStrategyMode.SOLDIER);
      expect(profile.dailyPoiTarget.min).assertEqual(5);
      expect(profile.moveTolerance).assertEqual(45);
    });

    it('boundary: strategy_presets_get_profile_should_return_leisure_profile', 0, () => {
      // Arrange
      // Act
      // Assert
      const profile = StrategyPresets.getProfile(TravelStrategyMode.LEISURE);
      expect(profile.dailyPoiTarget.min).assertEqual(3);
      expect(profile.slackRatio).assertEqual(0.4);
    });

    it('invalid: strategy_presets_get_profile_unknown_mode_should_fallback_default', 0, () => {
      // Arrange
      // Act
      // Assert
      const profile = StrategyPresets.getProfile(99 as TravelStrategyMode);
      expect(profile.dailyPoiTarget.min).assertEqual(4);
      expect(profile.slackRatio).assertEqual(0);
    });

    it('normal: strategy_prompt_builder_system_prompt_should_include_soldier_range', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyPromptBuilder.buildSystemPromptFragment(TravelStrategyMode.SOLDIER).includes('5-8')).assertTrue();
    });

    it('boundary: strategy_prompt_builder_system_prompt_should_include_leisure_range', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyPromptBuilder.buildSystemPromptFragment(TravelStrategyMode.LEISURE).includes('3-5')).assertTrue();
    });

    it('invalid: strategy_prompt_builder_system_prompt_unknown_mode_should_be_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyPromptBuilder.buildSystemPromptFragment(TravelStrategyMode.DEFAULT)).assertEqual('');
    });

    it('normal: strategy_prompt_builder_explanation_should_return_non_empty_for_soldier', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyPromptBuilder.buildExplanation(TravelStrategyMode.SOLDIER);
      expect(text.length > 0).assertTrue();
      expect(text.includes('AI')).assertFalse();
    });

    it('boundary: strategy_prompt_builder_explanation_should_return_non_empty_for_leisure', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyPromptBuilder.buildExplanation(TravelStrategyMode.LEISURE).length > 0).assertTrue();
    });

    it('invalid: strategy_prompt_builder_explanation_unknown_mode_should_fallback_ai_hint', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyPromptBuilder.buildExplanation(TravelStrategyMode.DEFAULT).includes('AI')).assertTrue();
    });

    it('normal: strategy_service_build_strategy_prompt_should_return_soldier_prompt', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyService.buildStrategyPrompt(1).includes('5-8')).assertTrue();
    });

    it('boundary: strategy_service_build_strategy_prompt_should_return_leisure_prompt', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyService.buildStrategyPrompt(2).includes('3-5')).assertTrue();
    });

    it('invalid: strategy_service_build_strategy_prompt_unknown_mode_should_be_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyService.buildStrategyPrompt(99)).assertEqual('');
    });

    it('normal: strategy_service_build_composable_prompt_should_include_strategy_lines', 0, () => {
      // Arrange
      // Act
      // Assert
      const prompt = StrategyService.buildComposablePrompt({ density: 2, pace: 2, preference: 1, energy: 2 });
      expect(prompt.length > 0).assertTrue();
      expect(prompt.split('\n').length >= 5).assertTrue();
    });

    it('boundary: strategy_service_build_composable_prompt_balanced_preference_should_have_one_less_line', 0, () => {
      // Arrange
      // Act
      // Assert
      const prompt = StrategyService.buildComposablePrompt({ density: 1, pace: 1, preference: 0, energy: 1 });
      expect(prompt.split('\n').length >= 4).assertTrue();
    });

    it('invalid: strategy_service_build_composable_prompt_unknown_preference_should_still_return_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const prompt = StrategyService.buildComposablePrompt(createOutOfRangeStrategy(1, 1, 99, 1));
      expect(prompt.length > 0).assertTrue();
    });

    it('normal: strategy_service_build_strategy_explanation_should_return_soldier_text', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildStrategyExplanation(1);
      expect(text.length > 0).assertTrue();
      expect(text.includes('AI')).assertFalse();
    });

    it('boundary: strategy_service_build_strategy_explanation_should_return_leisure_text', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyService.buildStrategyExplanation(2).length > 0).assertTrue();
    });

    it('invalid: strategy_service_build_strategy_explanation_unknown_mode_should_return_ai_text', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyService.buildStrategyExplanation(999).includes('AI')).assertTrue();
    });

    it('normal: strategy_service_build_composable_explanation_should_include_all_sections', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildComposableExplanation({ density: 2, pace: 2, preference: 4, energy: 2 });
      expect(text.split('+').length).assertEqual(4);
    });

    it('boundary: strategy_service_build_composable_explanation_should_support_balanced_values', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(StrategyService.buildComposableExplanation(createStrategy()).length > 0).assertTrue();
    });

    it('invalid: strategy_service_build_composable_explanation_unknown_values_should_still_be_stable', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildComposableExplanation(createOutOfRangeStrategy(99, 99, 99, 99));
      expect(text.length > 0).assertTrue();
    });

    it('normal: strategy_service_weather_constraint_should_hit_mode_soldier_rain_branch', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildWeatherAwareConstraint(createStrategy(), 65, ['RAIN'], 'RAIN_PERSIST', 1);
      expect(text.length > 0).assertTrue();
      expect(text.includes('室内')).assertTrue();
    });

    it('boundary: strategy_service_weather_constraint_should_keep_mode_leisure_stable_branch', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildWeatherAwareConstraint(createStrategy(), 90, [], 'STABLE', 2);
      expect(text.length > 0).assertTrue();
      expect(text.includes('原策略')).assertTrue();
    });

    it('invalid: strategy_service_weather_constraint_should_fallback_generic_when_no_rule_matches', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildWeatherAwareConstraint(createStrategy(), 80, [], 'UNKNOWN', 0);
      expect(text.length > 0).assertTrue();
      expect(text.includes('联合评估')).assertTrue();
    });

    it('normal: travel_strategy_mode_helper_display_name_should_return_soldier', 0, () => {
      // Arrange
      // Act
      // Assert
      const name = TravelStrategyModeHelper.getDisplayName(TravelStrategyMode.SOLDIER);
      expect(name.length > 0).assertTrue();
      expect(name === TravelStrategyModeHelper.getDisplayName(TravelStrategyMode.DEFAULT)).assertFalse();
    });

    it('boundary: travel_strategy_mode_helper_display_name_should_return_leisure', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(TravelStrategyModeHelper.getDisplayName(TravelStrategyMode.LEISURE).length > 0).assertTrue();
    });

    it('invalid: travel_strategy_mode_helper_display_name_unknown_mode_should_fallback_default', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(TravelStrategyModeHelper.getDisplayName(99 as TravelStrategyMode)).assertEqual(TravelStrategyModeHelper.getDisplayName(TravelStrategyMode.DEFAULT));
    });

    it('normal: travel_strategy_mode_helper_icon_should_return_soldier_icon', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(TravelStrategyModeHelper.getIcon(TravelStrategyMode.SOLDIER).length > 0).assertTrue();
    });

    it('boundary: travel_strategy_mode_helper_icon_should_return_leisure_icon', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(TravelStrategyModeHelper.getIcon(TravelStrategyMode.LEISURE).length > 0).assertTrue();
    });

    it('invalid: travel_strategy_mode_helper_icon_unknown_mode_should_fallback_default_icon', 0, () => {
      // Arrange
      // Act
      // Assert
      expect(TravelStrategyModeHelper.getIcon(99 as TravelStrategyMode)).assertEqual(TravelStrategyModeHelper.getIcon(TravelStrategyMode.DEFAULT));
    });
  });

  describe('phase2BatchAL_behavior_tracker', () => {
    it('normal: user_behavior_tracker_record_deletion_should_append_record', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordDeletion(1, 60, 20);
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentDeletions.length).assertEqual(1);
    });

    it('boundary: user_behavior_tracker_record_deletion_should_keep_max_window_ten', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      for (let i = 0; i < 11; i++) {
        tracker.recordDeletion(1, 30 + i, 10);
      }
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentDeletions.length).assertEqual(10);
    });

    it('invalid: user_behavior_tracker_record_deletion_should_keep_invalid_numeric_values_for_diagnosis', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordDeletion(1, -1, -5);
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentDeletions[0].duration).assertEqual(-1);
      expect(context.recentDeletions[0].trafficTime).assertEqual(-5);
    });

    it('normal: user_behavior_tracker_record_skip_should_increase_counter', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordSkip(1);
      tracker.recordSkip(2);
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentSkips).assertEqual(2);
    });

    it('boundary: user_behavior_tracker_record_skip_should_accept_zero_event_id', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordSkip(0);
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentSkips).assertEqual(1);
    });

    it('invalid: user_behavior_tracker_record_skip_should_accept_nan_event_id_without_throw', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordSkip(Number.NaN);
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentSkips).assertEqual(1);
    });

    it('normal: user_behavior_tracker_should_trigger_adaptation_when_deletions_reach_five', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      for (let i = 0; i < 5; i++) {
        tracker.recordDeletion(1, 60, 20);
      }
      expect(tracker.shouldTriggerAdaptation()).assertTrue();
    });

    it('boundary: user_behavior_tracker_should_not_trigger_when_deletions_are_four', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      for (let i = 0; i < 4; i++) {
        tracker.recordDeletion(1, 60, 20);
      }
      expect(tracker.shouldTriggerAdaptation()).assertFalse();
    });

    it('invalid: user_behavior_tracker_should_not_trigger_after_reset', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      for (let i = 0; i < 5; i++) {
        tracker.recordDeletion(1, 60, 20);
      }
      tracker.reset();
      expect(tracker.shouldTriggerAdaptation()).assertFalse();
    });

    it('normal: user_behavior_tracker_get_context_should_compute_avg_traffic', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordDeletion(1, 60, 20);
      tracker.recordDeletion(1, 60, 40);
      const context = tracker.getBehaviorContext(7, createStrategy());
      expect(context.avgTrafficMinutes).assertEqual(30);
      expect(context.planId).assertEqual(7);
    });

    it('boundary: user_behavior_tracker_get_context_should_return_zero_avg_when_empty', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.avgTrafficMinutes).assertEqual(0);
      expect(context.recentDeletions.length).assertEqual(0);
    });

    it('invalid: user_behavior_tracker_get_context_should_return_array_copy', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordDeletion(1, 60, 20);
      const context = tracker.getBehaviorContext(1, createStrategy());
      context.recentDeletions.push(createDeletion(1, 1));
      const contextAgain = tracker.getBehaviorContext(1, createStrategy());
      expect(contextAgain.recentDeletions.length).assertEqual(1);
    });

    it('normal: user_behavior_tracker_reset_should_clear_deletions_and_skips', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordDeletion(1, 60, 20);
      tracker.recordSkip(1);
      tracker.reset();
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentDeletions.length).assertEqual(0);
      expect(context.recentSkips).assertEqual(0);
    });

    it('boundary: user_behavior_tracker_reset_should_be_safe_on_empty_tracker', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.reset();
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentDeletions.length).assertEqual(0);
    });

    it('invalid: user_behavior_tracker_reset_should_be_idempotent', 0, () => {
      // Arrange
      // Act
      // Assert
      const tracker = new UserBehaviorTracker();
      tracker.recordSkip(1);
      tracker.reset();
      tracker.reset();
      const context = tracker.getBehaviorContext(1, createStrategy());
      expect(context.recentSkips).assertEqual(0);
    });
  });

  describe('phase2BatchAL_user_profile_service', () => {
    it('normal: user_profile_service_record_usage_should_update_soldier_averages_and_frequency', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      let saved: UserStrategyProfile = cloneDefaultProfile();
      let savedAssigned = false;
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile());
      hooks.setSave(async (profile: UserStrategyProfile): Promise<void> => { saved = profile; savedAssigned = true; });
      try {
        await UserProfileService.recordStrategyUsage(1);
      } finally {
        hooks.restore();
      }
      expect(savedAssigned).assertTrue();
      const savedProfile = saved;
      expect(String(savedProfile.modeFrequency).includes('"1":1')).assertTrue();
      expect(Number(savedProfile.sampleCount)).assertEqual(1);
    });

    it('boundary: user_profile_service_record_usage_custom_mode_should_use_custom_strategy_values', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      let saved: UserStrategyProfile = cloneDefaultProfile();
      let savedAssigned = false;
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile());
      hooks.setSave(async (profile: UserStrategyProfile): Promise<void> => { saved = profile; savedAssigned = true; });
      try {
        await UserProfileService.recordStrategyUsage(-1, { density: 2, pace: 2, preference: 3, energy: 2 });
      } finally {
        hooks.restore();
      }
      expect(savedAssigned).assertTrue();
      const savedProfile = saved;
      expect(String(savedProfile.modeFrequency).includes('"-1":1')).assertTrue();
    });

    it('invalid: user_profile_service_record_usage_custom_mode_without_strategy_should_fallback_default_frequency_bucket', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      let saved: UserStrategyProfile = cloneDefaultProfile();
      let savedAssigned = false;
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile());
      hooks.setSave(async (profile: UserStrategyProfile): Promise<void> => { saved = profile; savedAssigned = true; });
      try {
        await UserProfileService.recordStrategyUsage(-1);
      } finally {
        hooks.restore();
      }
      expect(savedAssigned).assertTrue();
      const savedProfile = saved;
      expect(savedProfile.modeFrequency.length > 0).assertTrue();
    });

    it('normal: user_profile_service_recommended_strategy_should_return_rounded_values', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
        avgDensity: 1.6,
        avgPace: 1.4,
        avgPreference: 3.2,
        avgEnergy: 1.9,
        modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: 4,
        updatedAt: DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
        consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
        consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
        lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
      }));
      let strategy: ComposableStrategy | null = null;
      try {
        strategy = await UserProfileService.getRecommendedStrategy();
      } finally {
        hooks.restore();
      }
      expect(strategy !== null).assertTrue();
      expect(Number(strategy?.density)).assertEqual(2);
      expect(Number(strategy?.preference)).assertEqual(3);
    });

    it('boundary: user_profile_service_recommended_strategy_should_allow_manual_override_with_low_sample', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
        avgDensity: DEFAULT_USER_PROFILE.avgDensity,
        avgPace: DEFAULT_USER_PROFILE.avgPace,
        avgPreference: DEFAULT_USER_PROFILE.avgPreference,
        avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
        modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: 0,
        updatedAt: DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: true,
        consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
        consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
        lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
      }));
      let strategy: ComposableStrategy | null = null;
      try {
        strategy = await UserProfileService.getRecommendedStrategy();
      } finally {
        hooks.restore();
      }
      expect(strategy !== null).assertTrue();
    });

    it('invalid: user_profile_service_recommended_strategy_should_clamp_out_of_range_values', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
        avgDensity: 99,
        avgPace: -10,
        avgPreference: 99,
        avgEnergy: -1,
        modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: 10,
        updatedAt: DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
        consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
        consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
        lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
      }));
      let strategy: ComposableStrategy | null = null;
      try {
        strategy = await UserProfileService.getRecommendedStrategy();
      } finally {
        hooks.restore();
      }
      expect(Number(strategy?.density)).assertEqual(2);
      expect(Number(strategy?.pace)).assertEqual(0);
      expect(Number(strategy?.preference)).assertEqual(4);
      expect(Number(strategy?.energy)).assertEqual(0);
    });

    it('normal: user_profile_service_recommendation_hint_should_return_text_when_sample_enough', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
        avgDensity: 1.8,
        avgPace: 1.9,
        avgPreference: DEFAULT_USER_PROFILE.avgPreference,
        avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
        modeFrequency: '{"1":4}',
        sampleCount: 4,
        updatedAt: DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
        consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
        consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
        lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
      }));
      let hint = '';
      try {
        hint = await UserProfileService.getRecommendationHint();
      } finally {
        hooks.restore();
      }
      expect(hint.length > 0).assertTrue();
    });

    it('boundary: user_profile_service_recommendation_hint_should_return_text_for_manual_override', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
        avgDensity: DEFAULT_USER_PROFILE.avgDensity,
        avgPace: DEFAULT_USER_PROFILE.avgPace,
        avgPreference: DEFAULT_USER_PROFILE.avgPreference,
        avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
        modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: 0,
        updatedAt: DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: true,
        consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
        consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
        lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
      }));
      let hint = '';
      try {
        hint = await UserProfileService.getRecommendationHint();
      } finally {
        hooks.restore();
      }
      expect(hint.length > 0).assertTrue();
    });

    it('invalid: user_profile_service_recommendation_hint_should_be_empty_when_sample_not_enough', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      hooks.setLoad(async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
        avgDensity: DEFAULT_USER_PROFILE.avgDensity,
        avgPace: DEFAULT_USER_PROFILE.avgPace,
        avgPreference: DEFAULT_USER_PROFILE.avgPreference,
        avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
        modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
        sampleCount: 2,
        updatedAt: DEFAULT_USER_PROFILE.updatedAt,
        manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
        consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
        consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
        lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
      }));
      let hint = 'x';
      try {
        hint = await UserProfileService.getRecommendationHint();
      } finally {
        hooks.restore();
      }
      expect(hint).assertEqual('');
    });

    it('normal: user_profile_service_load_profile_should_delegate_to_preference_manager', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAL();
      hooks.setGetInstance((): Object => new PreferenceManagerStubAL(
        async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
          avgDensity: DEFAULT_USER_PROFILE.avgDensity,
          avgPace: DEFAULT_USER_PROFILE.avgPace,
          avgPreference: DEFAULT_USER_PROFILE.avgPreference,
          avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
          modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
          sampleCount: 9,
          updatedAt: DEFAULT_USER_PROFILE.updatedAt,
          manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
          consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
          consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
          lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
        })
      ));
      let profile: UserStrategyProfile = DEFAULT_USER_PROFILE;
      try {
        profile = await UserProfileService.loadProfile();
      } finally {
        hooks.restore();
      }
      expect(profile.sampleCount).assertEqual(9);
    });

    it('boundary: user_profile_service_load_profile_should_support_manual_override_field', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAL();
      hooks.setGetInstance((): Object => new PreferenceManagerStubAL(
        async (): Promise<UserStrategyProfile> => cloneDefaultProfile({
          avgDensity: DEFAULT_USER_PROFILE.avgDensity,
          avgPace: DEFAULT_USER_PROFILE.avgPace,
          avgPreference: DEFAULT_USER_PROFILE.avgPreference,
          avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
          modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
          sampleCount: DEFAULT_USER_PROFILE.sampleCount,
          updatedAt: DEFAULT_USER_PROFILE.updatedAt,
          manualOverrideEnabled: true,
          consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
          consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
          lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
        })
      ));
      let profile: UserStrategyProfile = DEFAULT_USER_PROFILE;
      try {
        profile = await UserProfileService.loadProfile();
      } finally {
        hooks.restore();
      }
      expect(profile.manualOverrideEnabled === true).assertTrue();
    });

    it('invalid: user_profile_service_load_profile_should_throw_when_manager_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAL();
      hooks.setGetInstance((): Object => new PreferenceManagerStubAL(
        async (): Promise<UserStrategyProfile> => { throw new Error('load_failed'); }
      ));
      let message = '';
      try {
        await UserProfileService.loadProfile();
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('load_failed');
    });

    it('normal: user_profile_service_save_profile_should_delegate_to_preference_manager', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAL();
      let saved: UserStrategyProfile = cloneDefaultProfile();
      let savedAssigned = false;
      hooks.setGetInstance((): Object => new PreferenceManagerStubAL(
        null,
        async (profile: UserStrategyProfile): Promise<void> => { saved = profile; savedAssigned = true; }
      ));
      try {
        await UserProfileService.saveProfile(cloneDefaultProfile({
          avgDensity: DEFAULT_USER_PROFILE.avgDensity,
          avgPace: DEFAULT_USER_PROFILE.avgPace,
          avgPreference: DEFAULT_USER_PROFILE.avgPreference,
          avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
          modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
          sampleCount: 11,
          updatedAt: DEFAULT_USER_PROFILE.updatedAt,
          manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
          consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
          consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
          lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
        }));
      } finally {
        hooks.restore();
      }
      expect(savedAssigned).assertTrue();
      const savedProfile = saved;
      expect(Number(savedProfile.sampleCount)).assertEqual(11);
    });

    it('boundary: user_profile_service_save_profile_should_accept_zero_timestamp', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAL();
      let updatedAt = -1;
      hooks.setGetInstance((): Object => new PreferenceManagerStubAL(
        null,
        async (profile: UserStrategyProfile): Promise<void> => { updatedAt = profile.updatedAt; }
      ));
      try {
        await UserProfileService.saveProfile(cloneDefaultProfile({
          avgDensity: DEFAULT_USER_PROFILE.avgDensity,
          avgPace: DEFAULT_USER_PROFILE.avgPace,
          avgPreference: DEFAULT_USER_PROFILE.avgPreference,
          avgEnergy: DEFAULT_USER_PROFILE.avgEnergy,
          modeFrequency: DEFAULT_USER_PROFILE.modeFrequency,
          sampleCount: DEFAULT_USER_PROFILE.sampleCount,
          updatedAt: 0,
          manualOverrideEnabled: DEFAULT_USER_PROFILE.manualOverrideEnabled,
          consistencyMatchCount: DEFAULT_USER_PROFILE.consistencyMatchCount,
          consistencyMismatchCount: DEFAULT_USER_PROFILE.consistencyMismatchCount,
          lastConsistencyCheckAt: DEFAULT_USER_PROFILE.lastConsistencyCheckAt
        }));
      } finally {
        hooks.restore();
      }
      expect(updatedAt).assertEqual(0);
    });

    it('invalid: user_profile_service_save_profile_should_throw_when_manager_fails', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new PreferenceManagerHooksAL();
      hooks.setGetInstance((): Object => new PreferenceManagerStubAL(
        null,
        async (_profile: UserStrategyProfile): Promise<void> => { throw new Error('save_failed'); }
      ));
      let message = '';
      try {
        await UserProfileService.saveProfile(cloneDefaultProfile());
      } catch (error) {
        message = error instanceof Error ? error.message : '';
      } finally {
        hooks.restore();
      }
      expect(message).assertEqual('save_failed');
    });

    it('conflict: user_profile_service_record_usage_should_keep_mode_frequency_json_valid_under_sequential_calls', 0, async () => {
      // Arrange
      // Act
      // Assert
      const hooks = new UserProfileServiceHooksAL();
      let saved: UserStrategyProfile = cloneDefaultProfile();
      let savedAssigned = false;
      hooks.setLoad(async (): Promise<UserStrategyProfile> => DEFAULT_USER_PROFILE);
      hooks.setSave(async (profile: UserStrategyProfile): Promise<void> => { saved = profile; savedAssigned = true; });
      try {
        await UserProfileService.recordStrategyUsage(1);
        await UserProfileService.recordStrategyUsage(2);
      } finally {
        hooks.restore();
      }
      expect(savedAssigned).assertTrue();
      const savedProfile = saved;
      expect(savedProfile.modeFrequency.length > 0).assertTrue();
    });

    it('regression: strategy_service_build_strategy_explanation_unknown_mode_should_keep_ai_fallback', 0, () => {
      // Arrange
      // Act
      // Assert
      const text = StrategyService.buildStrategyExplanation(99);
      expect(text.includes('AI')).assertTrue();
    });

    it('combined: strategy_adjustment_and_weather_adaptation_should_return_stable_strategy_bounds', 0, () => {
      // Arrange
      // Act
      // Assert
      const current = createStrategy();
      const adjusted = StrategyAdaptationEngine.applyAdjustment(current, {
        reason: 'USER_FEEDBACK',
        adjustments: { density: 1, pace: -1, preference: 1, energy: 1 },
        message: 'combined'
      });
      const weather = StrategyAdaptationEngine.adaptToWeather(createWeatherCollabContext('RAIN_PERSIST'), 68, adjusted);
      const finalStrategy = weather ? StrategyAdaptationEngine.applyAdjustment(adjusted, weather) : adjusted;
      const density = finalStrategy.density;
      expect(density >= 0).assertTrue();
      expect(density <= 2).assertTrue();
    });
  });
}
