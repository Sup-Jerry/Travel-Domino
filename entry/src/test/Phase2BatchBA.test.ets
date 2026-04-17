import { describe, expect, it } from '@ohos/hypium';
import { LoginStatus } from '../main/ets/domain/auth/AuthTypes';
import { AppTexts } from '../main/ets/common/constants/AppTexts';
import { TravelPlanItem } from '../main/ets/model/interface/IStandardEvent';
import {
  parseHuaweiLoginErrorCodeFromMessage,
  resolveLoginAgreementRequiredToast,
  resolveLoginFailureToast,
  shouldUseHuaweiApiFallbackByCode
} from '../main/ets/pages/LoginPage';
import {
  resolveAuthGateCheckingText,
  resolveAuthGateTargetUrl,
  shouldAuthGateRouteToPlanList
} from '../main/ets/pages/AuthGatePage';
import {
  resolveTrashAutoPurgeDiffMs,
  resolveTrashRemainingTimeText
} from '../main/ets/pages/TrashPage';
import {
  resolveArchiveSoftDeleteDialogMessage,
  resolveArchiveSoftDeleteDialogTitle,
  resolveArchiveTagText,
  shouldArchiveSkipSoftDeleteTip
} from '../main/ets/pages/ArchivePage';
import {
  canPlanListRepromptPermission,
  resolvePlanListShareCategory,
  resolvePlanListShareEndTime,
  resolvePlanListShareIcon,
  resolvePlanListShareStartTime
} from '../main/ets/pages/PlanListPage';

function buildShareEventBA(): TravelPlanItem {
  const item = {} as TravelPlanItem;
  item.fixedStartTime = '09:30';
  item.computedStartTime = '10:15';
  item.priority = 0;
  item.lockStatus = 0;
  item.type = 'NORMAL';
  item.duration = 90;
  return item;
}

export default function phase2BatchBATest() {
  describe('phase2BatchBATest', () => {
    it('normal: login_agreement_toast_should_include_protocol_keywords', 0, () => {
      // Arrange
      // Act
      const message = resolveLoginAgreementRequiredToast();
      // Assert
      expect(message.indexOf('用户协议') >= 0).assertTrue();
      expect(message.indexOf('隐私政策') >= 0).assertTrue();
    });

    it('boundary: login_agreement_toast_should_keep_stable_copy_on_repeat_calls', 0, () => {
      // Arrange
      // Act
      const first = resolveLoginAgreementRequiredToast();
      const second = resolveLoginAgreementRequiredToast();
      // Assert
      expect(first).assertEqual(second);
    });

    it('invalid: login_agreement_toast_should_never_be_blank_or_undefined_text', 0, () => {
      // Arrange
      // Act
      const message = resolveLoginAgreementRequiredToast();
      // Assert
      expect(message.length > 0).assertTrue();
      expect(message.indexOf('undefined') >= 0).assertFalse();
    });

    it('normal: login_error_code_parser_should_extract_target_code', 0, () => {
      // Arrange
      const message = 'huawei_login_error_1001502003_button';
      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      // Assert
      expect(code).assertEqual(1001502003);
    });

    it('boundary: login_error_code_parser_should_support_message_without_suffix', 0, () => {
      // Arrange
      const message = 'huawei_login_error_1001502003';
      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      // Assert
      expect(code).assertEqual(1001502003);
    });

    it('invalid: login_error_code_parser_should_return_nan_for_bad_message', 0, () => {
      // Arrange
      const message = 'bad_message';
      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      // Assert
      expect(Number.isNaN(code)).assertTrue();
    });

    it('normal: login_api_fallback_guard_should_allow_target_error_code', 0, () => {
      // Arrange
      const code = 1001502003;
      // Act
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);
      // Assert
      expect(shouldFallback).assertTrue();
    });

    it('boundary: login_api_fallback_guard_should_reject_nearby_code', 0, () => {
      // Arrange
      const code = 1001502002;
      // Act
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);
      // Assert
      expect(shouldFallback).assertFalse();
    });

    it('invalid: login_api_fallback_guard_should_reject_nan_code', 0, () => {
      // Arrange
      const code = Number.NaN;
      // Act
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);
      // Assert
      expect(shouldFallback).assertFalse();
    });

    it('normal: login_failure_toast_should_join_prefix_and_detail', 0, () => {
      // Arrange
      const prefix = '登录失败：';
      const detail = 'network_down';
      // Act
      const message = resolveLoginFailureToast(prefix, detail);
      // Assert
      expect(message).assertEqual('登录失败：network_down');
    });

    it('boundary: login_failure_toast_should_keep_prefix_when_detail_empty', 0, () => {
      // Arrange
      const prefix = '登录失败：';
      const detail = '';
      // Act
      const message = resolveLoginFailureToast(prefix, detail);
      // Assert
      expect(message).assertEqual('登录失败：');
    });

    it('invalid: login_failure_toast_should_keep_detail_when_prefix_empty', 0, () => {
      // Arrange
      const prefix = '';
      const detail = 'auth_error';
      // Act
      const message = resolveLoginFailureToast(prefix, detail);
      // Assert
      expect(message).assertEqual('auth_error');
    });

    it('normal: auth_gate_route_guard_should_allow_authenticated_success', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.AUTHENTICATED;
      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      // Assert
      expect(shouldRoute).assertTrue();
    });

    it('boundary: auth_gate_route_guard_should_block_when_success_false', 0, () => {
      // Arrange
      const success = false;
      const status = LoginStatus.AUTHENTICATED;
      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      // Assert
      expect(shouldRoute).assertFalse();
    });

    it('invalid: auth_gate_route_guard_should_block_non_authenticated_status', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.UNAUTHENTICATED;
      // Act
      const shouldRoute = shouldAuthGateRouteToPlanList(success, status);
      // Assert
      expect(shouldRoute).assertFalse();
    });

    it('normal: auth_gate_target_url_should_route_authenticated_success_to_plan_list', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.AUTHENTICATED;
      // Act
      const target = resolveAuthGateTargetUrl(success, status);
      // Assert
      expect(target).assertEqual('pages/PlanListPage');
    });

    it('boundary: auth_gate_target_url_should_fallback_to_login_when_success_false', 0, () => {
      // Arrange
      const success = false;
      const status = LoginStatus.AUTHENTICATED;
      // Act
      const target = resolveAuthGateTargetUrl(success, status);
      // Assert
      expect(target).assertEqual('pages/LoginPage');
    });

    it('invalid: auth_gate_target_url_should_fallback_to_login_for_failed_status', 0, () => {
      // Arrange
      const success = true;
      const status = LoginStatus.LOGIN_FAILED;
      // Act
      const target = resolveAuthGateTargetUrl(success, status);
      // Assert
      expect(target).assertEqual('pages/LoginPage');
    });

    it('normal: auth_gate_checking_text_should_use_checking_copy_when_busy', 0, () => {
      // Arrange
      // Act
      const text = resolveAuthGateCheckingText(true);
      // Assert
      expect(text.indexOf('检查') >= 0).assertTrue();
    });

    it('boundary: auth_gate_checking_text_should_use_jump_copy_when_not_busy', 0, () => {
      // Arrange
      // Act
      const text = resolveAuthGateCheckingText(false);
      // Assert
      expect(text.indexOf('跳转') >= 0).assertTrue();
    });

    it('invalid: auth_gate_checking_text_should_never_be_blank_or_undefined_text', 0, () => {
      // Arrange
      // Act
      const text = resolveAuthGateCheckingText(false);
      // Assert
      expect(text.length > 0).assertTrue();
      expect(text.indexOf('undefined') >= 0).assertFalse();
    });

    it('normal: trash_auto_purge_diff_should_return_positive_remaining_ms', 0, () => {
      // Arrange
      const now = 1_000;
      const deleteTime = now - 2 * 24 * 60 * 60 * 1000;
      const retentionMs = 3 * 24 * 60 * 60 * 1000;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, retentionMs);
      // Assert
      expect(diff).assertEqual(24 * 60 * 60 * 1000);
    });

    it('boundary: trash_auto_purge_diff_should_allow_exact_zero_deadline', 0, () => {
      // Arrange
      const now = 5_000;
      const deleteTime = 4_000;
      const retentionMs = 1_000;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(deleteTime, now, retentionMs);
      // Assert
      expect(diff).assertEqual(0);
    });

    it('invalid: trash_auto_purge_diff_should_return_negative_one_when_delete_time_missing', 0, () => {
      // Arrange
      const now = 9_999;
      // Act
      const diff = resolveTrashAutoPurgeDiffMs(undefined, now);
      // Assert
      expect(diff).assertEqual(-1);
    });

    it('normal: trash_remaining_time_text_should_render_day_and_hour_copy', 0, () => {
      // Arrange
      const now = 1_000;
      const deleteTime = now - 2 * 24 * 60 * 60 * 1000;
      const retentionMs = 3 * 24 * 60 * 60 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('1天 0小时 后自动清除');
    });

    it('boundary: trash_remaining_time_text_should_render_hour_only_copy_under_one_day', 0, () => {
      // Arrange
      const now = 100_000;
      const deleteTime = now - 6 * 60 * 60 * 1000;
      const retentionMs = 12 * 60 * 60 * 1000;
      // Act
      const text = resolveTrashRemainingTimeText(deleteTime, now, retentionMs);
      // Assert
      expect(text).assertEqual('6小时 后自动清除');
    });

    it('invalid: trash_remaining_time_text_should_fallback_to_immediate_when_missing_delete_time', 0, () => {
      // Arrange
      const now = 100_000;
      // Act
      const text = resolveTrashRemainingTimeText(undefined, now);
      // Assert
      expect(text).assertEqual('即将清除');
    });

    it('normal: archive_skip_tip_guard_should_return_true_for_enabled_preference', 0, () => {
      // Arrange
      const isSkip = true;
      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(isSkip);
      // Assert
      expect(shouldSkip).assertTrue();
    });

    it('boundary: archive_skip_tip_guard_should_return_false_for_disabled_preference', 0, () => {
      // Arrange
      const isSkip = false;
      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(isSkip);
      // Assert
      expect(shouldSkip).assertFalse();
    });

    it('invalid: archive_skip_tip_guard_should_not_flip_disabled_preference_to_true', 0, () => {
      // Arrange
      const isSkip = false;
      // Act
      const shouldSkip = shouldArchiveSkipSoftDeleteTip(isSkip);
      // Assert
      expect(shouldSkip).assertFalse();
    });

    it('normal: archive_dialog_title_should_include_recycle_keyword', 0, () => {
      // Arrange
      // Act
      const title = resolveArchiveSoftDeleteDialogTitle();
      // Assert
      expect(title.indexOf('回收站') >= 0).assertTrue();
    });

    it('boundary: archive_dialog_title_should_keep_same_copy_on_repeat_calls', 0, () => {
      // Arrange
      // Act
      const first = resolveArchiveSoftDeleteDialogTitle();
      const second = resolveArchiveSoftDeleteDialogTitle();
      // Assert
      expect(first).assertEqual(second);
    });

    it('invalid: archive_dialog_title_should_never_be_blank_or_undefined_text', 0, () => {
      // Arrange
      // Act
      const title = resolveArchiveSoftDeleteDialogTitle();
      // Assert
      expect(title.length > 0).assertTrue();
      expect(title.indexOf('undefined') >= 0).assertFalse();
    });

    it('normal: archive_dialog_message_should_match_shared_constant', 0, () => {
      // Arrange
      // Act
      const message = resolveArchiveSoftDeleteDialogMessage();
      // Assert
      expect(message).assertEqual(AppTexts.SOFT_DELETE_RECYCLE_TIP);
    });

    it('boundary: archive_dialog_message_should_keep_same_copy_on_repeat_calls', 0, () => {
      // Arrange
      // Act
      const first = resolveArchiveSoftDeleteDialogMessage();
      const second = resolveArchiveSoftDeleteDialogMessage();
      // Assert
      expect(first).assertEqual(second);
    });

    it('invalid: archive_dialog_message_should_never_be_blank_or_undefined_text', 0, () => {
      // Arrange
      // Act
      const message = resolveArchiveSoftDeleteDialogMessage();
      // Assert
      expect(message.length > 0).assertTrue();
      expect(message.indexOf('undefined') >= 0).assertFalse();
    });

    it('normal: archive_tag_text_should_trim_to_archived_label', 0, () => {
      // Arrange
      // Act
      const tag = resolveArchiveTagText();
      // Assert
      expect(tag.trim()).assertEqual('已归档');
    });

    it('boundary: archive_tag_text_should_preserve_padding_spaces', 0, () => {
      // Arrange
      // Act
      const tag = resolveArchiveTagText();
      // Assert
      expect(tag.startsWith(' ')).assertTrue();
      expect(tag.endsWith(' ')).assertTrue();
    });

    it('invalid: archive_tag_text_should_never_be_blank_or_undefined_text', 0, () => {
      // Arrange
      // Act
      const tag = resolveArchiveTagText();
      // Assert
      expect(tag.length > 0).assertTrue();
      expect(tag.indexOf('undefined') >= 0).assertFalse();
    });

    it('normal: plan_list_permission_reprompt_should_allow_first_prompt', 0, () => {
      // Arrange
      const now = 2_000;
      const lastPromptAt = 0;
      const hasPromptedBefore = false;
      const cooldownMs = 1_000;
      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, hasPromptedBefore, cooldownMs);
      // Assert
      expect(allowed).assertTrue();
    });

    it('boundary: plan_list_permission_reprompt_should_allow_when_cooldown_exactly_met', 0, () => {
      // Arrange
      const now = 2_000;
      const lastPromptAt = 1_000;
      const hasPromptedBefore = true;
      const cooldownMs = 1_000;
      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, hasPromptedBefore, cooldownMs);
      // Assert
      expect(allowed).assertTrue();
    });

    it('invalid: plan_list_permission_reprompt_should_block_within_cooldown_window', 0, () => {
      // Arrange
      const now = 1_999;
      const lastPromptAt = 1_000;
      const hasPromptedBefore = true;
      const cooldownMs = 1_000;
      // Act
      const allowed = canPlanListRepromptPermission(now, lastPromptAt, hasPromptedBefore, cooldownMs);
      // Assert
      expect(allowed).assertFalse();
    });

    it('normal: plan_list_share_start_should_use_fixed_start_time_when_valid', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('09:30');
    });

    it('boundary: plan_list_share_start_should_fallback_to_computed_start_time', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.fixedStartTime = '';
      event.computedStartTime = '10:15';
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('10:15');
    });

    it('invalid: plan_list_share_start_should_fallback_when_all_times_invalid', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.fixedStartTime = 'bad_time';
      event.computedStartTime = '';
      // Act
      const start = resolvePlanListShareStartTime(event);
      // Assert
      expect(start).assertEqual('--:--');
    });

    it('normal: plan_list_share_end_should_calculate_end_time_from_duration', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      // Act
      const end = resolvePlanListShareEndTime(event, 90);
      // Assert
      expect(end).assertEqual('11:00');
    });

    it('boundary: plan_list_share_end_should_keep_same_time_when_duration_zero', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      // Act
      const end = resolvePlanListShareEndTime(event, 0);
      // Assert
      expect(end).assertEqual('09:30');
    });

    it('invalid: plan_list_share_end_should_fallback_when_start_time_invalid', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.fixedStartTime = '';
      event.computedStartTime = 'invalid';
      // Act
      const end = resolvePlanListShareEndTime(event, 90);
      // Assert
      expect(end).assertEqual('--:--');
    });

    it('normal: plan_list_share_icon_should_prioritize_star_for_priority_event', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.priority = 1;
      // Act
      const icon = resolvePlanListShareIcon(event);
      // Assert
      expect(icon).assertEqual('⭐');
    });

    it('boundary: plan_list_share_icon_should_use_clock_for_anchor_like_event', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.lockStatus = 1;
      event.type = 'ANCHOR';
      // Act
      const icon = resolvePlanListShareIcon(event);
      // Assert
      expect(icon).assertEqual('⏰');
    });

    it('invalid: plan_list_share_icon_should_fallback_to_location_pin_for_normal_event', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      // Act
      const icon = resolvePlanListShareIcon(event);
      // Assert
      expect(icon).assertEqual('📍');
    });

    it('normal: plan_list_share_category_should_mark_anchor_as_fixed', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.type = 'ANCHOR';
      // Act
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(category).assertEqual('固定行程');
    });

    it('boundary: plan_list_share_category_should_mark_locked_event_as_fixed', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.lockStatus = 1;
      // Act
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(category).assertEqual('固定行程');
    });

    it('invalid: plan_list_share_category_should_fallback_to_flexible_for_normal_event', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      // Act
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(category).assertEqual('灵活行程');
    });

    it('conflict: plan_list_share_icon_and_category_should_stay_aligned_for_anchor_event', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      event.type = 'ANCHOR';
      event.lockStatus = 1;
      const lockedOnly = buildShareEventBA();
      lockedOnly.lockStatus = 1;
      // Act
      const icon = resolvePlanListShareIcon(event);
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(icon.length > 0).assertTrue();
      expect(category).assertEqual(resolvePlanListShareCategory(lockedOnly));
    });

    it('regression: login_error_code_parser_and_fallback_guard_should_keep_target_code_path', 0, () => {
      // Arrange
      const message = 'huawei_login_error_1001502003_retry';
      // Act
      const code = parseHuaweiLoginErrorCodeFromMessage(message);
      const shouldFallback = shouldUseHuaweiApiFallbackByCode(code);
      // Assert
      expect(code).assertEqual(1001502003);
      expect(shouldFallback).assertTrue();
    });

    it('combined: plan_list_share_helpers_should_resolve_start_end_icon_and_category_together', 0, () => {
      // Arrange
      const event = buildShareEventBA();
      // Act
      const start = resolvePlanListShareStartTime(event);
      const end = resolvePlanListShareEndTime(event, event.duration);
      const icon = resolvePlanListShareIcon(event);
      const category = resolvePlanListShareCategory(event);
      // Assert
      expect(start).assertEqual('09:30');
      expect(end).assertEqual('11:00');
      expect(icon.length > 0).assertTrue();
      expect(category.length > 0).assertTrue();
    });
  });
}
