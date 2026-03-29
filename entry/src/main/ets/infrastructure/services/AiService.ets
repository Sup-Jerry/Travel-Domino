// 文件路径: ets/infrastructure/services/AiService.ets
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../../common/utils/AppConfig';
import { HttpRequestHelper } from '../adapters/HttpRequestHelper';
import { ComposableStrategy, PreferenceType } from '../../domain/strategy/TravelStrategyDimensions';
import { StrategyBuilder } from '../../domain/strategy/StrategyBuilder';
import { StrategyService } from '../../domain/strategy/StrategyService';

export interface AiRawItem {
  name: string;
  duration: number;
  ai_reasoning: string;
  type: number;
}

export interface AiGenerateRequest {
  userPrompt: string;
  strategyMode?: number;
  customStrategy?: ComposableStrategy;
}

interface MessageContent {
  role: string;
  content: string;
}

interface Choice {
  index: number;
  message: MessageContent;
  finish_reason: string;
}

interface PanguResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  choices: Choice[];
}

interface HttpResponseLike {
  responseCode: number;
  result: string | Object;
}

type AiRequester = (url: string, options: http.HttpRequestOptions) => Promise<HttpResponseLike>;


export class AiService {
  private static readonly TAG = 'AiService';
  private static requesterForTest: AiRequester | null = null;
  private static readonly DEFAULT_REQUESTED_DAYS = 1;
  private static readonly MAX_REQUESTED_DAYS = 30;
  private static readonly SCENIC_MIN_DURATION = 30;
  private static readonly SCENIC_MAX_DURATION = 180;
  private static readonly FOOD_MIN_DURATION = 20;
  private static readonly FOOD_MAX_DURATION = 120;
  private static readonly HOTEL_MIN_DURATION = 480;
  private static readonly HOTEL_MAX_DURATION = 720;

  public static setRequesterForTest(requester: AiRequester | null): void {
    AiService.requesterForTest = requester;
  }

  private static async doRequest(url: string, options: http.HttpRequestOptions): Promise<HttpResponseLike> {
    if (AiService.requesterForTest) {
      return AiService.requesterForTest(url, options);
    }
    return HttpRequestHelper.request(AiService.TAG, 'generateItinerary', url, options);
  }

  private static unwrapContent(raw: string): string {
    let content = raw.trim();
    const fence = content.match(/```[a-zA-Z]*\s*([\s\S]*?)```/);
    if (fence && fence.length > 1) {
      content = fence[1].trim();
    } else {
      content = content.replace(/```json/gi, '').replace(/```/g, '').trim();
    }

    const firstBracket = content.indexOf('[');
    const lastBracket = content.lastIndexOf(']');
    if (firstBracket >= 0 && lastBracket > firstBracket) {
      content = content.slice(firstBracket, lastBracket + 1).trim();
    }
    return content;
  }

  private static parseItemsFromContent(contentRaw: string): AiRawItem[] {
    const normalized = AiService.unwrapContent(contentRaw);
    let parsed = null as Object | null;
    try {
      parsed = JSON.parse(normalized) as Object;
    } catch (_error) {
      throw new Error('AI 返回内容不是合法 JSON');
    }
    if (!Array.isArray(parsed)) {
      throw new Error('AI 返回内容不是数组');
    }
    const items = parsed as AiRawItem[];
    const normalizedItems: AiRawItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const validName = typeof item.name === 'string' && item.name.trim().length > 0;
      const validDuration = Number.isFinite(Number(item.duration)) && Number(item.duration) > 0;
      if (!validName || !validDuration) {
        throw new Error(`AI 返回项格式错误:index=${i}`);
      }
      normalizedItems.push(AiService.normalizeItem(item));
    }
    return normalizedItems;
  }

  private static normalizeItem(item: AiRawItem): AiRawItem {
    const type = AiService.normalizeItemType(item.type);
    const duration = AiService.normalizeDurationByType(Number(item.duration), type);
    const name = item.name.trim();
    const reason = typeof item.ai_reasoning === 'string' && item.ai_reasoning.trim().length > 0
      ? item.ai_reasoning.trim()
      : 'AI 智能推荐';
    return {
      name: name,
      duration: duration,
      ai_reasoning: reason,
      type: type
    };
  }

  private static normalizeItemType(type: number): number {
    if (type === 0 || type === 1 || type === 2) {
      return type;
    }
    return 0;
  }

  private static normalizeDurationByType(duration: number, type: number): number {
    if (!Number.isFinite(duration)) {
      return 60;
    }
    const rounded = Math.round(duration);
    if (type === 0) {
      return Math.min(AiService.SCENIC_MAX_DURATION, Math.max(AiService.SCENIC_MIN_DURATION, rounded));
    }
    if (type === 1) {
      return Math.min(AiService.FOOD_MAX_DURATION, Math.max(AiService.FOOD_MIN_DURATION, rounded));
    }
    if (type === 2) {
      return Math.min(AiService.HOTEL_MAX_DURATION, Math.max(AiService.HOTEL_MIN_DURATION, rounded));
    }
    return Math.max(10, rounded);
  }

  private static parseSimpleChineseNumber(raw: string): number {
    const text = (raw || '').trim();
    if (text.length === 0) {
      return 0;
    }
    const map: Record<string, number> = {
      '零': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '俩': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9
    };
    if (text === '十') {
      return 10;
    }
    if (text.indexOf('十') >= 0) {
      const parts = text.split('十');
      const leftRaw = (parts[0] || '').trim();
      const rightRaw = (parts[1] || '').trim();
      const left = leftRaw.length === 0 ? 1 : (map[leftRaw] ?? 0);
      const right = rightRaw.length === 0 ? 0 : (map[rightRaw] ?? 0);
      return left * 10 + right;
    }
    return map[text] ?? 0;
  }

  public static resolveRequestedDaysFromPrompt(prompt: string): number {
    const normalized = (prompt || '').replace(/\s+/g, '');
    if (normalized.length === 0) {
      return AiService.DEFAULT_REQUESTED_DAYS;
    }

    const arabicMatch = normalized.match(/([1-9]\d{0,2})(?:天|日)/);
    if (arabicMatch && arabicMatch[1]) {
      const parsed = Number(arabicMatch[1]);
      if (Number.isFinite(parsed)) {
        return Math.min(AiService.MAX_REQUESTED_DAYS, Math.max(AiService.DEFAULT_REQUESTED_DAYS, Math.floor(parsed)));
      }
    }

    const zhMatch = normalized.match(/([零一二两俩三四五六七八九十]{1,3})(?:天|日)/);
    if (zhMatch && zhMatch[1]) {
      const parsed = AiService.parseSimpleChineseNumber(zhMatch[1]);
      if (Number.isFinite(parsed) && parsed > 0) {
        return Math.min(AiService.MAX_REQUESTED_DAYS, Math.max(AiService.DEFAULT_REQUESTED_DAYS, Math.floor(parsed)));
      }
    }

    return AiService.DEFAULT_REQUESTED_DAYS;
  }

  private static resolveStrategyMaxItems(request: AiGenerateRequest): number {
    const requestedDays = AiService.resolveRequestedDaysFromPrompt(request.userPrompt);
    let dailyMax = 5;
    if (request.customStrategy) {
      dailyMax = StrategyBuilder.buildProfile(request.customStrategy).dailyPoiTarget.max;
    } else if (request.strategyMode === 1) {
      dailyMax = 8;
    } else if (request.strategyMode === 2) {
      dailyMax = 4;
    }
    return Math.max(1, Math.floor(dailyMax)) * requestedDays;
  }

  public static resolveStrategyMaxItemsForTest(request: AiGenerateRequest): number {
    return AiService.resolveStrategyMaxItems(request);
  }

  private static enforceMaxItems(items: AiRawItem[], maxItems: number): AiRawItem[] {
    const safeMax = Number.isFinite(maxItems) ? Math.max(1, Math.floor(maxItems)) : 5;
    if (items.length <= safeMax) {
      return items;
    }
    return items.slice(0, safeMax);
  }

  public static parseItemsForTest(contentRaw: string): AiRawItem[] {
    return AiService.parseItemsFromContent(contentRaw);
  }

  public static parseModelResponseForTest(resultStr: string): AiRawItem[] {
    let resultObj = null as PanguResponse | null;
    try {
      resultObj = JSON.parse(resultStr) as PanguResponse;
    } catch (_error) {
      throw new Error('AI 顶层响应不是合法 JSON');
    }
    if (!resultObj.choices || resultObj.choices.length === 0) {
      throw new Error('AI 响应格式为空');
    }
    return AiService.parseItemsFromContent(resultObj.choices[0].message.content);
  }

  static async generateItinerary(userRequest: string): Promise<AiRawItem[]> {
    AppConfig.validateAiConfig();

    const systemPrompt = `
        你是一个专业的行程规划助手。请根据用户需求生成行程列表。
        【输出规则】
        1. 必须返回纯 JSON 数组，严禁包含 Markdown 格式。
        2. 数组对象字段：
           - "name": (String) 名称
           - "duration": (Number) 分钟数
           - "ai_reasoning": (String) 推荐理由
           - "type": (Number) 0=景点, 1=美食, 2=住宿
      `;

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AppConfig.AI_API_KEY}`
      },
      extraData: {
        model: 'DeepSeek-V3.2',
        max_tokens: 2000,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userRequest }
        ],
        stream: false
      },
      expectDataType: http.HttpDataType.STRING,
      readTimeout: 30000
    };

    try {
      const response = await AiService.doRequest(AppConfig.AI_API_URL, options);

      if (response.responseCode !== 200) {
        hilog.error(0x0000, AiService.TAG, `[AI_TRACE][generateItinerary] non-200 responseCode=${response.responseCode}`);
        throw new Error('网络请求失败');
      }

      const resultStr = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      const items = AiService.parseModelResponseForTest(resultStr);

      hilog.info(0x0000, AiService.TAG, `[AI_TRACE][generateItinerary] parse success, itemCount=${items.length}`);
      return items;
    } catch (error) {
      hilog.error(0x0000, AiService.TAG, `[AI_TRACE][generateItinerary] failed, error=${JSON.stringify(error)}`);
      const rethrowMessage = error instanceof Error ? error.message : 'AI 请求失败';
      throw new Error(rethrowMessage);
    }
  }

  static async generateItineraryWithStrategy(
    request: AiGenerateRequest
  ): Promise<AiRawItem[]> {
    AppConfig.validateAiConfig();

    const mode = request.strategyMode || 0;
    const strategyFragment = request.customStrategy
      ? StrategyService.buildComposablePrompt(request.customStrategy)
      : StrategyService.buildStrategyPrompt(mode);

    const systemPrompt = `
你是一个专业的行程规划助手。请根据用户需求生成行程列表。
${strategyFragment}
【时间合理性约束】
1. 景点(type=0)：适合8:00-20:00，避免深夜或凌晨
2. 美食(type=1)：早餐6:00-9:00，午餐11:00-14:00，晚餐17:00-21:00，避免深夜用餐
3. 住宿(type=2)：适合20:00-次日8:00
4. 按时间顺序安排，确保活动时间段合理衔接
【输出规则】
1. 必须返回纯 JSON 数组，严禁包含 Markdown 格式。
2. 数组对象字段：
   - "name": (String) 名称
   - "duration": (Number) 分钟数
   - "ai_reasoning": (String) 推荐理由
   - "type": (Number) 0=景点, 1=美食, 2=住宿
  `.trim();

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AppConfig.AI_API_KEY}`
      },
      extraData: {
        model: 'DeepSeek-V3.2',
        max_tokens: 2000,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: request.userPrompt }
        ],
        stream: false
      },
      expectDataType: http.HttpDataType.STRING,
      readTimeout: 30000
    };

    try {
      const response = await AiService.doRequest(AppConfig.AI_API_URL, options);

      if (response.responseCode !== 200) {
        throw new Error('网络请求失败');
      }

      const resultStr = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result);
      const parsedItems = AiService.parseModelResponseForTest(resultStr);
      const maxItems = AiService.resolveStrategyMaxItems(request);
      const finalItems = AiService.enforceMaxItems(parsedItems, maxItems);
      if (finalItems.length === 0) {
        throw new Error('AI 未返回可用地点，请调整描述后重试');
      }
      return finalItems;
    } catch (error) {
      const rethrowMessage = error instanceof Error ? error.message : 'AI 请求失败';
      throw new Error(rethrowMessage);
    }
  }

}
