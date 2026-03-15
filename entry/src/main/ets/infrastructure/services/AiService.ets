// 文件路径: ets/common/utils/AiService.ets
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from './AppConfig';
import { HttpRequestHelper } from './HttpRequestHelper';

export interface AiRawItem {
  name: string;
  duration: number;
  ai_reasoning: string;
  type: number;
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
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const validName = typeof item.name === 'string' && item.name.trim().length > 0;
      const validDuration = Number.isFinite(Number(item.duration)) && Number(item.duration) > 0;
      if (!validName || !validDuration) {
        throw new Error(`AI 返回项格式错误:index=${i}`);
      }
    }
    return items;
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
}
