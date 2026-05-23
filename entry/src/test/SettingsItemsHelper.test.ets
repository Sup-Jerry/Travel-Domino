import { describe, it, expect } from '@ohos/hypium';
import {
  SettingSwitchItem,
  SettingCategoryItem,
  SettingSelectItem,
  SettingsSubPageHeader,
  getSettingsSubPageBackLabel,
  resolveSettingSelectRenderState,
  resolveSettingSwitchRenderState,
  resolveSettingsSubPageHeaderState,
  resolveSettingSelectValueText,
  shouldShowSettingSwitchLoading
} from '../main/ets/pages/components/views/SettingsItems';

interface SettingSwitchItemParamsTest {
  title?: string;
  desc?: string;
  loading?: boolean;
  checked?: boolean;
  onToggle?: (value: boolean) => void;
}

interface SettingSwitchItemHostPrivateTest {
  __checked: Object;
}

interface SettingSwitchItemCtorParamsTest {
  checked: Object;
}

interface SettingSwitchItemPrivateTest {
  title: string;
  desc: string;
  loading: boolean;
  checked: boolean;
  onToggle: (value: boolean) => void;
  setInitiallyProvidedValue(params: SettingSwitchItemParamsTest): void;
  updateStateVars(params: SettingSwitchItemParamsTest): void;
  initialRender(): void;
}

interface SettingSelectItemParamsTest {
  title?: string;
  desc?: string;
  valueText?: string;
  onClickItem?: () => void;
}

interface SettingSelectItemPrivateTest {
  title: string;
  desc: string;
  valueText: string;
  onClickItem: () => void;
  setInitiallyProvidedValue(params: SettingSelectItemParamsTest): void;
  updateStateVars(params: SettingSelectItemParamsTest): void;
  initialRender(): void;
}

interface SettingCategoryItemParamsTest {
  title?: string;
  desc?: string;
  onClickItem?: () => void;
}

interface SettingCategoryItemPrivateTest {
  title: string;
  desc: string;
  effectiveTheme: string;
  onClickItem: () => void;
  setInitiallyProvidedValue(params: SettingCategoryItemParamsTest): void;
  updateStateVars(params: SettingCategoryItemParamsTest): void;
  getPalette(): Object;
  initialRender(): void;
}

interface SettingsSubPageHeaderParamsTest {
  title?: string;
}

interface SettingsSubPageHeaderPrivateTest {
  title: string;
  effectiveTheme: string;
  setInitiallyProvidedValue(params: SettingsSubPageHeaderParamsTest): void;
  updateStateVars(params: SettingsSubPageHeaderParamsTest): void;
  getPalette(): Object;
  initialRender(): void;
}

@Component
struct SettingSwitchItemHostTest {
  @State checked: boolean = true;

  build() {
    SettingSwitchItem({
      checked: $checked
    });
  }
}

function createSettingSwitchItemForTest(): SettingSwitchItemPrivateTest {
  const host = new SettingSwitchItemHostTest(undefined, {} as LocalStorage) as Object as SettingSwitchItemHostPrivateTest;
  const params: SettingSwitchItemCtorParamsTest = {
    checked: host.__checked
  };
  return new SettingSwitchItem(host as Object, params as Object as LocalStorage) as Object as SettingSwitchItemPrivateTest;
}

export default function settingsItemsHelperTest() {
  describe('unit_test_case_generator_autofill_SettingsItemsHelper', () => {
    it('normal: settings_switch_should_show_loading_when_flag_true', 0, () => {
      // Arrange
      const loading = true;
      // Act
      const showLoading = shouldShowSettingSwitchLoading(loading);
      // Assert
      expect(showLoading).assertTrue();
    });

    it('boundary: settings_select_value_should_fallback_to_empty_when_blank', 0, () => {
      // Arrange
      const valueText = '';
      // Act
      const resolved = resolveSettingSelectValueText(valueText);
      // Assert
      expect(resolved).assertEqual('');
    });

    it('invalid: settings_switch_should_hide_loading_when_flag_false', 0, () => {
      // Arrange
      const loading = false;
      // Act
      const showLoading = shouldShowSettingSwitchLoading(loading);
      // Assert
      expect(showLoading).assertFalse();
    });

    it('conflict: settings_select_value_should_keep_original_non_empty_text', 0, () => {
      // Arrange
      const valueText = '自动';
      // Act
      const resolved = resolveSettingSelectValueText(valueText);
      // Assert
      expect(resolved).assertEqual('自动');
    });

    it('regression: td-20260412-settings-back-label-should-stay-return', 0, () => {
      // Arrange
      // Act
      const label = getSettingsSubPageBackLabel();
      // Assert
      expect(label).assertEqual('\u8FD4\u56DE');
    });

    it('combined: settings_loading_and_value_resolution_should_be_independent', 0, () => {
      // Arrange
      const loading = true;
      const valueText = '手动';
      // Act
      const showLoading = shouldShowSettingSwitchLoading(loading);
      const resolved = resolveSettingSelectValueText(valueText);
      // Assert
      expect(showLoading).assertTrue();
      expect(resolved).assertEqual('手动');
    });

    it('normal: settings_render_state_helpers_should_resolve_all_component_outputs', 0, () => {
      // Arrange
      const loading = true;
      const valueText = '深色';
      const title = '通用设置';

      // Act
      const switchState = resolveSettingSwitchRenderState(loading);
      const selectState = resolveSettingSelectRenderState(valueText);
      const headerState = resolveSettingsSubPageHeaderState(title);

      // Assert
      expect(switchState.showLoading).assertTrue();
      expect(switchState.showToggle).assertFalse();
      expect(selectState.valueText).assertEqual('深色');
      expect(selectState.trailingText).assertEqual('>');
      expect(headerState.title).assertEqual('通用设置');
      expect(headerState.backLabel).assertEqual('\u8FD4\u56DE');
    });

    it('normal: settings_switch_item_update_state_vars_should_sync_link_checked', 0, () => {
      // Arrange
      const page = createSettingSwitchItemForTest();
      let toggled = false;
      let toggleValue = false;
      let threw = false;

      // Act
      page.setInitiallyProvidedValue({
        title: '归档提示',
        desc: '切换归档提醒',
        loading: false,
        onToggle: (value: boolean) => {
          toggled = true;
          toggleValue = value;
        }
      });
      page.updateStateVars({
        checked: false,
        title: '删除提示'
      });
      try {
        page.initialRender();
        page.onToggle(true);
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.title).assertEqual('删除提示');
      expect(toggled).assertTrue();
      expect(toggleValue).assertTrue();
    });

    it('normal: settings_select_item_initial_render_should_support_value_branch', 0, () => {
      // Arrange
      const page = new SettingSelectItem(undefined, {} as LocalStorage) as Object as SettingSelectItemPrivateTest;
      let clicked = false;
      let threw = false;

      // Act
      page.setInitiallyProvidedValue({
        title: '主题模式',
        desc: '支持浅色深色',
        valueText: '深色',
        onClickItem: () => {
          clicked = true;
        }
      });
      page.updateStateVars({
        valueText: '浅色'
      });
      try {
        page.initialRender();
        page.onClickItem();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(clicked).assertTrue();
      expect(page.valueText).assertEqual('浅色');
    });

    it('combined: settings_category_item_initial_render_should_support_theme_palette_branch', 0, () => {
      // Arrange
      const page = new SettingCategoryItem(undefined, {} as LocalStorage) as Object as SettingCategoryItemPrivateTest;
      let clicked = false;
      let threw = false;

      // Act
      page.setInitiallyProvidedValue({
        title: '偏好洞察',
        desc: '查看你的行程偏好',
        onClickItem: () => {
          clicked = true;
        }
      });
      page.updateStateVars({
        desc: '查看偏好'
      });
      page.effectiveTheme = 'dark';
      try {
        page.initialRender();
        page.onClickItem();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(clicked).assertTrue();
      expect(page.getPalette() !== null).assertTrue();
    });

    it('boundary: settings_sub_page_header_initial_render_should_support_back_button_branch', 0, () => {
      // Arrange
      const page = new SettingsSubPageHeader(undefined, {} as LocalStorage) as Object as SettingsSubPageHeaderPrivateTest;
      let threw = false;

      // Act
      page.setInitiallyProvidedValue({
        title: '通用设置'
      });
      page.updateStateVars({
        title: '安全设置'
      });
      page.effectiveTheme = 'light';
      try {
        page.initialRender();
      } catch (_error) {
        threw = true;
      }

      // Assert
      expect(threw).assertFalse();
      expect(page.getPalette() !== null).assertTrue();
    });
  });
}

