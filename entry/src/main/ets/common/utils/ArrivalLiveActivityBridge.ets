import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'ArrivalLiveBridge';

const ARRIVAL_LIVE_SEQ_KEY = 'ArrivalLiveActivitySeq';
const ARRIVAL_LIVE_PAYLOAD_KEY = 'ArrivalLiveActivityPayload';

export type ArrivalLiveStatus = 'REMINDING' | 'ACKED' | 'STARTED' | 'ENDED';

export interface ArrivalLiveActivityPayload {
  seq: number;
  planId: number;
  eventId: number;
  placeName: string;
  status: ArrivalLiveStatus;
  updatedAt: number;
}

/**
 * Live Activity 预留桥接层：
 * - 当前：使用 AppStorage 写入状态，供 UI/后续接入使用
 * - 后续：在此处替换为真实 Live View Kit API 调用
 */
export class ArrivalLiveActivityBridge {
  public static init(): void {
    AppStorage.setOrCreate(ARRIVAL_LIVE_SEQ_KEY, 0);
    AppStorage.setOrCreate(ARRIVAL_LIVE_PAYLOAD_KEY, '');
  }

  public static start(planId: number, eventId: number, placeName: string): void {
    ArrivalLiveActivityBridge.publish(planId, eventId, placeName, 'REMINDING');
  }

  public static update(planId: number, eventId: number, placeName: string, status: ArrivalLiveStatus): void {
    ArrivalLiveActivityBridge.publish(planId, eventId, placeName, status);
  }

  public static end(planId: number, eventId: number, placeName: string): void {
    ArrivalLiveActivityBridge.publish(planId, eventId, placeName, 'ENDED');
  }

  private static publish(planId: number, eventId: number, placeName: string, status: ArrivalLiveStatus): void {
    const currentSeq = AppStorage.get<number>(ARRIVAL_LIVE_SEQ_KEY) ?? 0;
    const nextSeq = currentSeq + 1;
    const payload: ArrivalLiveActivityPayload = {
      seq: nextSeq,
      planId: planId,
      eventId: eventId,
      placeName: placeName,
      status: status,
      updatedAt: Date.now()
    };
    AppStorage.setOrCreate(ARRIVAL_LIVE_PAYLOAD_KEY, JSON.stringify(payload));
    AppStorage.setOrCreate(ARRIVAL_LIVE_SEQ_KEY, nextSeq);
    hilog.info(0x0000, TAG, `[LIVE_BRIDGE][publish] status=${status}, eventId=${eventId}, planId=${planId}`);
  }
}
