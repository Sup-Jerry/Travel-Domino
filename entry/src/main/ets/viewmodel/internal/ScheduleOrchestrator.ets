import { TimeConstraintSolver, TimelineCalculateOptions } from '../../model/logic/TimeConstraintSolver';
import { TravelPlanItem } from '../../model/interface/IStandardEvent';

export class ScheduleOrchestrator {
  public calculate(
    events: TravelPlanItem[],
    globalStartTimeStr: string,
    planStartDate: number,
    options?: TimelineCalculateOptions
  ): TravelPlanItem[] {
    return TimeConstraintSolver.calculateTimeline(events, globalStartTimeStr, planStartDate, options);
  }
}
