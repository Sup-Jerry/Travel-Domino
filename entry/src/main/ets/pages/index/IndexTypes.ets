export interface InitDialogData {
  name: string;
  note: string;
  duration: number;
  isAnchor: boolean;
  fixedTime: string;
  dayOffset: number;
  suggestedTime?: string;
  isSchedule?: boolean;
  lat?: number;
  lng?: number;
}

export interface PendingItemData {
  id: number;
  name: string;
  duration: number;
  isSchedule: boolean;
  fixedTime?: string;
  dayOffset: number;
  targetDateMs: number;
  note: string;
  lat?: number;
  lng?: number;
}

export class AddDialogDefaults {
  dayOffset: number = 0;
  suggestedTime: string = '08:00';
}
