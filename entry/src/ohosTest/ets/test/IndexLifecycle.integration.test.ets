import { describe, it, expect } from '@ohos/hypium';
import { PageDraftRecovery } from '../../../main/ets/common/utils/PageDraftRecovery';

export default function indexLifecycleIntegrationTest() {
  describe('IndexLifecycleIntegrationTest', () => {
    it('recover_should_clear_and_skip_when_temp_corrupted', 0, () => {
      const result = PageDraftRecovery.recover('{bad_json', '');
      expect(result.shouldClear).assertEqual(true);
      expect(result.shouldRestore).assertEqual(false);
      expect(result.reason).assertEqual('temp_invalid');
    });

    it('recover_should_clear_and_restore_when_temp_valid', 0, () => {
      const temp = JSON.stringify({
        name: '旧地点',
        note: '备注',
        duration: 45,
        isAnchor: false,
        fixedTime: '09:00',
        dayOffset: 1,
        isSchedule: true,
        lat: 31.23,
        lng: 121.47
      });
      const result = PageDraftRecovery.recover(temp, '');
      expect(result.shouldClear).assertEqual(true);
      expect(result.shouldRestore).assertEqual(true);
      expect(result.restored?.name ?? '').assertEqual('旧地点');
      expect(result.restored?.duration ?? 0).assertEqual(45);
    });

    it('recover_should_fail_when_picked_corrupted', 0, () => {
      const temp = JSON.stringify({
        name: '旧地点',
        note: '',
        duration: 60,
        isAnchor: false,
        fixedTime: '',
        dayOffset: 0,
        isSchedule: true,
        lat: 0,
        lng: 0
      });
      const result = PageDraftRecovery.recover(temp, '{bad_loc');
      expect(result.shouldClear).assertEqual(true);
      expect(result.shouldRestore).assertEqual(false);
      expect(result.reason).assertEqual('picked_invalid');
    });
  });
}
