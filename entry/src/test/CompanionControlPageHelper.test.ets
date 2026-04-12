import { describe, it, expect } from '@ohos/hypium';
import {
  getCompanionControlCurrentEventId,
  resolveCompanionControlCardOpacity,
  resolveCompanionControlCardScale,
  resolveCompanionControlCardTranslateX,
  shouldShowCompanionWeatherCard
} from '../main/ets/pages/components/views/companion/CompanionControlPage';
import { CompanionCardPhase } from '../main/ets/pages/components/views/companion/CompanionAnimationHelper';
import { EventEntity } from '../main/ets/model/entity/EventEntity';

function buildEvent(id: number): EventEntity {
  const event = new EventEntity();
  event.id = id;
  return event;
}

export default function companionControlPageHelperTest() {
  describe('unit_test_case_generator_autofill_CompanionControlPageHelper', () => {
    it('normal: weather_card_should_follow_feature_flag', 0, () => {
      // Arrange
      const enabled = true;

      // Act
      const visible = shouldShowCompanionWeatherCard(enabled);

      // Assert
      expect(visible).assertTrue();
    });

    it('boundary: current_event_id_should_return_minus_one_for_null', 0, () => {
      // Arrange
      const currentEvent = null;

      // Act
      const id = getCompanionControlCurrentEventId(currentEvent);

      // Assert
      expect(id).assertEqual(-1);
    });

    it('invalid: weather_card_should_handle_false_flag', 0, () => {
      // Arrange
      const enabled = false;

      // Act
      const visible = shouldShowCompanionWeatherCard(enabled);

      // Assert
      expect(visible).assertFalse();
    });

    it('conflict: current_event_id_should_prefer_event_id_when_present', 0, () => {
      // Arrange
      const event = buildEvent(22);

      // Act
      const id = getCompanionControlCurrentEventId(event);

      // Assert
      expect(id).assertEqual(22);
    });

    it('regression: current_event_id_should_not_depend_on_other_fields', 0, () => {
      // Arrange
      const event = buildEvent(33);
      event.name = '';

      // Act
      const id = getCompanionControlCurrentEventId(event);

      // Assert
      expect(id).assertEqual(33);
    });

    it('combined: control_helper_matrix_should_cover_visible_and_hidden_states', 0, () => {
      // Arrange
      const event = buildEvent(101);

      // Act
      const show = shouldShowCompanionWeatherCard(true);
      const hide = shouldShowCompanionWeatherCard(false);
      const id = getCompanionControlCurrentEventId(event);
      const none = getCompanionControlCurrentEventId(null);

      // Assert
      expect(show).assertTrue();
      expect(hide).assertFalse();
      expect(id).assertEqual(101);
      expect(none).assertEqual(-1);
    });

    it('normal: control_card_translate_should_move_outgoing_left_when_switching', 0, () => {
      // Arrange
      const phase: CompanionCardPhase = 'outgoing';
      // Act
      const x = resolveCompanionControlCardTranslateX(true, 0.5, phase);
      // Assert
      expect(x).assertEqual(-9);
    });

    it('boundary: control_card_opacity_should_keep_one_when_not_switching', 0, () => {
      // Arrange
      const phase: CompanionCardPhase = 'stable';
      // Act
      const opacity = resolveCompanionControlCardOpacity(false, 0.2, phase);
      // Assert
      expect(opacity).assertEqual(1);
    });

    it('regression: td-20260412-control-card-scale-incoming-should-follow-progress', 0, () => {
      // Arrange
      const phase: CompanionCardPhase = 'incoming';
      // Act
      const scale = resolveCompanionControlCardScale(true, 0.5, phase);
      // Assert
      expect(scale).assertEqual(0.996);
    });
  });
}
