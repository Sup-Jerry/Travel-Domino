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
import companionSwipeHelperVelocityTest from './CompanionSwipeHelperVelocity.test';
import companionSwipeHelperThresholdsTest from './CompanionSwipeHelperThresholds.test';
import companionWeatherActionHelperTest from './CompanionWeatherActionHelper.test';
import companionWeatherActionHelperConfirmTest from './CompanionWeatherActionHelperConfirm.test';
import companionWeatherActionHelperGuardsTest from './CompanionWeatherActionHelperGuards.test';
import companionAnimationHelperTest from './CompanionAnimationHelper.test';
import companionAnimationHelperProgressTest from './CompanionAnimationHelperProgress.test';
import companionDisplayHelperTest from './CompanionDisplayHelper.test';
import companionDisplayHelperActionsTest from './CompanionDisplayHelperActions.test';
import companionDisplayHelperActionsPositiveTest from './CompanionDisplayHelperActionsPositive.test';
import companionDisplayHelperMessagesTest from './CompanionDisplayHelperMessages.test';
import companionDisplayHelperErrorCodesTest from './CompanionDisplayHelperErrorCodes.test';
import companionDisplayHelperToastFallbackTest from './CompanionDisplayHelperToastFallback.test';
import companionDisplayHelperSuggestionExplanationTest from './CompanionDisplayHelperSuggestionExplanation.test';
import companionDisplayHelperSuggestionActionsTest from './CompanionDisplayHelperSuggestionActions.test';
import companionDisplayHelperRuntimeDescriptionTest from './CompanionDisplayHelperRuntimeDescription.test';
import companionDisplayHelperFallbackModesTest from './CompanionDisplayHelperFallbackModes.test';
import companionDisplayHelperStateGuardsTest from './CompanionDisplayHelperStateGuards.test';
import companionDisplayHelperPaletteMatrixTest from './CompanionDisplayHelperPaletteMatrix.test';
import companionDisplayHelperEventStateTest from './CompanionDisplayHelperEventState.test';
import companionWeatherPopupsHelperTest from './CompanionWeatherPopupsHelper.test';
import companionExecutionWeatherCardHelperTest from './CompanionExecutionWeatherCardHelper.test';
import companionFilterPageHelperTest from './CompanionFilterPageHelper.test';
import companionImmersiveViewHelperTest from './CompanionImmersiveViewHelper.test';
import companionTimelineSectionHelperTest from './CompanionTimelineSectionHelper.test';
import companionControlTopBarHelperTest from './CompanionControlTopBarHelper.test';
import companionSearchPageHelperTest from './CompanionSearchPageHelper.test';
import companionOverlayPagesHelperTest from './CompanionOverlayPagesHelper.test';
import companionFocusedCardHostHelperTest from './CompanionFocusedCardHostHelper.test';
import companionControlPageHelperTest from './CompanionControlPageHelper.test';
import companionHistoryPageHelperTest from './CompanionHistoryPageHelper.test';
import companionFocusActionHelperTest from './CompanionFocusActionHelper.test';
import companionWindowHelperTest from './CompanionWindowHelper.test';
import companionWindowHelperInsetsTest from './CompanionWindowHelperInsets.test';
import companionWindowHelperCutoutBottomRightTest from './CompanionWindowHelperCutoutBottomRight.test';
import companionPresentationHelperTest from './CompanionPresentationHelper.test';
import companionPresentationHelperEdgeFallbackTest from './CompanionPresentationHelperEdgeFallback.test';
import bottomNavBarHelperTest from './BottomNavBarHelper.test';
import appSideBarHelperTest from './AppSideBarHelper.test';
import renameDialogHelperTest from './RenameDialogHelper.test';
import dateFilterDialogHelperTest from './DateFilterDialogHelper.test';
import tipDialogHelperTest from './TipDialogHelper.test';
import planItemViewHelperTest from './PlanItemViewHelper.test';
import backlogViewHelperTest from './BacklogViewHelper.test';
import settingsItemsHelperTest from './SettingsItemsHelper.test';
import eventItemViewHelperTest from './EventItemViewHelper.test';
import companionViewHelperTest from './CompanionViewHelper.test';
import conflictSelectionDialogHelperTest from './ConflictSelectionDialogHelper.test';
import suggestionDialogHelperTest from './SuggestionDialogHelper.test';
import dateConflictDialogHelperTest from './DateConflictDialogHelper.test';
import conflictCompressDialogHelperTest from './ConflictCompressDialogHelper.test';
import recordCorrectionDialogHelperTest from './RecordCorrectionDialogHelper.test';
import addItemDialogHelperTest from './AddItemDialogHelper.test';
import aiInputDialogHelperTest from './AiInputDialogHelper.test';
import planSettingsDialogHelperTest from './PlanSettingsDialogHelper.test';
import planImportDialogHelperTest from './PlanImportDialogHelper.test';
import planJsonImportDialogHelperTest from './PlanJsonImportDialogHelper.test';
import planJsonExportDialogHelperTest from './PlanJsonExportDialogHelper.test';
import planShareDialogHelperTest from './PlanShareDialogHelper.test';
import advanceAdjustDialogHelperTest from './AdvanceAdjustDialogHelper.test';
import aiReplanPreviewDialogHelperTest from './AiReplanPreviewDialogHelper.test';
import createPlanDialogHelperTest from './CreatePlanDialogHelper.test';
import gapResolutionDialogHelperTest from './GapResolutionDialogHelper.test';
import huaweiAccountLoginButtonHelperTest from './HuaweiAccountLoginButtonHelper.test';
import indexToolbarHelperTest from './IndexToolbarHelper.test';
import indexWeatherHintBarHelperTest from './IndexWeatherHintBarHelper.test';
import indexUnsavedActionBarHelperTest from './IndexUnsavedActionBarHelper.test';
import indexTimelineViewHelperTest from './IndexTimelineViewHelper.test';
import indexBacklogSectionHelperTest from './IndexBacklogSectionHelper.test';
import indexBacklogViewHelperTest from './IndexBacklogViewHelper.test';
import indexBottomBarHelperTest from './IndexBottomBarHelper.test';
import indexTopAreaHelperTest from './IndexTopAreaHelper.test';
import indexCompanionOverlayHelperTest from './IndexCompanionOverlayHelper.test';
import indexScheduleAreaHelperTest from './IndexScheduleAreaHelper.test';
import indexPageLayoutHelperTest from './IndexPageLayoutHelper.test';
import appTextsConstantsTest from './AppTextsConstants.test';
import domainConstantsTest from './DomainConstants.test';
import storageKeysTest from './StorageKeys.test';
import entryBackupAbilityTest from './EntryBackupAbility.test';
import settingsAdvancedPageHelperTest from './SettingsAdvancedPageHelper.test';
import settingsNotificationPageHelperTest from './SettingsNotificationPageHelper.test';
import settingsPrivacyPageHelperTest from './SettingsPrivacyPageHelper.test';
import settingsAccountSecurityPageHelperTest from './SettingsAccountSecurityPageHelper.test';
import settingsGeneralPageHelperTest from './SettingsGeneralPageHelper.test';
import mapPickerPageHelperTest from './MapPickerPageHelper.test';
import planSearchPageHelperTest from './PlanSearchPageHelper.test';
import loginPageHelperTest from './LoginPageHelper.test';
import planListPageHelperTest from './PlanListPageHelper.test';
import authGatePageHelperTest from './AuthGatePageHelper.test';
import myPageHelperTest from './MyPageHelper.test';
import settingsPageHelperTest from './SettingsPageHelper.test';
import settingsPreferenceInsightsPageHelperTest from './SettingsPreferenceInsightsPageHelper.test';

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
  'CompanionSwipeHelperVelocity',
  'CompanionSwipeHelperThresholds',
  'CompanionWeatherActionHelper',
  'CompanionWeatherActionHelperConfirm',
  'CompanionWeatherActionHelperGuards',
  'CompanionAnimationHelper',
  'CompanionAnimationHelperProgress',
  'CompanionDisplayHelper',
  'CompanionDisplayHelperActions',
  'CompanionDisplayHelperActionsPositive',
  'CompanionDisplayHelperMessages',
  'CompanionDisplayHelperErrorCodes',
  'CompanionDisplayHelperToastFallback',
  'CompanionDisplayHelperSuggestionExplanation',
  'CompanionDisplayHelperSuggestionActions',
  'CompanionDisplayHelperRuntimeDescription',
  'CompanionDisplayHelperFallbackModes',
  'CompanionDisplayHelperStateGuards',
  'CompanionDisplayHelperPaletteMatrix',
  'CompanionDisplayHelperEventState',
  'CompanionWeatherPopupsHelper',
  'CompanionExecutionWeatherCardHelper',
  'CompanionFilterPageHelper',
  'CompanionImmersiveViewHelper',
  'CompanionTimelineSectionHelper',
  'CompanionControlTopBarHelper',
  'CompanionSearchPageHelper',
  'CompanionOverlayPagesHelper',
  'CompanionFocusedCardHostHelper',
  'CompanionControlPageHelper',
  'CompanionHistoryPageHelper',
  'CompanionFocusActionHelper',
  'CompanionWindowHelper',
  'CompanionWindowHelperInsets',
  'CompanionWindowHelperCutoutBottomRight',
  'CompanionPresentationHelper',
  'CompanionPresentationHelperEdgeFallback',
  'BottomNavBarHelper',
  'AppSideBarHelper',
  'RenameDialogHelper',
  'DateFilterDialogHelper',
  'TipDialogHelper',
  'PlanItemViewHelper',
  'BacklogViewHelper',
  'SettingsItemsHelper',
  'EventItemViewHelper',
  'CompanionViewHelper',
  'ConflictSelectionDialogHelper',
  'SuggestionDialogHelper',
  'DateConflictDialogHelper',
  'ConflictCompressDialogHelper',
  'RecordCorrectionDialogHelper',
  'AddItemDialogHelper',
  'AiInputDialogHelper',
  'PlanSettingsDialogHelper',
  'PlanImportDialogHelper',
  'PlanJsonImportDialogHelper',
  'PlanJsonExportDialogHelper',
  'PlanShareDialogHelper',
  'AdvanceAdjustDialogHelper',
  'AiReplanPreviewDialogHelper',
  'CreatePlanDialogHelper',
  'GapResolutionDialogHelper',
  'HuaweiAccountLoginButtonHelper',
  'IndexToolbarHelper',
  'IndexWeatherHintBarHelper',
  'IndexUnsavedActionBarHelper',
  'IndexTimelineViewHelper',
  'IndexBacklogSectionHelper',
  'IndexBacklogViewHelper',
  'IndexBottomBarHelper',
  'IndexTopAreaHelper',
  'IndexCompanionOverlayHelper',
  'IndexScheduleAreaHelper',
  'IndexPageLayoutHelper',
  'AppTextsConstants',
  'DomainConstants',
  'StorageKeys',
  'EntryBackupAbility',
  'SettingsAdvancedPageHelper',
  'SettingsNotificationPageHelper',
  'SettingsPrivacyPageHelper',
  'SettingsAccountSecurityPageHelper',
  'SettingsGeneralPageHelper',
  'MapPickerPageHelper',
  'PlanSearchPageHelper',
  'LoginPageHelper',
  'PlanListPageHelper',
  'AuthGatePageHelper',
  'MyPageHelper',
  'SettingsPageHelper',
  'SettingsPreferenceInsightsPageHelper'
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
  companionSwipeHelperVelocityTest();
  companionSwipeHelperThresholdsTest();
  companionWeatherActionHelperTest();
  companionWeatherActionHelperConfirmTest();
  companionWeatherActionHelperGuardsTest();
  companionAnimationHelperTest();
  companionAnimationHelperProgressTest();
  companionDisplayHelperTest();
  companionDisplayHelperActionsTest();
  companionDisplayHelperActionsPositiveTest();
  companionDisplayHelperMessagesTest();
  companionDisplayHelperErrorCodesTest();
  companionDisplayHelperToastFallbackTest();
  companionDisplayHelperSuggestionExplanationTest();
  companionDisplayHelperSuggestionActionsTest();
  companionDisplayHelperRuntimeDescriptionTest();
  companionDisplayHelperFallbackModesTest();
  companionDisplayHelperStateGuardsTest();
  companionDisplayHelperPaletteMatrixTest();
  companionDisplayHelperEventStateTest();
  companionWeatherPopupsHelperTest();
  companionExecutionWeatherCardHelperTest();
  companionFilterPageHelperTest();
  companionImmersiveViewHelperTest();
  companionTimelineSectionHelperTest();
  companionControlTopBarHelperTest();
  companionSearchPageHelperTest();
  companionOverlayPagesHelperTest();
  companionFocusedCardHostHelperTest();
  companionControlPageHelperTest();
  companionHistoryPageHelperTest();
  companionFocusActionHelperTest();
  companionWindowHelperTest();
  companionWindowHelperInsetsTest();
  companionWindowHelperCutoutBottomRightTest();
  companionPresentationHelperTest();
  companionPresentationHelperEdgeFallbackTest();
  bottomNavBarHelperTest();
  appSideBarHelperTest();
  renameDialogHelperTest();
  dateFilterDialogHelperTest();
  tipDialogHelperTest();
  planItemViewHelperTest();
  backlogViewHelperTest();
  settingsItemsHelperTest();
  eventItemViewHelperTest();
  companionViewHelperTest();
  conflictSelectionDialogHelperTest();
  suggestionDialogHelperTest();
  dateConflictDialogHelperTest();
  conflictCompressDialogHelperTest();
  recordCorrectionDialogHelperTest();
  addItemDialogHelperTest();
  aiInputDialogHelperTest();
  planSettingsDialogHelperTest();
  planImportDialogHelperTest();
  planJsonImportDialogHelperTest();
  planJsonExportDialogHelperTest();
  planShareDialogHelperTest();
  advanceAdjustDialogHelperTest();
  aiReplanPreviewDialogHelperTest();
  createPlanDialogHelperTest();
  gapResolutionDialogHelperTest();
  huaweiAccountLoginButtonHelperTest();
  indexToolbarHelperTest();
  indexWeatherHintBarHelperTest();
  indexUnsavedActionBarHelperTest();
  indexTimelineViewHelperTest();
  indexBacklogSectionHelperTest();
  indexBacklogViewHelperTest();
  indexBottomBarHelperTest();
  indexTopAreaHelperTest();
  indexCompanionOverlayHelperTest();
  indexScheduleAreaHelperTest();
  indexPageLayoutHelperTest();
  appTextsConstantsTest();
  domainConstantsTest();
  storageKeysTest();
  entryBackupAbilityTest();
  settingsAdvancedPageHelperTest();
  settingsNotificationPageHelperTest();
  settingsPrivacyPageHelperTest();
  settingsAccountSecurityPageHelperTest();
  settingsGeneralPageHelperTest();
  mapPickerPageHelperTest();
  planSearchPageHelperTest();
  loginPageHelperTest();
  planListPageHelperTest();
  authGatePageHelperTest();
  myPageHelperTest();
  settingsPageHelperTest();
  settingsPreferenceInsightsPageHelperTest();

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





