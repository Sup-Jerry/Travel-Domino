export interface CompanionSwipeUpdate {
  peakDistance: number;
  lastTs: number;
  dragOffsetY: number;
}

export function getCompanionSwipeUpdate(offsetY: number, currentPeakDistance: number, nowTs: number): CompanionSwipeUpdate {
  if (offsetY >= 0) {
    return {
      peakDistance: currentPeakDistance,
      lastTs: nowTs,
      dragOffsetY: 0
    };
  }

  const dragDistance = Math.abs(offsetY);
  const nextPeakDistance = dragDistance > currentPeakDistance ? dragDistance : currentPeakDistance;
  const dampedOffset = offsetY * 0.38;

  return {
    peakDistance: nextPeakDistance,
    lastTs: nowTs,
    dragOffsetY: dampedOffset < -150 ? -150 : dampedOffset
  };
}

export function shouldCompanionEnterControlMode(
  peakDistance: number,
  offsetY: number,
  swipeStartTs: number,
  nowTs: number,
  distanceTrigger: number,
  velocityTrigger: number
): boolean {
  const dragDistance = Math.max(peakDistance, offsetY < 0 ? Math.abs(offsetY) : 0);
  const duration = Math.max(1, nowTs - swipeStartTs);
  const upVelocity = dragDistance / duration;
  return dragDistance >= distanceTrigger || upVelocity >= velocityTrigger;
}
