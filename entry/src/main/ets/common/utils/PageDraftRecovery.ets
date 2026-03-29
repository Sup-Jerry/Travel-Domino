export interface TempDialogState {
  name: string;
  note: string;
  duration: number;
  isAnchor: boolean;
  fixedTime: string;
  dayOffset: number;
  isSchedule: boolean;
  lat: number;
  lng: number;
}

export interface PickedLocationData {
  lat: number;
  lng: number;
  address: string;
}

export interface RecoveredDialogDraft {
  name: string;
  note: string;
  duration: number;
  isAnchor: boolean;
  fixedTime: string;
  dayOffset: number;
  isSchedule: boolean;
  lat: number;
  lng: number;
}

export interface DraftRecoveryResult {
  shouldClear: boolean;
  shouldRestore: boolean;
  reason: string;
  restored?: RecoveredDialogDraft;
}

export class PageDraftRecovery {
  private static buildCoordinateFallbackAddress(lat: number, lng: number): string {
    return `已选位置(${lat.toFixed(5)}, ${lng.toFixed(5)})`;
  }

  public static parseTempDialogState(raw: string): TempDialogState | null {
    try {
      const parsed = JSON.parse(raw) as TempDialogState;
      if (!parsed || typeof parsed.name !== 'string' || typeof parsed.note !== 'string' || typeof parsed.fixedTime !== 'string') {
        return null;
      }
      if (typeof parsed.isAnchor !== 'boolean' || typeof parsed.isSchedule !== 'boolean') {
        return null;
      }
      if (!Number.isFinite(parsed.dayOffset)) {
        return null;
      }
      const duration = Number.isFinite(parsed.duration) ? Math.max(1, Math.floor(parsed.duration)) : 60;
      const dayOffset = Math.floor(parsed.dayOffset);
      const lat = Number.isFinite(parsed.lat) ? parsed.lat : 0;
      const lng = Number.isFinite(parsed.lng) ? parsed.lng : 0;
      return {
        name: parsed.name,
        note: parsed.note,
        duration: duration,
        isAnchor: parsed.isAnchor,
        fixedTime: parsed.fixedTime,
        dayOffset: dayOffset,
        isSchedule: parsed.isSchedule,
        lat: lat,
        lng: lng
      };
    } catch (_error) {
      return null;
    }
  }

  public static parsePickedLocation(raw: string): PickedLocationData | null {
    try {
      const parsed = JSON.parse(raw) as PickedLocationData;
      if (!parsed || typeof parsed.address !== 'string' || !Number.isFinite(parsed.lat) || !Number.isFinite(parsed.lng)) {
        return null;
      }
      return parsed;
    } catch (_error) {
      return null;
    }
  }

  public static recover(tempStateRaw: string, pickedRaw: string): DraftRecoveryResult {
    if (!tempStateRaw || tempStateRaw.trim().length === 0) {
      if (pickedRaw && pickedRaw.trim().length > 0) {
        return {
          shouldClear: true,
          shouldRestore: false,
          reason: 'orphan_picked'
        };
      }
      return {
        shouldClear: false,
        shouldRestore: false,
        reason: 'empty'
      };
    }

    const temp = PageDraftRecovery.parseTempDialogState(tempStateRaw);
    if (!temp) {
      return {
        shouldClear: true,
        shouldRestore: false,
        reason: 'temp_invalid'
      };
    }

    const hasPicked = pickedRaw && pickedRaw.trim().length > 0;
    if (!hasPicked) {
      return {
        shouldClear: true,
        shouldRestore: true,
        reason: 'restore_temp_only',
        restored: {
          name: temp.name,
          note: temp.note,
          duration: temp.duration,
          isAnchor: temp.isAnchor,
          fixedTime: temp.fixedTime,
          dayOffset: temp.dayOffset,
          isSchedule: temp.isSchedule,
          lat: temp.lat,
          lng: temp.lng
        }
      };
    }

    const picked = PageDraftRecovery.parsePickedLocation(pickedRaw);
    if (!picked) {
      return {
        shouldClear: true,
        shouldRestore: false,
        reason: 'picked_invalid'
      };
    }
    const normalizedAddress = (picked.address || '').trim();
    const mergedName = normalizedAddress.length > 0
      ? normalizedAddress
      : PageDraftRecovery.buildCoordinateFallbackAddress(picked.lat, picked.lng);

    return {
      shouldClear: true,
      shouldRestore: true,
      reason: 'restore_merged',
      restored: {
        name: mergedName,
        note: temp.note,
        duration: temp.duration,
        isAnchor: temp.isAnchor,
        fixedTime: temp.fixedTime,
        dayOffset: temp.dayOffset,
        isSchedule: temp.isSchedule,
        lat: picked.lat,
        lng: picked.lng
      }
    };
  }
}
