import { describe, it, expect } from '@ohos/hypium';
import localUnitTest from './LocalUnit.test';
import automatedTest from './AutomatedTest.test';
import conflictCompressionTest from './ConflictCompression.test';
import planJsonTransferServiceTest from './PlanJsonTransferService.test';
import timeConstraintSolverTest from './TimeConstraintSolver.test';
import planStateFlowTest from './PlanStateFlow.test';
import planStateMachineCoreTest from './PlanStateMachineCore.test';
import planStateMachineLinkTest from './PlanStateMachineLink.test';
import planStateMachineTCSuiteTest from './PlanStateMachineTCSuite.test';
import aiServiceTest from './AiService.test';
import preferenceManagerTest from './PreferenceManager.test';
import mapServiceImplTest from './MapServiceImpl.test';
import arrivalReminderEngineTest from './ArrivalReminderEngine.test';
import scheduleOrchestratorTest from './ScheduleOrchestrator.test';
import reminderFacadeTest from './ReminderFacade.test';
import timelineDatePolicyTest from './TimelineDatePolicy.test';
import timelineViewModelAiDistributionTest from './TimelineViewModelAiDistribution.test';
import weatherCacheTest from './WeatherCache.test';
import weatherRiskEvaluatorTest from './WeatherRiskEvaluator.test';
import weatherExecutionTest from './WeatherExecution.test';
import weatherStageCoordinatorTest from './WeatherStageCoordinator.test';
import weatherCityCapTest from './WeatherCityCap.test';
import weatherFacadeTest from './WeatherFacade.test';
import weatherP0SuiteTest from './WeatherP0Suite.test';
import weatherPolicyResolverTest from './WeatherPolicyResolver.test';
import weatherStrategyLinkageTest from './WeatherStrategyLinkage.test';
import timelineWeatherLinkageIntegrationTest from './TimelineWeatherLinkageIntegration.test';
import authServiceTest from './AuthService.test';
import authFacadeSessionManagerTest from './AuthFacadeSessionManager.test';
import avatarServiceTest from './AvatarService.test';
import avatarUploadApiTest from './AvatarUploadApi.test';
import profileCacheManagerTest from './ProfileCacheManager.test';
import profileViewModelTest from './ProfileViewModel.test';
import userProfileRepositoryImplTest from './UserProfileRepositoryImpl.test';
import timelineExecutionCoordinatorTest from './TimelineExecutionCoordinator.test';
import timelineHistoryManagerTest from './TimelineHistoryManager.test';
import executionContextStoreTest from './ExecutionContextStore.test';
import authSessionStoreTest from './AuthSessionStore.test';
import timelineCompressionCoordinatorTest from './TimelineCompressionCoordinator.test';
import timelineDistributionCoordinatorTest from './TimelineDistributionCoordinator.test';
import timelineStrategyManagerTest from './TimelineStrategyManager.test';
import timelineCompanionManagerTest from './TimelineCompanionManager.test';
import appStartupCoordinatorTest from './AppStartupCoordinator.test';
import companionSwipeHelperTest from './CompanionSwipeHelper.test';
import companionWeatherActionHelperTest from './CompanionWeatherActionHelper.test';
import companionAnimationHelperTest from './CompanionAnimationHelper.test';
import companionDisplayHelperTest from './CompanionDisplayHelper.test';
import companionDisplayHelperActionsTest from './CompanionDisplayHelperActions.test';
import companionDisplayHelperMessagesTest from './CompanionDisplayHelperMessages.test';
import companionDisplayHelperErrorCodesTest from './CompanionDisplayHelperErrorCodes.test';
import companionDisplayHelperSuggestionExplanationTest from './CompanionDisplayHelperSuggestionExplanation.test';
import companionFocusActionHelperTest from './CompanionFocusActionHelper.test';
import companionWindowHelperTest from './CompanionWindowHelper.test';
import companionWindowHelperInsetsTest from './CompanionWindowHelperInsets.test';
import companionPresentationHelperTest from './CompanionPresentationHelper.test';

const registeredSuiteNames: string[] = [
  'LocalUnit',
  'AutomatedTest',
  'ConflictCompression',
  'PlanJsonTransferService',
  'TimeConstraintSolver',
  'PlanStateFlow',
  'PlanStateMachineCore',
  'PlanStateMachineLink',
  'PlanStateMachineTCSuite',
  'AiService',
  'PreferenceManager',
  'MapServiceImpl',
  'ArrivalReminderEngine',
  'ScheduleOrchestrator',
  'ReminderFacade',
  'TimelineDatePolicy',
  'TimelineViewModelAiDistribution',
  'WeatherCache',
  'WeatherRiskEvaluator',
  'WeatherExecution',
  'WeatherStageCoordinator',
  'WeatherCityCap',
  'WeatherFacade',
  'WeatherP0Suite',
  'WeatherPolicyResolver',
  'WeatherStrategyLinkage',
  'TimelineWeatherLinkageIntegration',
  'AuthService',
  'AuthFacadeSessionManager',
  'AvatarService',
  'AvatarUploadApi',
  'ProfileCacheManager',
  'ProfileViewModel',
  'UserProfileRepositoryImpl',
  'TimelineExecutionCoordinator',
  'TimelineHistoryManager',
  'ExecutionContextStore',
  'AuthSessionStore',
  'TimelineCompressionCoordinator',
  'TimelineDistributionCoordinator',
  'TimelineStrategyManager',
  'TimelineCompanionManager',
  'AppStartupCoordinator',
  'CompanionSwipeHelper',
  'CompanionWeatherActionHelper',
  'CompanionAnimationHelper',
  'CompanionDisplayHelper',
  'CompanionDisplayHelperActions',
  'CompanionDisplayHelperMessages',
  'CompanionDisplayHelperErrorCodes',
  'CompanionDisplayHelperSuggestionExplanation',
  'CompanionFocusActionHelper',
  'CompanionWindowHelper',
  'CompanionWindowHelperInsets',
  'CompanionPresentationHelper'
];

function containsSuite(name: string): boolean {
  return registeredSuiteNames.indexOf(name) >= 0;
}

function detectDuplicateNames(names: string[]): string[] {
  const seen = new Set<string>();
  const duplicates: string[] = [];
  for (const name of names) {
    if (seen.has(name) && duplicates.indexOf(name) < 0) {
      duplicates.push(name);
    } else {
      seen.add(name);
    }
  }
  return duplicates;
}

function buildExecutionPlan(allNames: string[], disabledNames: string[]): string[] {
  return allNames.filter((name) => disabledNames.indexOf(name) < 0);
}

export default function testsuite() {
  localUnitTest();
  automatedTest();
  conflictCompressionTest();
  planJsonTransferServiceTest();
  timeConstraintSolverTest();
  planStateFlowTest();
  planStateMachineCoreTest();
  planStateMachineLinkTest();
  planStateMachineTCSuiteTest();
  aiServiceTest();
  preferenceManagerTest();
  mapServiceImplTest();
  arrivalReminderEngineTest();
  scheduleOrchestratorTest();
  reminderFacadeTest();
  timelineDatePolicyTest();
  timelineViewModelAiDistributionTest();
  weatherCacheTest();
  weatherRiskEvaluatorTest();
  weatherExecutionTest();
  weatherStageCoordinatorTest();
  weatherCityCapTest();
  weatherFacadeTest();
  weatherP0SuiteTest();
  weatherPolicyResolverTest();
  weatherStrategyLinkageTest();
  timelineWeatherLinkageIntegrationTest();
  authServiceTest();
  authFacadeSessionManagerTest();
  avatarServiceTest();
  avatarUploadApiTest();
  profileCacheManagerTest();
  profileViewModelTest();
  userProfileRepositoryImplTest();
  timelineExecutionCoordinatorTest();
  timelineHistoryManagerTest();
  executionContextStoreTest();
  authSessionStoreTest();
  timelineCompressionCoordinatorTest();
  timelineDistributionCoordinatorTest();
  timelineStrategyManagerTest();
  timelineCompanionManagerTest();
  appStartupCoordinatorTest();
  companionSwipeHelperTest();
  companionWeatherActionHelperTest();
  companionAnimationHelperTest();
  companionDisplayHelperTest();
  companionDisplayHelperActionsTest();
  companionDisplayHelperMessagesTest();
  companionDisplayHelperErrorCodesTest();
  companionDisplayHelperSuggestionExplanationTest();
  companionFocusActionHelperTest();
  companionWindowHelperTest();
  companionWindowHelperInsetsTest();
  companionPresentationHelperTest();

  describe('listTest', () => {
    it('normal: list_should_keep_core_test_modules_registered', 0, () => {
      // Arrange
      const coreModules = ['LocalUnit', 'AuthService', 'WeatherFacade'];
      // Act
      const allPresent = coreModules.every((name) => containsSuite(name));
      // Assert
      expect(allPresent).assertTrue();
    });

    it('boundary: list_should_preserve_minimum_suite_count', 0, () => {
      // Arrange
      const minimumExpected = 30;
      // Act
      const totalSuites = registeredSuiteNames.length;
      // Assert
      expect(totalSuites >= minimumExpected).assertTrue();
    });

    it('invalid: list_should_reject_unknown_suite_name', 0, () => {
      // Arrange
      const unknownSuiteName = 'NotExistingSuite';
      // Act
      const exists = containsSuite(unknownSuiteName);
      // Assert
      expect(exists).assertFalse();
    });

    it('conflict: list_should_detect_duplicate_suite_names', 0, () => {
      // Arrange
      const withDuplicates = ['LocalUnit', 'AuthService', 'LocalUnit'];
      // Act
      const duplicates = detectDuplicateNames(withDuplicates);
      // Assert
      expect(duplicates.length).assertEqual(1);
      expect(duplicates[0]).assertEqual('LocalUnit');
    });

    it('regression: td-20260411-list-suite-order-should-stay-stable', 0, () => {
      // Arrange
      const expectedHead = ['LocalUnit', 'AutomatedTest', 'ConflictCompression'];
      // Act
      const actualHead = registeredSuiteNames.slice(0, 3);
      // Assert
      expect(actualHead[0]).assertEqual(expectedHead[0]);
      expect(actualHead[1]).assertEqual(expectedHead[1]);
      expect(actualHead[2]).assertEqual(expectedHead[2]);
    });

    it('combined: list_should_exclude_disabled_and_keep_others', 0, () => {
      // Arrange
      const allNames = ['LocalUnit', 'AuthService', 'WeatherFacade'];
      const disabledNames = ['AuthService'];
      // Act
      const executionPlan = buildExecutionPlan(allNames, disabledNames);
      // Assert
      expect(executionPlan.length).assertEqual(2);
      expect(executionPlan[0]).assertEqual('LocalUnit');
      expect(executionPlan[1]).assertEqual('WeatherFacade');
    });
  });
}

