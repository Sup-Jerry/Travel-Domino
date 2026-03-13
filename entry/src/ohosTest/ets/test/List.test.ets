import abilityTest from './Ability.test';
import indexLifecycleIntegrationTest from './IndexLifecycle.integration.test';
import arrivalReminderFlowIntegrationTest from './ArrivalReminderFlow.integration.test';

export default function testsuite() {
  abilityTest();
  indexLifecycleIntegrationTest();
  arrivalReminderFlowIntegrationTest();
}
