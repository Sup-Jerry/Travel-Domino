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
import dateUtilTest from './DateUtil.test';
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
import authApiClientTest from './AuthApiClient.test';
import authGatewayTest from './AuthGateway.test';
import authFacadeSessionManagerTest from './AuthFacadeSessionManager.test';
import huaweiAccountProviderTest from './HuaweiAccountProvider.test';
import avatarServiceTest from './AvatarService.test';
import avatarUploadApiTest from './AvatarUploadApi.test';
import profileCacheManagerTest from './ProfileCacheManager.test';
import profileViewModelTest from './ProfileViewModel.test';
import userProfileRepositoryImplTest from './UserProfileRepositoryImpl.test';
import timelineExecutionCoordinatorTest from './TimelineExecutionCoordinator.test';
import timelineHistoryManagerTest from './TimelineHistoryManager.test';
import executionContextStoreTest from './ExecutionContextStore.test';
import eventRepositoryImplTest from './EventRepositoryImpl.test';
import authSessionStoreTest from './AuthSessionStore.test';
import timelinePlanStateManagerTest from './TimelinePlanStateManager.test';
import timelineRecalculationManagerTest from './TimelineRecalculationManager.test';
import timelineEventMutationManagerTest from './TimelineEventMutationManager.test';
import timelineCompressionCoordinatorTest from './TimelineCompressionCoordinator.test';
import timelineDistributionCoordinatorTest from './TimelineDistributionCoordinator.test';
import timelineStrategyManagerTest from './TimelineStrategyManager.test';
import timelineAiServiceReplanTest from './TimelineAiServiceReplan.test';
import timelineCompanionManagerTest from './TimelineCompanionManager.test';
import appStartupCoordinatorTest from './AppStartupCoordinator.test';
import timelineWeatherCoordinatorTest from './TimelineWeatherCoordinator.test';
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
import planItemViewTimeAndConflictEdgeTest from './PlanItemViewTimeAndConflictEdge.test';
import backlogViewHelperTest from './BacklogViewHelper.test';
import settingsItemsHelperTest from './SettingsItemsHelper.test';
import eventItemViewHelperTest from './EventItemViewHelper.test';
import eventItemViewConflictGapEdgeTest from './EventItemViewConflictGapEdge.test';
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
import gapResolutionDialogThresholdsTest from './GapResolutionDialogThresholds.test';
import huaweiAccountLoginButtonHelperTest from './HuaweiAccountLoginButtonHelper.test';
import indexToolbarHelperTest from './IndexToolbarHelper.test';
import indexWeatherHintBarHelperTest from './IndexWeatherHintBarHelper.test';
import indexUnsavedActionBarHelperTest from './IndexUnsavedActionBarHelper.test';
import indexTimelineViewHelperTest from './IndexTimelineViewHelper.test';
import indexDialogManagerTest from './IndexDialogManager.test';
import indexEventHandlersTest from './IndexEventHandlers.test';
import indexHelpersTest from './IndexHelpers.test';
import indexBacklogSectionHelperTest from './IndexBacklogSectionHelper.test';
import indexBacklogViewHelperTest from './IndexBacklogViewHelper.test';
import indexBottomBarHelperTest from './IndexBottomBarHelper.test';
import indexTopAreaHelperTest from './IndexTopAreaHelper.test';
import indexCompanionOverlayHelperTest from './IndexCompanionOverlayHelper.test';
import indexScheduleAreaHelperTest from './IndexScheduleAreaHelper.test';
import indexPageLayoutHelperTest from './IndexPageLayoutHelper.test';
import indexAddDialogHelperTest from './IndexAddDialogHelper.test';
import indexConflictHelperTest from './IndexConflictHelper.test';
import indexLifecycleHelperTest from './IndexLifecycleHelper.test';
import indexPageShowHelperTest from './IndexPageShowHelper.test';
import indexSettingsFlowHelperTest from './IndexSettingsFlowHelper.test';
import indexStateManagerTest from './IndexStateManager.test';
import indexStateManagerHelperTest from './IndexStateManagerHelper.test';
import indexTimelineActionHelperTest from './IndexTimelineActionHelper.test';
import indexTypesTest from './IndexTypes.test';
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
import trashPageHelperTest from './TrashPageHelper.test';
import archivePageHelperTest from './ArchivePageHelper.test';
import phase1ZeroHitBatchATest from './Phase1ZeroHitBatchA.test';
import phase1ZeroHitBatchBTest from './Phase1ZeroHitBatchB.test';
import phase1ZeroHitBatchCTest from './Phase1ZeroHitBatchC.test';
import phase1ZeroHitBatchDTest from './Phase1ZeroHitBatchD.test';
import phase1ZeroHitBatchETest from './Phase1ZeroHitBatchE.test';
import phase1ZeroHitBatchFTest from './Phase1ZeroHitBatchF.test';
import phase1ZeroHitBatchGTest from './Phase1ZeroHitBatchG.test';
import phase1ZeroHitBatchHTest from './Phase1ZeroHitBatchH.test';
import phase1ZeroHitBatchITest from './Phase1ZeroHitBatchI.test';
import phase1ZeroHitBatchJTest from './Phase1ZeroHitBatchJ.test';
import phase1ZeroHitBatchKTest from './Phase1ZeroHitBatchK.test';
import phase2CoreCoverageBatchATest from './Phase2CoreCoverageBatchA.test';
import phase2CoreCoverageBatchBTest from './Phase2CoreCoverageBatchB.test';
import phase2CoreCoverageBatchCTest from './Phase2CoreCoverageBatchC.test';
import phase2CoreCoverageBatchDTest from './Phase2CoreCoverageBatchD.test';
import phase2CoreCoverageBatchETest from './Phase2CoreCoverageBatchE.test';
import phase2CoreCoverageBatchFTest from './Phase2CoreCoverageBatchF.test';
import phase2CoreCoverageBatchGTest from './Phase2CoreCoverageBatchG.test';
import phase2CoreCoverageBatchHTest from './Phase2CoreCoverageBatchH.test';
import phase2CoreCoverageBatchITest from './Phase2CoreCoverageBatchI.test';
import phase2CoreCoverageBatchJTest from './Phase2CoreCoverageBatchJ.test';
import phase2CoreCoverageBatchKTest from './Phase2CoreCoverageBatchK.test';
import phase2CoreCoverageBatchLTest from './Phase2CoreCoverageBatchL.test';
import phase2CoreCoverageBatchMTest from './Phase2CoreCoverageBatchM.test';
import phase2CoreCoverageBatchNTest from './Phase2CoreCoverageBatchN.test';
import phase2CoreCoverageBatchOTest from './Phase2CoreCoverageBatchO.test';
import phase2CoreCoverageBatchPTest from './Phase2CoreCoverageBatchP.test';
import phase2CoreCoverageBatchQTest from './Phase2CoreCoverageBatchQ.test';
import phase2CoreCoverageBatchRTest from './Phase2CoreCoverageBatchR.test';
import phase2CoreCoverageBatchSTest from './Phase2CoreCoverageBatchS.test';
import phase2CoreCoverageBatchTTest from './Phase2CoreCoverageBatchT.test';
import phase2CoreCoverageBatchUTest from './Phase2CoreCoverageBatchU.test';
import phase2CoreCoverageBatchVTest from './Phase2CoreCoverageBatchV.test';
import phase2CoreCoverageBatchWTest from './Phase2CoreCoverageBatchW.test';

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
  'DateUtil',
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
  'AuthApiClient',
  'AuthGateway',
  'AuthFacadeSessionManager',
  'HuaweiAccountProvider',
  'AvatarService',
  'AvatarUploadApi',
  'ProfileCacheManager',
  'ProfileViewModel',
  'UserProfileRepositoryImpl',
  'TimelineExecutionCoordinator',
  'TimelineHistoryManager',
  'ExecutionContextStore',
  'EventRepositoryImpl',
  'AuthSessionStore',
  'TimelinePlanStateManager',
  'TimelineRecalculationManager',
  'TimelineEventMutationManager',
  'TimelineCompressionCoordinator',
  'TimelineDistributionCoordinator',
  'TimelineStrategyManager',
  'TimelineAiServiceReplan',
  'TimelineCompanionManager',
  'AppStartupCoordinator',
  'TimelineWeatherCoordinator',
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
  'PlanItemViewTimeAndConflictEdge',
  'BacklogViewHelper',
  'SettingsItemsHelper',
  'EventItemViewHelper',
  'EventItemViewConflictGapEdge',
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
  'GapResolutionDialogThresholds',
  'HuaweiAccountLoginButtonHelper',
  'IndexToolbarHelper',
  'IndexWeatherHintBarHelper',
  'IndexUnsavedActionBarHelper',
  'IndexTimelineViewHelper',
  'IndexDialogManager',
  'IndexEventHandlers',
  'IndexHelpers',
  'IndexBacklogSectionHelper',
  'IndexBacklogViewHelper',
  'IndexBottomBarHelper',
  'IndexTopAreaHelper',
  'IndexCompanionOverlayHelper',
  'IndexScheduleAreaHelper',
  'IndexPageLayoutHelper',
  'IndexAddDialogHelper',
  'IndexConflictHelper',
  'IndexLifecycleHelper',
  'IndexPageShowHelper',
  'IndexSettingsFlowHelper',
  'IndexStateManager',
  'IndexStateManagerHelper',
  'IndexTimelineActionHelper',
  'IndexTypes',
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
  'SettingsPreferenceInsightsPageHelper',
  'TrashPageHelper',
  'ArchivePageHelper',
  'Phase1ZeroHitBatchA',
  'Phase1ZeroHitBatchB',
  'Phase1ZeroHitBatchC',
  'Phase1ZeroHitBatchD',
  'Phase1ZeroHitBatchE',
  'Phase1ZeroHitBatchF',
  'Phase1ZeroHitBatchG',
  'Phase1ZeroHitBatchH',
  'Phase1ZeroHitBatchI',
  'Phase1ZeroHitBatchJ',
  'Phase1ZeroHitBatchK',
  'Phase2CoreCoverageBatchA',
  'Phase2CoreCoverageBatchB',
  'Phase2CoreCoverageBatchC',
  'Phase2CoreCoverageBatchD',
  'Phase2CoreCoverageBatchE',
  'Phase2CoreCoverageBatchF',
  'Phase2CoreCoverageBatchG',
  'Phase2CoreCoverageBatchH',
  'Phase2CoreCoverageBatchI',
  'Phase2CoreCoverageBatchJ',
  'Phase2CoreCoverageBatchK',
  'Phase2CoreCoverageBatchL',
  'Phase2CoreCoverageBatchM',
  'Phase2CoreCoverageBatchN',
  'Phase2CoreCoverageBatchO',
  'Phase2CoreCoverageBatchP',
  'Phase2CoreCoverageBatchQ',
  'Phase2CoreCoverageBatchR',
  'Phase2CoreCoverageBatchS',
  'Phase2CoreCoverageBatchT',
  'Phase2CoreCoverageBatchU',
  'Phase2CoreCoverageBatchV',
  'Phase2CoreCoverageBatchW'
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
  dateUtilTest();
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
  authApiClientTest();
  authGatewayTest();
  authFacadeSessionManagerTest();
  huaweiAccountProviderTest();
  avatarServiceTest();
  avatarUploadApiTest();
  profileCacheManagerTest();
  profileViewModelTest();
  userProfileRepositoryImplTest();
  timelineExecutionCoordinatorTest();
  timelineHistoryManagerTest();
  executionContextStoreTest();
  eventRepositoryImplTest();
  authSessionStoreTest();
  timelinePlanStateManagerTest();
  timelineRecalculationManagerTest();
  timelineEventMutationManagerTest();
  timelineCompressionCoordinatorTest();
  timelineDistributionCoordinatorTest();
  timelineStrategyManagerTest();
  timelineAiServiceReplanTest();
  timelineCompanionManagerTest();
  appStartupCoordinatorTest();
  timelineWeatherCoordinatorTest();
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
  planItemViewTimeAndConflictEdgeTest();
  backlogViewHelperTest();
  settingsItemsHelperTest();
  eventItemViewHelperTest();
  eventItemViewConflictGapEdgeTest();
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
  gapResolutionDialogThresholdsTest();
  huaweiAccountLoginButtonHelperTest();
  indexToolbarHelperTest();
  indexWeatherHintBarHelperTest();
  indexUnsavedActionBarHelperTest();
  indexTimelineViewHelperTest();
  indexDialogManagerTest();
  indexEventHandlersTest();
  indexHelpersTest();
  indexBacklogSectionHelperTest();
  indexBacklogViewHelperTest();
  indexBottomBarHelperTest();
  indexTopAreaHelperTest();
  indexCompanionOverlayHelperTest();
  indexScheduleAreaHelperTest();
  indexPageLayoutHelperTest();
  indexAddDialogHelperTest();
  indexConflictHelperTest();
  indexLifecycleHelperTest();
  indexPageShowHelperTest();
  indexSettingsFlowHelperTest();
  indexStateManagerTest();
  indexStateManagerHelperTest();
  indexTimelineActionHelperTest();
  indexTypesTest();
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
  trashPageHelperTest();
  archivePageHelperTest();
  phase1ZeroHitBatchATest();
  phase1ZeroHitBatchBTest();
  phase1ZeroHitBatchCTest();
  phase1ZeroHitBatchDTest();
  phase1ZeroHitBatchETest();
  phase1ZeroHitBatchFTest();
  phase1ZeroHitBatchGTest();
  phase1ZeroHitBatchHTest();
  phase1ZeroHitBatchITest();
  phase1ZeroHitBatchJTest();
  phase1ZeroHitBatchKTest();
  phase2CoreCoverageBatchATest();
  phase2CoreCoverageBatchBTest();
  phase2CoreCoverageBatchCTest();
  phase2CoreCoverageBatchDTest();
  phase2CoreCoverageBatchETest();
  phase2CoreCoverageBatchFTest();
  phase2CoreCoverageBatchGTest();
  phase2CoreCoverageBatchHTest();
  phase2CoreCoverageBatchITest();
  phase2CoreCoverageBatchJTest();
  phase2CoreCoverageBatchKTest();
  phase2CoreCoverageBatchLTest();
  phase2CoreCoverageBatchMTest();
  phase2CoreCoverageBatchNTest();
  phase2CoreCoverageBatchOTest();
  phase2CoreCoverageBatchPTest();
  phase2CoreCoverageBatchQTest();
  phase2CoreCoverageBatchRTest();
  phase2CoreCoverageBatchSTest();
  phase2CoreCoverageBatchTTest();
  phase2CoreCoverageBatchUTest();
  phase2CoreCoverageBatchVTest();
  phase2CoreCoverageBatchWTest();

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






