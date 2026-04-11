import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionCardOpacity,
  getCompanionCardScale,
  getCompanionCardTranslateX,
  getCompanionInteractiveEnabled,
  pickRandomCompanionImmersiveText
} from '../main/ets/pages/components/views/companion/CompanionAnimationHelper';

export default function companionAnimationHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionAnimationHelper', () => {
    it('normal: interactive_should_be_enabled_when_mode_matches', 0, () => {
      // Arrange
      const mode = 'immersive';

      // Act
      const enabled = getCompanionInteractiveEnabled(mode, 'immersive');

      // Assert
      expect(enabled).assertTrue();
    });

    it('boundary: random_immersive_text_should_always_be_non_empty', 0, () => {
      // Arrange
      const samples: string[] = [];

      // Act
      for (let i = 0; i < 12; i++) {
        samples.push(pickRandomCompanionImmersiveText());
      }

      // Assert
      expect(samples.length).assertEqual(12);
      expect(samples.every((item: string) => item.length > 0)).assertTrue();
    });

    it('invalid: interactive_should_be_disabled_when_mode_does_not_match', 0, () => {
      // Arrange
      const mode = 'control';

      // Act
      const enabled = getCompanionInteractiveEnabled(mode, 'immersive');

      // Assert
      expect(enabled).assertFalse();
    });

    it('conflict: translate_x_should_apply_opposite_direction_for_outgoing_and_incoming', 0, () => {
      // Arrange
      const progress = 0.5;

      // Act
      const outgoingX = getCompanionCardTranslateX(true, progress, 'outgoing');
      const incomingX = getCompanionCardTranslateX(true, progress, 'incoming');

      // Assert
      expect(outgoingX).assertEqual(-9);
      expect(incomingX).assertEqual(9);
    });

    it('regression: opacity_should_keep_one_when_not_switching_or_phase_is_stable', 0, () => {
      // Arrange
      const progress = 0.8;

      // Act
      const notSwitchingOpacity = getCompanionCardOpacity(false, progress, 'outgoing');
      const stableOpacity = getCompanionCardOpacity(true, progress, 'stable');

      // Assert
      expect(notSwitchingOpacity).assertEqual(1);
      expect(stableOpacity).assertEqual(1);
    });

    it('combined: scale_and_opacity_should_follow_progress_for_incoming_and_outgoing', 0, () => {
      // Arrange
      const progress = 0.25;

      // Act
      const outgoingScale = getCompanionCardScale(true, progress, 'outgoing');
      const incomingScale = getCompanionCardScale(true, progress, 'incoming');
      const outgoingOpacity = getCompanionCardOpacity(true, progress, 'outgoing');
      const incomingOpacity = getCompanionCardOpacity(true, progress, 'incoming');

      // Assert
      expect(outgoingScale).assertEqual(1 - (0.015 * progress));
      expect(incomingScale).assertEqual(0.992 + (0.008 * progress));
      expect(outgoingOpacity).assertEqual(1 - progress);
      expect(incomingOpacity).assertEqual(progress);
    });
  });
}
