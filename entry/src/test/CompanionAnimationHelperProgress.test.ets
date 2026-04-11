import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionCardOpacity,
  getCompanionCardScale,
  getCompanionCardTranslateX,
  getCompanionInteractiveEnabled
} from '../main/ets/pages/components/views/companion/CompanionAnimationHelper';

export default function companionAnimationHelperProgressTest() {
  describe('unit_test_case_generator_autofill_CompanionAnimationHelperProgress', () => {
    it('normal: card_motion_should_match_expected_start_values_when_progress_is_zero', 0, () => {
      // Arrange
      const progress = 0;

      // Act
      const outgoingX = getCompanionCardTranslateX(true, progress, 'outgoing');
      const incomingX = getCompanionCardTranslateX(true, progress, 'incoming');
      const outgoingOpacity = getCompanionCardOpacity(true, progress, 'outgoing');
      const incomingOpacity = getCompanionCardOpacity(true, progress, 'incoming');

      // Assert
      expect(outgoingX).assertEqual(0);
      expect(incomingX).assertEqual(18);
      expect(outgoingOpacity).assertEqual(1);
      expect(incomingOpacity).assertEqual(0);
    });

    it('boundary: card_motion_should_match_expected_end_values_when_progress_is_one', 0, () => {
      // Arrange
      const progress = 1;

      // Act
      const outgoingX = getCompanionCardTranslateX(true, progress, 'outgoing');
      const incomingX = getCompanionCardTranslateX(true, progress, 'incoming');
      const outgoingOpacity = getCompanionCardOpacity(true, progress, 'outgoing');
      const incomingOpacity = getCompanionCardOpacity(true, progress, 'incoming');
      const outgoingScale = getCompanionCardScale(true, progress, 'outgoing');
      const incomingScale = getCompanionCardScale(true, progress, 'incoming');

      // Assert
      expect(outgoingX).assertEqual(-18);
      expect(incomingX).assertEqual(0);
      expect(outgoingOpacity).assertEqual(0);
      expect(incomingOpacity).assertEqual(1);
      expect(outgoingScale).assertEqual(0.985);
      expect(incomingScale).assertEqual(1);
    });

    it('invalid: card_motion_should_keep_formula_behavior_when_progress_is_out_of_range', 0, () => {
      // Arrange
      const progress = 1.5;

      // Act
      const outgoingOpacity = getCompanionCardOpacity(true, progress, 'outgoing');
      const incomingOpacity = getCompanionCardOpacity(true, progress, 'incoming');
      const outgoingX = getCompanionCardTranslateX(true, progress, 'outgoing');

      // Assert
      expect(outgoingOpacity).assertEqual(-0.5);
      expect(incomingOpacity).assertEqual(1.5);
      expect(outgoingX).assertEqual(-27);
    });

    it('conflict: interaction_mode_both_should_enable_interaction_for_immersive_and_control', 0, () => {
      // Arrange
      const immersiveMode = 'immersive';
      const controlMode = 'control';

      // Act
      const immersiveEnabled = getCompanionInteractiveEnabled(immersiveMode, 'both');
      const controlEnabled = getCompanionInteractiveEnabled(controlMode, 'both');

      // Assert
      expect(immersiveEnabled).assertTrue();
      expect(controlEnabled).assertTrue();
    });

    it('regression: stable_phase_should_keep_neutral_translate_opacity_and_scale_while_switching', 0, () => {
      // Arrange
      const progress = 0.66;

      // Act
      const translate = getCompanionCardTranslateX(true, progress, 'stable');
      const opacity = getCompanionCardOpacity(true, progress, 'stable');
      const scale = getCompanionCardScale(true, progress, 'stable');

      // Assert
      expect(translate).assertEqual(0);
      expect(opacity).assertEqual(1);
      expect(scale).assertEqual(1);
    });

    it('combined: outgoing_and_incoming_card_states_should_remain_complementary_under_same_progress', 0, () => {
      // Arrange
      const progress = 0.6;

      // Act
      const outgoingX = getCompanionCardTranslateX(true, progress, 'outgoing');
      const incomingX = getCompanionCardTranslateX(true, progress, 'incoming');
      const outgoingOpacity = getCompanionCardOpacity(true, progress, 'outgoing');
      const incomingOpacity = getCompanionCardOpacity(true, progress, 'incoming');
      const outgoingScale = getCompanionCardScale(true, progress, 'outgoing');
      const incomingScale = getCompanionCardScale(true, progress, 'incoming');

      // Assert
      expect(outgoingX).assertEqual(-18 * progress);
      expect(incomingX).assertEqual(18 * (1 - progress));
      expect(outgoingOpacity).assertEqual(0.4);
      expect(incomingOpacity).assertEqual(0.6);
      expect(outgoingScale).assertEqual(1 - (0.015 * progress));
      expect(incomingScale).assertEqual(0.992 + (0.008 * progress));
    });
  });
}
