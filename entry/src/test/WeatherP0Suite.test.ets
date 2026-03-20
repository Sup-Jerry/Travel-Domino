import preferenceManagerTest from './PreferenceManager.test';
import weatherRiskEvaluatorTest from './WeatherRiskEvaluator.test';
import weatherExecutionTest from './WeatherExecution.test';
import weatherStageCoordinatorTest from './WeatherStageCoordinator.test';
import weatherCityCapTest from './WeatherCityCap.test';
import weatherFacadeTest from './WeatherFacade.test';

/**
 * 天气 P0 最小回归测试组入口。
 * 用于与全量测试基线隔离管理。
 */
export default function weatherP0SuiteTest() {
  preferenceManagerTest();
  weatherRiskEvaluatorTest();
  weatherExecutionTest();
  weatherStageCoordinatorTest();
  weatherCityCapTest();
  weatherFacadeTest();
}
