import { TravelStrategyMode } from './TravelStrategyMode';
import { TravelStrategyProfile } from './TravelStrategyProfile';

export interface AiGenerateRequest {
  userPrompt: string;
  planId: number;
  strategyMode: TravelStrategyMode;
  strategyProfile?: TravelStrategyProfile;
}
