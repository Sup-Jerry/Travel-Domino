export type CompanionSubMode = 'immersive' | 'control';
export type CompanionInteractionMode = 'immersive' | 'control' | 'both';
export type CompanionCardPhase = 'stable' | 'outgoing' | 'incoming';

export function pickRandomCompanionImmersiveText(): string {
  const tips: string[] = [
    '一步一步来。',
    '按自己的节奏走，就是最好的节奏。',
    '先完成这一站，再去下一站。',
    '旅程正在此刻发生。'
  ];
  const idx = Math.floor(Math.random() * tips.length);
  return tips[idx];
}

export function getCompanionInteractiveEnabled(mode: CompanionSubMode, interactionMode: CompanionInteractionMode): boolean {
  if (interactionMode === 'both') {
    return true;
  }
  return interactionMode === mode;
}

export function getCompanionCardTranslateX(
  isCardSwitching: boolean,
  cardSwitchProgress: number,
  phase: CompanionCardPhase
): number {
  if (!isCardSwitching) {
    return 0;
  }
  if (phase === 'outgoing') {
    return -18 * cardSwitchProgress;
  }
  if (phase === 'incoming') {
    return 18 * (1 - cardSwitchProgress);
  }
  return 0;
}

export function getCompanionCardOpacity(
  isCardSwitching: boolean,
  cardSwitchProgress: number,
  phase: CompanionCardPhase
): number {
  if (!isCardSwitching) {
    return 1;
  }
  if (phase === 'outgoing') {
    return 1 - cardSwitchProgress;
  }
  if (phase === 'incoming') {
    return cardSwitchProgress;
  }
  return 1;
}

export function getCompanionCardScale(
  isCardSwitching: boolean,
  cardSwitchProgress: number,
  phase: CompanionCardPhase
): number {
  if (!isCardSwitching) {
    return 1;
  }
  if (phase === 'outgoing') {
    return 1 - (0.015 * cardSwitchProgress);
  }
  if (phase === 'incoming') {
    return 0.992 + (0.008 * cardSwitchProgress);
  }
  return 1;
}
