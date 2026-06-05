import { describe, expect, it } from '@ohos/hypium';
import {
  SettingCategoryItem,
  SettingSelectItem,
  SettingSwitchItem,
  SettingsSubPageHeader,
  resolveSettingSelectRenderState,
  resolveSettingSwitchRenderState,
  resolveSettingsSubPageHeaderState
} from '../main/ets/pages/components/views/SettingsItems';
import { AiParserItem, AiResponseParser } from '../main/ets/infrastructure/services/AiResponseParser';

interface SettingSwitchItemHostPrivateHN {
  __checked: Object;
}

interface SettingSwitchItemCtorParamsHN {
  checked: Object;
}

interface SettingSwitchItemPrivateHN {
  title: string;
  desc: string;
  loading: boolean;
  checked: boolean;
  onToggle: (value: boolean) => void;
  initialRender(): void;
  setInitiallyProvidedValue(params: SettingSwitchItemParamsHN): void;
  updateStateVars(params: SettingSwitchItemParamsHN): void;
}

interface SettingSwitchItemParamsHN {
  title?: string;
  desc?: string;
  loading?: boolean;
  checked?: boolean;
  onToggle?: (value: boolean) => void;
}

interface SettingSelectItemPrivateHN {
  title: string;
  desc: string;
  valueText: string;
  onClickItem: () => void;
  initialRender(): void;
  setInitiallyProvidedValue(params: SettingSelectItemParamsHN): void;
  updateStateVars(params: SettingSelectItemParamsHN): void;
}

interface SettingSelectItemParamsHN {
  title?: string;
  desc?: string;
  valueText?: string;
  onClickItem?: () => void;
}

interface SettingCategoryItemPrivateHN {
  title: string;
  desc: string;
  effectiveTheme: string;
  onClickItem: () => void;
  getPalette(): Object;
  initialRender(): void;
  setInitiallyProvidedValue(params: SettingCategoryItemParamsHN): void;
  updateStateVars(params: SettingCategoryItemParamsHN): void;
}

interface SettingCategoryItemParamsHN {
  title?: string;
  desc?: string;
  onClickItem?: () => void;
}

interface SettingsSubPageHeaderPrivateHN {
  title: string;
  effectiveTheme: string;
  getPalette(): Object;
  initialRender(): void;
  setInitiallyProvidedValue(params: SettingsSubPageHeaderParamsHN): void;
  updateStateVars(params: SettingsSubPageHeaderParamsHN): void;
}

interface SettingsSubPageHeaderParamsHN {
  title?: string;
}

interface AiResponseParserPrivateHN {
  tryExtractItemsFromParsed(parsed: Object, depth?: number): AiParserItem[] | null;
  buildLooseParseCandidates(contentRaw: string, normalized: string): string[];
}

@Component
struct SettingSwitchItemHostHN {
  @State checked: boolean = false;

  build() {
    SettingSwitchItem({
      checked: $checked
    });
  }
}

function createSettingSwitchItemHN(): SettingSwitchItemPrivateHN {
  const host = new SettingSwitchItemHostHN(undefined, {} as LocalStorage) as Object as SettingSwitchItemHostPrivateHN;
  const params: SettingSwitchItemCtorParamsHN = {
    checked: host.__checked
  };
  return new SettingSwitchItem(host as Object, params as Object as LocalStorage) as Object as SettingSwitchItemPrivateHN;
}

function identityHN(item: AiParserItem): AiParserItem {
  return item;
}

class AiParserListHolderHN {
  list: AiParserItem[] = [];
}

class AiParserRandomHolderHN {
  random: AiParserListHolderHN = new AiParserListHolderHN();
}

class AiParserPayloadRootHN {
  content: Object | null = null;
  payload: AiParserRandomHolderHN = new AiParserRandomHolderHN();
}

class AiParserItemsRootHN {
  items: AiParserItem[] = [];
}

export default function phase2BatchHNTest() {
  describe('unit_test_case_generator_autofill_Phase2BatchHN_settings_item_default_callbacks', () => {
    it('normal: setting_switch_default_state_should_render_without_custom_toggle', 0, () => {
      // Arrange
      const page = createSettingSwitchItemHN();
      let threw = false;

      // Act
      try {
        page.initialRender();
        page.onToggle(true);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.title).assertEqual('');
      expect(page.desc).assertEqual('');
      expect(page.loading).assertFalse();
      expect(resolveSettingSwitchRenderState(page.loading).showToggle).assertTrue();
    });

    it('boundary: setting_switch_default_loading_state_should_keep_toggle_branch_available', 0, () => {
      // Arrange
      const page = createSettingSwitchItemHN();
      let threw = false;

      // Act
      page.updateStateVars({ loading: false, checked: true });
      try {
        page.initialRender();
        page.onToggle(false);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(resolveSettingSwitchRenderState(false).loadingText).assertEqual('');
    });

    it('invalid: setting_select_default_state_should_render_blank_value_and_noop_click', 0, () => {
      // Arrange
      const page = new SettingSelectItem(undefined, {} as LocalStorage) as Object as SettingSelectItemPrivateHN;
      let threw = false;

      // Act
      try {
        page.initialRender();
        page.onClickItem();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.title).assertEqual('');
      expect(page.desc).assertEqual('');
      expect(page.valueText).assertEqual('');
      expect(resolveSettingSelectRenderState(page.valueText).trailingText).assertEqual('>');
    });

    it('conflict: setting_select_update_after_default_render_should_keep_click_handler_stable', 0, () => {
      // Arrange
      const page = new SettingSelectItem(undefined, {} as LocalStorage) as Object as SettingSelectItemPrivateHN;
      let clicked = false;
      let threw = false;

      // Act
      try {
        page.initialRender();
        page.setInitiallyProvidedValue({
          title: 'Theme',
          desc: 'Mode',
          valueText: 'System',
          onClickItem: (): void => {
            clicked = true;
          }
        });
        page.updateStateVars({ valueText: 'Dark' });
        page.onClickItem();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(clicked).assertTrue();
      expect(page.valueText).assertEqual('Dark');
    });

    it('regression: setting_category_default_state_should_render_light_palette_and_noop_click', 0, () => {
      // Arrange
      const page = new SettingCategoryItem(undefined, {} as LocalStorage) as Object as SettingCategoryItemPrivateHN;
      let threw = false;

      // Act
      try {
        page.initialRender();
        page.onClickItem();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.title).assertEqual('');
      expect(page.desc).assertEqual('');
      expect(page.getPalette() !== null).assertTrue();
    });

    it('combined: settings_header_default_and_updated_title_should_keep_back_label_state', 0, () => {
      // Arrange
      const page = new SettingsSubPageHeader(undefined, {} as LocalStorage) as Object as SettingsSubPageHeaderPrivateHN;
      let threw = false;

      // Act
      try {
        page.initialRender();
        page.setInitiallyProvidedValue({ title: 'General' });
        page.updateStateVars({ title: 'Security' });
        page.effectiveTheme = 'dark';
        page.initialRender();
      } catch (_error) {
        threw = true;
      }
      const state = resolveSettingsSubPageHeaderState(page.title);

      // Assert
      expect(threw).assertFalse();
      expect(state.title).assertEqual('Security');
      expect(state.backLabel).assertEqual('\u8FD4\u56DE');
      expect(page.getPalette() !== null).assertTrue();
    });
  });

  describe('unit_test_case_generator_autofill_Phase2BatchHN_ai_response_parser_deep_edges', () => {
    it('normal: ai_parser_private_extract_should_walk_generic_nested_object_key', 0, () => {
      // Arrange
      const parser = AiResponseParser as Object as AiResponseParserPrivateHN;
      const parsed = new AiParserPayloadRootHN();
      const item: AiParserItem = {
        name: 'Nested Park',
        duration: 35,
        ai_reasoning: 'generic key',
        type: 0
      };
      parsed.payload.random.list.push(item);

      // Act
      const items = parser.tryExtractItemsFromParsed(parsed as Object, 0);

      // Assert
      expect(items !== null).assertTrue();
      expect((items as AiParserItem[])[0].name).assertEqual('Nested Park');
    });

    it('boundary: ai_parser_private_extract_should_stop_when_depth_exceeds_limit', 0, () => {
      // Arrange
      const parser = AiResponseParser as Object as AiResponseParserPrivateHN;
      const parsed = new AiParserItemsRootHN();
      const item: AiParserItem = {
        name: 'Too Deep',
        duration: 20,
        ai_reasoning: 'depth',
        type: 0
      };
      parsed.items.push(item);

      // Act
      const items = parser.tryExtractItemsFromParsed(parsed as Object, 5);

      // Assert
      expect(items === null).assertTrue();
    });

    it('invalid: ai_parser_private_extract_should_return_null_for_empty_string_and_number', 0, () => {
      // Arrange
      const parser = AiResponseParser as Object as AiResponseParserPrivateHN;

      // Act
      const emptyResult = parser.tryExtractItemsFromParsed('   ' as Object, 0);
      const numberResult = parser.tryExtractItemsFromParsed(12 as Object, 0);

      // Assert
      expect(emptyResult === null).assertTrue();
      expect(numberResult === null).assertTrue();
    });

    it('conflict: ai_parser_loose_candidates_should_dedupe_equivalent_sources', 0, () => {
      // Arrange
      const parser = AiResponseParser as Object as AiResponseParserPrivateHN;
      const normalized = '[{"name":"A","duration":30,"ai_reasoning":"r","type":0}]';

      // Act
      const candidates = parser.buildLooseParseCandidates(normalized, normalized);

      // Assert
      expect(candidates.length >= 1).assertTrue();
      expect(candidates[0]).assertEqual(normalized);
    });

    it('regression: ai_parser_content_array_should_ignore_non_text_objects_and_join_plain_fragments', 0, () => {
      // Arrange
      const response =
        '{"choices":[{"message":{"content":["[{\\"name\\":\\"Segment A\\",\\"duration\\":40,\\"ai_reasoning\\":\\"plain\\",\\"type\\":0}]",{"unknown":"ignored"}]}}]}';

      // Act
      const items = AiResponseParser.parseModelResponseForTest(response, identityHN);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Segment A');
      expect(items[0].duration).assertEqual(40);
    });

    it('combined: ai_parser_line_text_should_skip_empty_name_candidate_and_keep_next_valid_line', 0, () => {
      // Arrange
      const raw = '- duration: 20min reason: missing name\n- Museum Stop duration: 45min reason: valid';

      // Act
      const items = AiResponseParser.parseItemsFromContent(raw, identityHN);

      // Assert
      expect(items.length).assertEqual(1);
      expect(items[0].name).assertEqual('Museum Stop');
      expect(items[0].duration).assertEqual(45);
    });
  });
}
