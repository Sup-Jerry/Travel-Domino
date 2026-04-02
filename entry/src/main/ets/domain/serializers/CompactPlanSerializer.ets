import { TravelPlanItem } from '../../model/interface/IStandardEvent';

// 压缩后的计划元数据
interface CompactPlanMeta {
  t: string;      // title
  sd: number;     // startDate
  st: number;     // status
  ar: number;     // enableAutoAmapRoute
}

// 压缩后的事件
interface CompactEvent {
  n: string;      // name
  nt?: string;    // note
  d: number;      // duration
  pt: number;     // preTravelMinutes
  so: number;     // sortOrder
  s: number;      // status
  ls: number;     // lockStatus
  ft?: string;    // fixedStartTime
  do: number;     // dayOffset
  it: number;     // itemType
  p: number;      // priority
  tm: number;     // travelMode
  itm: number;    // isTravelManual
  src: number;    // source
  gid: number;    // groupId
  addr?: string;  // address
  lat?: number;   // latitude
  lng?: number;   // longitude
  ast?: number;   // actualStartTime
  aet?: number;   // actualEndTime
  cs: number;     // completionStatus
  tp: string;     // type
}

// 压缩后的完整数据
interface CompactPayload {
  v: number;              // schemaVersion
  exp: number;            // exportedAt
  p: CompactPlanMeta;     // plan
  e: CompactEvent[];      // events
}

export class CompactPlanSerializer {
  /**
   * 压缩计划数据用于分享
   */
  public static compressForShare(
    planMeta: { title: string; startDate: number; status: number; enableAutoAmapRoute: number },
    events: TravelPlanItem[]
  ): string {
    const compactPlan: CompactPlanMeta = {
      t: planMeta.title,
      sd: planMeta.startDate,
      st: planMeta.status,
      ar: planMeta.enableAutoAmapRoute
    };

    const compactEvents: CompactEvent[] = events.map(e => CompactPlanSerializer.compressEvent(e));

    const payload: CompactPayload = {
      v: 1,
      exp: Date.now(),
      p: compactPlan,
      e: compactEvents
    };

    return JSON.stringify(payload);
  }

  /**
   * 解压分享的计划数据
   */
  public static decompressFromShare(compressed: string): {
    plan: { title: string; startDate: number; status: number; enableAutoAmapRoute: number };
    events: TravelPlanItem[];
  } {
    const payload = JSON.parse(compressed) as CompactPayload;

    if (payload.v !== 1) {
      throw new Error(`unsupported_version:${payload.v}`);
    }

    const plan = {
      title: payload.p.t,
      startDate: payload.p.sd,
      status: payload.p.st,
      enableAutoAmapRoute: payload.p.ar
    };

    const events = payload.e.map(e => CompactPlanSerializer.decompressEvent(e));

    return { plan, events };
  }

  private static compressEvent(event: TravelPlanItem): CompactEvent {
    return {
      n: event.name,
      nt: event.note || undefined,
      d: event.duration,
      pt: event.preTravelMinutes,
      so: event.sortOrder,
      s: event.status,
      ls: event.lockStatus ?? 0,
      ft: event.fixedStartTime || undefined,
      do: event.dayOffset ?? 0,
      it: event.itemType ?? 0,
      p: event.priority ?? 0,
      tm: event.travelMode ?? event.transportMode ?? 2,
      itm: event.isTravelManual ?? 0,
      src: event.source ?? 0,
      gid: event.groupId ?? 0,
      addr: event.address || undefined,
      lat: event.latitude || undefined,
      lng: event.longitude || undefined,
      ast: event.actualStartTime || undefined,
      aet: event.actualEndTime || undefined,
      cs: event.completionStatus ?? 0,
      tp: event.type
    };
  }

  private static decompressEvent(compact: CompactEvent): TravelPlanItem {
    return {
      name: compact.n,
      note: compact.nt || '',
      duration: compact.d,
      preTravelMinutes: compact.pt,
      sortOrder: compact.so,
      status: compact.s,
      lockStatus: compact.ls,
      fixedStartTime: compact.ft,
      dayOffset: compact.do,
      itemType: compact.it,
      priority: compact.p,
      travelMode: compact.tm,
      transportMode: compact.tm,
      isTravelManual: compact.itm,
      source: compact.src,
      groupId: compact.gid,
      address: compact.addr || '',
      latitude: compact.lat,
      longitude: compact.lng,
      actualStartTime: compact.ast,
      actualEndTime: compact.aet,
      completionStatus: compact.cs,
      type: compact.tp,
      delFlag: 0
    };
  }
}
