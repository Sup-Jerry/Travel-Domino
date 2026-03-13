import localUnitTest from './LocalUnit.test';
import automatedTest from './AutomatedTest.test';
import conflictCompressionTest from './ConflictCompression.test';
import planJsonTransferServiceTest from './PlanJsonTransferService.test';
import timeConstraintSolverTest from './TimeConstraintSolver.test';
import planStateFlowTest from './PlanStateFlow.test';
import aiServiceTest from './AiService.test';
import preferenceManagerTest from './PreferenceManager.test';
import mapServiceImplTest from './MapServiceImpl.test';
import arrivalReminderEngineTest from './ArrivalReminderEngine.test';
export default function testsuite() {
  localUnitTest();
  automatedTest();
  conflictCompressionTest();
  planJsonTransferServiceTest();
  timeConstraintSolverTest();
  planStateFlowTest();
  aiServiceTest();
  preferenceManagerTest();
  mapServiceImplTest();
  arrivalReminderEngineTest();
}
