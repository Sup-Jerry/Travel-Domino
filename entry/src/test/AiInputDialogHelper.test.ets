import { describe, it, expect } from '@ohos/hypium';
import { ThemeCenter } from '../main/ets/common/utils/ThemeCenter';
import {
  AiInputDialog,
  getAiLoadingTextByStrategy,
  normalizeAiStrategyMode,
  shouldKeepCurrentModeOnRegenerate,
  shouldUseAiInitialPrompt
} from '../main/ets/pages/components/dialogs/AiInputDialog';
import {
  ComposableStrategy,
  DensityLevel,
  EnergyLevel,
  PaceLevel,
  PreferenceType
} from '../main/ets/domain/strategy/TravelStrategyDimensions';
import { UserProfileService } from '../main/ets/domain/strategy/UserProfileService';

class DialogControllerMockAiInput {
  close(): void {
  }
}

interface AiInputDialogPaletteTest {
  textPrimary: Object;
  primary: Object;
  cardBgSoft: Object;
}

interface AiInputDialogParamsTest {
  hasAiHistory?: boolean;
  currentStrategyMode?: number;
  initialPrompt?: string;
  initialSelectedStrategyMode?: number;
  initialCustomStrategy?: ComposableStrategy;
  forceUseInitialSelection?: boolean;
}

interface AiInputDialogPrivateTest {
  controller?: DialogControllerMockAiInput;
  hasAiHistory: boolean;
  currentStrategyMode: number;
  initialPrompt: string;
  initialSelectedStrategyMode: number;
  initialCustomStrategy?: ComposableStrategy;
  forceUseInitialSelection: boolean;
  inputText: string;
  isLoading: boolean;
  selectedStrategy: number;
  useCustomStrategy: boolean;
  strategyTouched: boolean;
  customStrategy: ComposableStrategy;
  recommendHint: string;
  recommendedStrategy: ComposableStrategy | null;
  effectiveTheme: string;
  onConfirm: (text: string, strategy: number, customStrategy?: ComposableStrategy) => void;
  onRegenerate: (strategy: number, customStrategy?: ComposableStrategy, keepCurrentMode?: boolean) => void;
  setInitiallyProvidedValue(params: AiInputDialogParamsTest): void;
  updateStateVars(params: AiInputDialogParamsTest): void;
  getPalette(): AiInputDialogPaletteTest;
  aboutToAppear(): void;
  loadRecommendation(): Promise<void>;
  getLoadingText(): string;
  initialRender(): void;
  setController(controller: DialogControllerMockAiInput): void;
}

function buildAiStrategy(
  density: DensityLevel,
  pace: PaceLevel,
  preference: PreferenceType,
  energy: EnergyLevel
): ComposableStrategy {
  return {
    density,
    pace,
    preference,
    energy
  };
}

export default function aiInputDialogHelperTest() {
  describe('unit_test_case_generator_autofill_AiInputDialogHelper', () => {
    it('combined: ai_input_dialog_set_controller_should_replace_controller_reference', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      const first = new DialogControllerMockAiInput();
      const second = new DialogControllerMockAiInput();
      page.controller = first;

      // Act
      page.setController(second);

      // Assert
      expect(page.controller === second).assertTrue();
    });

    it('normal: ai_input_strategy_mode_should_keep_valid_builtin_mode', 0, () => {
      // Arrange
      const mode = 2;

      // Act
      const normalized = normalizeAiStrategyMode(mode);

      // Assert
      expect(normalized).assertEqual(2);
    });

    it('boundary: ai_input_prompt_should_reject_blank_text', 0, () => {
      // Arrange
      const prompt = '   ';

      // Act
      const shouldUse = shouldUseAiInitialPrompt(prompt);

      // Assert
      expect(shouldUse).assertFalse();
    });

    it('invalid: ai_input_strategy_mode_should_fallback_when_out_of_range', 0, () => {
      // Arrange
      const mode = 99;

      // Act
      const normalized = normalizeAiStrategyMode(mode);

      // Assert
      expect(normalized).assertEqual(0);
    });

    it('conflict: ai_input_keep_mode_should_require_untouched_custom_state', 0, () => {
      // Arrange
      const currentStrategyMode = -1;
      const strategyTouched = true;
      const useCustomStrategy = false;

      // Act
      const keep = shouldKeepCurrentModeOnRegenerate(currentStrategyMode, strategyTouched, useCustomStrategy);

      // Assert
      expect(keep).assertFalse();
    });

    it('regression: td-20260412-ai-input-loading-text-for-special-mode-should-stay-stable', 0, () => {
      // Arrange
      const strategy = 1;

      // Act
      const text = getAiLoadingTextByStrategy(strategy);

      // Assert
      expect(text).assertEqual('正在生成行程（预计30-60秒）');
    });

    it('combined: ai_input_custom_mode_should_keep_and_use_prompt_together', 0, () => {
      // Arrange
      const prompt = '帮我做三天西安亲子行程';

      // Act
      const shouldUsePrompt = shouldUseAiInitialPrompt(prompt);
      const keepMode = shouldKeepCurrentModeOnRegenerate(-1, false, false);

      // Assert
      expect(shouldUsePrompt).assertTrue();
      expect(keepMode).assertTrue();
    });

    it('combined: ai_input_dialog_instance_should_sync_initial_state_and_palette_without_runtime_ui', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      const initialStrategy = buildAiStrategy(DensityLevel.HIGH, PaceLevel.COMPACT, PreferenceType.CULTURE, EnergyLevel.HIGH);
      const initParams: AiInputDialogParamsTest = {
        hasAiHistory: true,
        currentStrategyMode: -1,
        initialPrompt: '  西安三日游  ',
        initialSelectedStrategyMode: -1,
        initialCustomStrategy: initialStrategy,
        forceUseInitialSelection: true
      };
      const nextParams: AiInputDialogParamsTest = {
        hasAiHistory: false,
        currentStrategyMode: 2,
        initialPrompt: '更新文案',
        initialSelectedStrategyMode: 2,
        forceUseInitialSelection: false
      };
      page.setInitiallyProvidedValue(initParams);

      // Act
      page.onConfirm('trip', 1, initialStrategy);
      page.onRegenerate(-1, initialStrategy, true);
      page.aboutToAppear();
      page.updateStateVars(nextParams);
      page.selectedStrategy = 2;
      const loadingText = page.getLoadingText();
      page.effectiveTheme = 'dark';
      const palette = page.getPalette();

      // Assert
      expect(page.strategyTouched).assertFalse();
      expect(page.inputText).assertEqual('西安三日游');
      expect(page.selectedStrategy).assertEqual(2);
      expect(page.useCustomStrategy).assertTrue();
      expect(page.customStrategy.density).assertEqual(DensityLevel.HIGH);
      expect(page.customStrategy.pace).assertEqual(PaceLevel.COMPACT);
      expect(page.hasAiHistory).assertTrue();
      expect(page.currentStrategyMode).assertEqual(-1);
      expect(page.initialSelectedStrategyMode).assertEqual(-1);
      expect(loadingText).assertEqual('正在生成行程（预计20-40秒）');
      expect(palette.textPrimary).assertEqual(ThemeCenter.getPalette('dark').textPrimary);
      expect(palette.primary).assertEqual(ThemeCenter.getPalette('dark').primary);
      expect(palette.cardBgSoft).assertEqual(ThemeCenter.getPalette('dark').cardBgSoft);
    });

    it('normal: ai_input_dialog_initial_render_should_support_recommendation_and_custom_strategy_branch', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      let threw = false;

      // Act
      page.inputText = '西安两日游';
      page.selectedStrategy = -1;
      page.useCustomStrategy = true;
      page.strategyTouched = true;
      page.customStrategy = buildAiStrategy(DensityLevel.HIGH, PaceLevel.COMPACT, PreferenceType.CULTURE, EnergyLevel.HIGH);
      page.recommendHint = '推荐偏文化路线';
      page.recommendedStrategy = buildAiStrategy(DensityLevel.MEDIUM, PaceLevel.BALANCED, PreferenceType.FOOD, EnergyLevel.MEDIUM);
      page.isLoading = false;
      page.effectiveTheme = 'dark';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: ai_input_dialog_initial_render_should_support_loading_and_builtin_strategy_branch', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      let threw = false;

      // Act
      page.inputText = '';
      page.selectedStrategy = 1;
      page.useCustomStrategy = false;
      page.strategyTouched = false;
      page.recommendHint = '';
      page.recommendedStrategy = null;
      page.isLoading = true;
      page.effectiveTheme = 'light';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('normal: ai_input_dialog_load_recommendation_should_apply_hint_and_strategy_when_profile_available', 0,
      async () => {
        // Arrange
        const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
        const recommended = buildAiStrategy(
          DensityLevel.LOW,
          PaceLevel.BALANCED,
          PreferenceType.FOOD,
          EnergyLevel.MEDIUM
        );
        const originalHint = Reflect.get(UserProfileService as Object, 'getRecommendationHint') as () => Promise<string>;
        const originalStrategy = Reflect.get(UserProfileService as Object, 'getRecommendedStrategy') as
          () => Promise<ComposableStrategy | null>;
        Reflect.set(UserProfileService as Object, 'getRecommendationHint', async (): Promise<string> => '偏美食路线');
        Reflect.set(UserProfileService as Object, 'getRecommendedStrategy', async (): Promise<ComposableStrategy> =>
          recommended);

        try {
          // Act
          await page.loadRecommendation();

          // Assert
          expect(page.recommendHint).assertEqual('偏美食路线');
          expect(page.recommendedStrategy !== null).assertTrue();
          expect((page.recommendedStrategy as ComposableStrategy).preference).assertEqual(PreferenceType.FOOD);
        } finally {
          Reflect.set(UserProfileService as Object, 'getRecommendationHint', originalHint);
          Reflect.set(UserProfileService as Object, 'getRecommendedStrategy', originalStrategy);
        }
      });

    it('boundary: ai_input_dialog_load_recommendation_should_clear_state_when_profile_service_fails', 0,
      async () => {
        // Arrange
        const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
        const originalHint = Reflect.get(UserProfileService as Object, 'getRecommendationHint') as () => Promise<string>;
        const originalStrategy = Reflect.get(UserProfileService as Object, 'getRecommendedStrategy') as
          () => Promise<ComposableStrategy | null>;
        page.recommendHint = '旧提示';
        page.recommendedStrategy = buildAiStrategy(
          DensityLevel.HIGH,
          PaceLevel.COMPACT,
          PreferenceType.CULTURE,
          EnergyLevel.HIGH
        );
        Reflect.set(UserProfileService as Object, 'getRecommendationHint', async (): Promise<string> => {
          throw new Error('profile_hint_failed');
        });

        try {
          // Act
          await page.loadRecommendation();

          // Assert
          expect(page.recommendHint).assertEqual('');
          expect(page.recommendedStrategy === null).assertTrue();
        } finally {
          Reflect.set(UserProfileService as Object, 'getRecommendationHint', originalHint);
          Reflect.set(UserProfileService as Object, 'getRecommendedStrategy', originalStrategy);
        }
      });

    it('boundary: ai_input_dialog_about_to_appear_should_use_current_builtin_mode_when_not_forcing_initial_selection', 0,
      () => {
        // Arrange
        const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
        page.setInitiallyProvidedValue({
          forceUseInitialSelection: false,
          currentStrategyMode: 1,
          initialPrompt: '   ',
          initialSelectedStrategyMode: -1
        });

        // Act
        page.aboutToAppear();

        // Assert
        expect(page.selectedStrategy).assertEqual(1);
        expect(page.useCustomStrategy).assertFalse();
        expect(page.inputText).assertEqual('');
      });

    it('combined: ai_input_dialog_about_to_appear_should_enter_custom_mode_when_current_mode_is_custom_without_initial_strategy',
      0, () => {
        // Arrange
        const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
        page.setInitiallyProvidedValue({
          forceUseInitialSelection: false,
          currentStrategyMode: -1,
          initialPrompt: '  keep custom  ',
          initialSelectedStrategyMode: 2
        });

        // Act
        page.aboutToAppear();

        // Assert
        expect(page.selectedStrategy).assertEqual(-1);
        expect(page.useCustomStrategy).assertTrue();
        expect(page.inputText).assertEqual('keep custom');
      });

    it('normal: ai_input_dialog_about_to_appear_should_apply_forced_builtin_initial_selection', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      page.setInitiallyProvidedValue({
        forceUseInitialSelection: true,
        currentStrategyMode: 0,
        initialPrompt: '  builtin keep  ',
        initialSelectedStrategyMode: 2
      });

      // Act
      page.aboutToAppear();

      // Assert
      expect(page.selectedStrategy).assertEqual(2);
      expect(page.useCustomStrategy).assertFalse();
      expect(page.inputText).assertEqual('builtin keep');
      expect(page.strategyTouched).assertFalse();
    });

    it('boundary: ai_input_dialog_about_to_appear_should_keep_default_custom_strategy_when_forced_custom_has_no_payload', 0,
      () => {
        // Arrange
        const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
        page.setInitiallyProvidedValue({
          forceUseInitialSelection: true,
          currentStrategyMode: 1,
          initialPrompt: '',
          initialSelectedStrategyMode: -1
        });

        // Act
        page.aboutToAppear();

        // Assert
        expect(page.selectedStrategy).assertEqual(-1);
        expect(page.useCustomStrategy).assertTrue();
        expect(page.customStrategy.density).assertEqual(DensityLevel.MEDIUM);
        expect(page.customStrategy.pace).assertEqual(PaceLevel.BALANCED);
      });

    it('normal: ai_input_dialog_initial_render_should_support_builtin_history_regenerate_branch', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      let threw = false;

      // Act
      page.inputText = '继续优化西安三日游';
      page.selectedStrategy = 1;
      page.useCustomStrategy = false;
      page.strategyTouched = false;
      page.hasAiHistory = true;
      page.currentStrategyMode = 1;
      page.recommendHint = '';
      page.recommendedStrategy = null;
      page.isLoading = false;
      page.effectiveTheme = 'dark';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });

    it('boundary: ai_input_dialog_initial_render_should_support_non_history_builtin_default_branch', 0, () => {
      // Arrange
      const page = new AiInputDialog(undefined, {} as LocalStorage) as Object as AiInputDialogPrivateTest;
      let threw = false;

      // Act
      page.inputText = '  ';
      page.selectedStrategy = 0;
      page.useCustomStrategy = false;
      page.strategyTouched = false;
      page.hasAiHistory = false;
      page.recommendHint = '';
      page.recommendedStrategy = null;
      page.isLoading = false;
      page.effectiveTheme = 'light';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
    });
  });
}
