// 文件路径: ets/infrastructure/services/AiService.ets
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppConfig } from '../../common/utils/AppConfig';
import { PreferenceManager, AiDailyPoiRangeConfig } from '../../common/utils/PreferenceManager';
import { HttpRequestHelper } from '../adapters/HttpRequestHelper';
import { ComposableStrategy, PreferenceType } from '../../domain/strategy/TravelStrategyDimensions';
import { StrategyBuilder } from '../../domain/strategy/StrategyBuilder';
import { StrategyService } from '../../domain/strategy/StrategyService';
import { StrategyPresets } from '../../domain/strategy/StrategyPresets';
import { TravelStrategyMode } from '../../domain/strategy/TravelStrategyMode';

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
  allowPartialResult?: boolean;
}

interface AiGenerationRequirement {
  requestedDays: number;
  dailyMinItems: number;
  dailyMaxItems: number;
  totalMinItems: number;
  totalMaxItems: number;
  allowAccommodation: boolean;
}

interface DailyItemRange {
  min: number;
  max: number;
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
  private static readonly DEFAULT_READ_TIMEOUT_MS = 30000;
  private static readonly DEFAULT_MAX_TOKENS = 2000;
  private static readonly DEFAULT_REQUESTED_DAYS = 1;
  private static readonly MAX_REQUESTED_DAYS = 30;
  private static readonly RETRY_TIMES = 1;
  private static readonly RETRY_READ_TIMEOUT_MS = 60000;
  private static readonly RETRY_MAX_TOKENS = 2200;
  private static readonly MAX_TOKENS_CEILING = 3200;
  private static readonly LONG_TRIP_TOKEN_PER_DAY = 80;
  private static readonly RETRY_TOKEN_BONUS = 300;
  private static readonly MULTI_DAY_FALLBACK_DAILY_FLOOR = 2;
  private static readonly SCENIC_MIN_DURATION = 30;
  private static readonly SCENIC_MAX_DURATION = 180;
  private static readonly FOOD_MIN_DURATION = 20;
  private static readonly FOOD_MAX_DURATION = 120;
  private static readonly HOTEL_MIN_DURATION = 480;
  private static readonly HOTEL_MAX_DURATION = 720;
  private static readonly ACCOMMODATION_KEYWORDS: string[] = [
    '住宿',
    '酒店',
    '宾馆',
    '民宿',
    '过夜',
    '留宿',
    'hotel',
    'accommodation'
  ];

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

  private static stripMarkdownFence(raw: string): string {
    const trimmed = (raw || '').trim();
    const fence = trimmed.match(/```[a-zA-Z]*\s*([\s\S]*?)```/);
    if (fence && fence.length > 1) {
      return fence[1].trim();
    }
    return trimmed.replace(/```json/gi, '').replace(/```/g, '').trim();
  }

  private static removeJsonTrailingCommas(raw: string): string {
    return (raw || '').replace(/,\s*([}\]])/g, '$1');
  }

  private static toSafeString(value: Object): string {
    try {
      return JSON.stringify(value);
    } catch (_error) {
      return '';
    }
  }

  private static normalizeJsonLikeText(raw: string): string {
    let text = AiService.stripMarkdownFence(raw)
      .replace(/[“”]/g, '"')
      .replace(/[‘’]/g, '\'')
      .replace(/：/g, ':')
      .replace(/，/g, ',')
      .replace(/\r/g, '');
    text = text.replace(/([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)/g, '$1"$2"$3');
    text = text.replace(/'([^'\\]*(?:\\.[^'\\]*)*)'/g, (_m: string, group: string) => {
      const escaped = (group || '').replace(/"/g, '\\"');
      return `"${escaped}"`;
    });
    return AiService.removeJsonTrailingCommas(text).trim();
  }

  private static tryParseJson(raw: string): Object | null {
    try {
      return JSON.parse(raw) as Object;
    } catch (_error) {
      return null;
    }
  }

  private static pickArrayFromObject(parsed: Object): AiRawItem[] | null {
    const record = parsed as Record<string, Object>;
    const preferredKeys: string[] = ['items', 'data', 'list', 'itinerary', 'result', '地点', '行程', '列表', '数据'];
    for (let i = 0; i < preferredKeys.length; i++) {
      const key = preferredKeys[i];
      const value = record[key];
      if (Array.isArray(value)) {
        return value as AiRawItem[];
      }
    }
    const keys = Object.keys(record);
    for (let i = 0; i < keys.length; i++) {
      const value = record[keys[i]];
      if (Array.isArray(value)) {
        return value as AiRawItem[];
      }
    }
    return null;
  }

  private static tryExtractItemsFromParsed(parsed: Object, depth: number = 0): AiRawItem[] | null {
    if (depth > 4 || parsed === null || parsed === undefined) {
      return null;
    }
    if (Array.isArray(parsed)) {
      return parsed as AiRawItem[];
    }
    if (typeof parsed === 'string') {
      const text = (parsed as string).trim();
      if (text.length === 0) {
        return null;
      }
      const strictParsed = AiService.tryParseJson(text);
      if (strictParsed) {
        const nestedStrict = AiService.tryExtractItemsFromParsed(strictParsed, depth + 1);
        if (nestedStrict) {
          return nestedStrict;
        }
      }
      const normalized = AiService.unwrapContent(text);
      if (normalized.length > 0 && normalized !== text) {
        const normalizedParsed = AiService.tryParseJson(normalized);
        if (normalizedParsed) {
          const nestedNormalized = AiService.tryExtractItemsFromParsed(normalizedParsed, depth + 1);
          if (nestedNormalized) {
            return nestedNormalized;
          }
        }
      }
      const lineParsed = AiService.tryParseItemsFromLineText(text);
      if (lineParsed) {
        return lineParsed;
      }
      return null;
    }
    if (typeof parsed !== 'object') {
      return null;
    }
    const parsedObject = parsed as Object;
    const fromObject = AiService.pickArrayFromObject(parsedObject);
    if (fromObject) {
      return fromObject;
    }
    const record = parsedObject as Record<string, Object>;
    const preferredNestedKeys: string[] = ['content', 'text', 'message', 'result', 'output', 'data', 'itinerary', 'items', 'list'];
    for (let i = 0; i < preferredNestedKeys.length; i++) {
      const value = record[preferredNestedKeys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      const nested = AiService.tryExtractItemsFromParsed(value, depth + 1);
      if (nested) {
        return nested;
      }
    }
    const keys = Object.keys(record);
    for (let i = 0; i < keys.length; i++) {
      const value = record[keys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      const nested = AiService.tryExtractItemsFromParsed(value, depth + 1);
      if (nested) {
        return nested;
      }
    }
    return null;
  }

  private static tryParseArrayCandidate(raw: string): AiRawItem[] | null {
    const parsed = AiService.tryParseJson(raw);
    if (!parsed) {
      return null;
    }
    return AiService.tryExtractItemsFromParsed(parsed, 0);
  }

  private static buildLooseParseCandidates(contentRaw: string, normalized: string): string[] {
    const candidates: string[] = [];
    const seen: Set<string> = new Set<string>();
    const pushCandidate = (value: string) => {
      const trimmed = (value || '').trim();
      if (trimmed.length === 0 || seen.has(trimmed)) {
        return;
      }
      seen.add(trimmed);
      candidates.push(trimmed);
    };

    const rawNoFence = AiService.stripMarkdownFence(contentRaw);
    const jsonLike = AiService.normalizeJsonLikeText(contentRaw);
    pushCandidate(normalized);
    pushCandidate(AiService.removeJsonTrailingCommas(normalized));
    pushCandidate(rawNoFence);
    pushCandidate(AiService.removeJsonTrailingCommas(rawNoFence));
    pushCandidate(jsonLike);
    pushCandidate(AiService.removeJsonTrailingCommas(jsonLike));

    const firstBracket = rawNoFence.indexOf('[');
    const lastBracket = rawNoFence.lastIndexOf(']');
    if (firstBracket >= 0 && lastBracket > firstBracket) {
      const arraySlice = rawNoFence.slice(firstBracket, lastBracket + 1);
      pushCandidate(arraySlice);
      pushCandidate(AiService.removeJsonTrailingCommas(arraySlice));
    }
    const firstBracketJsonLike = jsonLike.indexOf('[');
    const lastBracketJsonLike = jsonLike.lastIndexOf(']');
    if (firstBracketJsonLike >= 0 && lastBracketJsonLike > firstBracketJsonLike) {
      const arraySliceJsonLike = jsonLike.slice(firstBracketJsonLike, lastBracketJsonLike + 1);
      pushCandidate(arraySliceJsonLike);
      pushCandidate(AiService.removeJsonTrailingCommas(arraySliceJsonLike));
    }

    return candidates;
  }

  private static inferItemTypeFromText(raw: string): number {
    const text = (raw || '').toLowerCase();
    if (text.length === 0) {
      return 0;
    }
    const foodKeywords: string[] = ['美食', '餐', '小吃', '吃', 'dining', 'food', 'restaurant', 'lunch', 'dinner', 'breakfast'];
    for (let i = 0; i < AiService.ACCOMMODATION_KEYWORDS.length; i++) {
      if (text.indexOf(AiService.ACCOMMODATION_KEYWORDS[i]) >= 0) {
        return 2;
      }
    }
    for (let i = 0; i < foodKeywords.length; i++) {
      if (text.indexOf(foodKeywords[i]) >= 0) {
        return 1;
      }
    }
    return 0;
  }

  private static tryParseItemsFromLineText(contentRaw: string): AiRawItem[] | null {
    const raw = AiService.stripMarkdownFence(contentRaw);
    if (!raw) {
      return null;
    }
    const lines = raw
      .split(/\r?\n/)
      .map((line: string) => line.trim())
      .filter((line: string) => line.length > 0);
    const items: AiRawItem[] = [];
    for (let i = 0; i < lines.length; i++) {
      let line = lines[i].replace(/^[\-\*\d\.\)\(、\s]+/, '').trim();
      if (line.length === 0) {
        continue;
      }
      const durationMatch = line.match(/(?:duration|时长)\s*[:：=]?\s*(\d{1,4})\s*(?:分钟|min|mins|m)?/i)
        || line.match(/(\d{1,4})\s*(?:分钟|min|mins|m)/i);
      if (!durationMatch || !durationMatch[1]) {
        continue;
      }
      const duration = Number(durationMatch[1]);
      if (!Number.isFinite(duration) || duration <= 0) {
        continue;
      }

      const typeMatch = line.match(/(?:type|类型)\s*[:：=]?\s*([012])/i);
      let type = typeMatch && typeMatch[1] ? Number(typeMatch[1]) : -1;

      const reasonMatch = line.match(/(?:ai_reasoning|reason|推荐理由|理由)\s*[:：]\s*(.+)$/i);
      const reason = reasonMatch && reasonMatch[1] ? reasonMatch[1].trim() : 'AI 智能推荐';

      const nameMatch = line.match(/(?:name|名称)\s*[:：]\s*["“]?([^"”,\|;；]+)["”]?/i);
      let name = nameMatch && nameMatch[1] ? nameMatch[1].trim() : '';
      if (!name) {
        let candidate = line
          .replace(/(?:name|名称)\s*[:：]\s*/ig, '')
          .replace(/(?:duration|时长)\s*[:：=]?\s*\d{1,4}\s*(?:分钟|min|mins|m)?/ig, '')
          .replace(/(?:type|类型)\s*[:：=]?\s*[012]/ig, '')
          .replace(/(?:ai_reasoning|reason|推荐理由|理由)\s*[:：].*$/ig, '')
          .replace(/[|,，;；]+/g, ' ')
          .trim();
        const splitByDash = candidate.split(/[-—–]/);
        if (splitByDash.length > 0) {
          candidate = splitByDash[0].trim();
        }
        name = candidate;
      }
      if (!name) {
        continue;
      }
      if (type < 0 || type > 2) {
        type = AiService.inferItemTypeFromText(`${name} ${line}`);
      }
      items.push({
        name: name,
        duration: duration,
        ai_reasoning: reason,
        type: type
      });
    }
    return items.length > 0 ? items : null;
  }

  private static buildParsePreview(raw: string): string {
    const compact = AiService.stripMarkdownFence(raw || '').replace(/\s+/g, ' ').trim();
    if (compact.length <= 120) {
      return compact;
    }
    return compact.slice(0, 120);
  }

  private static parseItemsFromContent(contentRaw: string): AiRawItem[] {
    const normalized = AiService.unwrapContent(contentRaw);
    const strictParsed = AiService.tryParseJson(normalized);
    let items = null as AiRawItem[] | null;
    if (strictParsed) {
      items = AiService.tryExtractItemsFromParsed(strictParsed, 0);
    }

    if (!items) {
      const candidates = AiService.buildLooseParseCandidates(contentRaw, normalized);
      for (let i = 0; i < candidates.length; i++) {
        const parsedItems = AiService.tryParseArrayCandidate(candidates[i]);
        if (parsedItems) {
          items = parsedItems;
          hilog.warn(
            0x0000,
            AiService.TAG,
            `[airest]AI_REPLAN_TRACE[ai_parse_loose_json_success] candidate=${i}, len=${candidates[i].length}`
          );
          break;
        }
      }
    }

    if (!items) {
      const lineParsedItems = AiService.tryParseItemsFromLineText(contentRaw);
      if (lineParsedItems) {
        items = lineParsedItems;
        hilog.warn(
          0x0000,
          AiService.TAG,
          `[airest]AI_REPLAN_TRACE[ai_parse_line_fallback_success] count=${items.length}`
        );
      }
    }

    if (!items) {
      hilog.error(
        0x0000,
        AiService.TAG,
        `[airest]AI_REPLAN_TRACE[ai_parse_fail] rawLen=${(contentRaw || '').length}, normalizedLen=${normalized.length}, preview=${AiService.buildParsePreview(contentRaw)}`
      );
      throw new Error('AI 返回内容不是合法 JSON');
    }

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

  private static buildDailyItemRange(min: number, max: number): DailyItemRange {
    const range: DailyItemRange = {
      min: min,
      max: max
    };
    return range;
  }

  private static resolveDailyItemRange(request: AiGenerateRequest): DailyItemRange {
    if (request.customStrategy) {
      const target = StrategyBuilder.buildProfile(request.customStrategy).dailyPoiTarget;
      return AiService.buildDailyItemRange(
        Math.max(1, Math.floor(target.min)),
        Math.max(1, Math.floor(target.max))
      );
    }
    const mode = request.strategyMode === 1
      ? TravelStrategyMode.SOLDIER
      : (request.strategyMode === 2 ? TravelStrategyMode.LEISURE : TravelStrategyMode.DEFAULT);
    const preset = StrategyPresets.getProfile(mode);
    return AiService.buildDailyItemRange(
      Math.max(1, Math.floor(preset.dailyPoiTarget.min)),
      Math.max(1, Math.floor(preset.dailyPoiTarget.max))
    );
  }

  private static resolveDailyItemRangeByConfiguredPreset(mode: number, config: AiDailyPoiRangeConfig): DailyItemRange {
    if (mode === 1) {
      return AiService.buildDailyItemRange(config.soldierMin, config.soldierMax);
    }
    if (mode === 2) {
      return AiService.buildDailyItemRange(config.leisureMin, config.leisureMax);
    }
    return AiService.buildDailyItemRange(config.defaultMin, config.defaultMax);
  }

  private static async resolveDailyItemRangeRuntime(request: AiGenerateRequest): Promise<DailyItemRange> {
    if (request.customStrategy) {
      const customRange = AiService.resolveDailyItemRange(request);
      hilog.info(
        0x0000,
        AiService.TAG,
        `[AI_DEBUG][strategy_range_runtime] mode=${request.strategyMode || 0}, source=custom, dailyMin=${customRange.min}, dailyMax=${customRange.max}`
      );
      return customRange;
    }
    try {
      const config = await PreferenceManager.getInstance().getAiDailyPoiRangeConfig();
      const runtimeRange = AiService.resolveDailyItemRangeByConfiguredPreset(request.strategyMode || 0, config);
      hilog.info(
        0x0000,
        AiService.TAG,
        `[AI_DEBUG][strategy_range_runtime] mode=${request.strategyMode || 0}, source=preferences, dailyMin=${runtimeRange.min}, dailyMax=${runtimeRange.max}`
      );
      return runtimeRange;
    } catch (error) {
      const fallbackRange = AiService.resolveDailyItemRange(request);
      hilog.warn(
        0x0000,
        AiService.TAG,
        `[AI_DEBUG][strategy_range_runtime] mode=${request.strategyMode || 0}, source=preset_fallback, dailyMin=${fallbackRange.min}, dailyMax=${fallbackRange.max}, reason=${error instanceof Error ? error.message : JSON.stringify(error)}`
      );
      return fallbackRange;
    }
  }

  private static resolveStrategyMinItems(request: AiGenerateRequest): number {
    const requestedDays = AiService.resolveRequestedDaysFromPrompt(request.userPrompt);
    const dailyRange = AiService.resolveDailyItemRange(request);
    return Math.max(1, Math.floor(dailyRange.min)) * requestedDays;
  }

  private static resolveStrategyMaxItems(request: AiGenerateRequest): number {
    const requestedDays = AiService.resolveRequestedDaysFromPrompt(request.userPrompt);
    const dailyRange = AiService.resolveDailyItemRange(request);
    return Math.max(1, Math.floor(dailyRange.max)) * requestedDays;
  }

  public static resolveStrategyMaxItemsForTest(request: AiGenerateRequest): number {
    return AiService.resolveStrategyMaxItems(request);
  }

  public static resolveStrategyMinItemsForTest(request: AiGenerateRequest): number {
    return AiService.resolveStrategyMinItems(request);
  }

  private static shouldAllowAccommodation(prompt: string): boolean {
    const normalized = (prompt || '').toLowerCase().replace(/\s+/g, '');
    return AiService.ACCOMMODATION_KEYWORDS.some((keyword: string) => normalized.indexOf(keyword) >= 0);
  }

  private static resolveGenerationRequirement(request: AiGenerateRequest): AiGenerationRequirement {
    const requestedDays = AiService.resolveRequestedDaysFromPrompt(request.userPrompt);
    const dailyRange = AiService.resolveDailyItemRange(request);
    const dailyMinItems = Math.max(1, Math.floor(dailyRange.min));
    const dailyMaxItems = Math.max(dailyMinItems, Math.floor(dailyRange.max));
    return {
      requestedDays: requestedDays,
      dailyMinItems: dailyMinItems,
      dailyMaxItems: dailyMaxItems,
      totalMinItems: dailyMinItems * requestedDays,
      totalMaxItems: dailyMaxItems * requestedDays,
      allowAccommodation: AiService.shouldAllowAccommodation(request.userPrompt)
    };
  }

  private static async resolveGenerationRequirementRuntime(request: AiGenerateRequest): Promise<AiGenerationRequirement> {
    const requestedDays = AiService.resolveRequestedDaysFromPrompt(request.userPrompt);
    const dailyRange = await AiService.resolveDailyItemRangeRuntime(request);
    const dailyMinItems = Math.max(1, Math.floor(dailyRange.min));
    const dailyMaxItems = Math.max(dailyMinItems, Math.floor(dailyRange.max));
    return {
      requestedDays: requestedDays,
      dailyMinItems: dailyMinItems,
      dailyMaxItems: dailyMaxItems,
      totalMinItems: dailyMinItems * requestedDays,
      totalMaxItems: dailyMaxItems * requestedDays,
      allowAccommodation: AiService.shouldAllowAccommodation(request.userPrompt)
    };
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
    const firstChoice = resultObj.choices[0];
    const finishReason = firstChoice && typeof firstChoice.finish_reason === 'string'
      ? firstChoice.finish_reason
      : '';
    const choiceRecord = firstChoice as Object as Record<string, Object>;
    let content = '';
    const message = choiceRecord['message'];
    if (message && typeof message === 'object') {
      const messageRecord = message as Record<string, Object>;
      const messageContent = messageRecord['content'];
      if (typeof messageContent === 'string') {
        content = messageContent as string;
      } else if (Array.isArray(messageContent)) {
        const fragments: string[] = [];
        const segments = messageContent as Object[];
        for (let i = 0; i < segments.length; i++) {
          const segment = segments[i];
          if (typeof segment === 'string') {
            fragments.push((segment as string).trim());
            continue;
          }
          if (segment && typeof segment === 'object') {
            const segmentRecord = segment as Record<string, Object>;
            const text = segmentRecord['text'];
            if (typeof text === 'string' && (text as string).trim().length > 0) {
              fragments.push((text as string).trim());
              continue;
            }
            const nestedText = segmentRecord['content'];
            if (typeof nestedText === 'string' && (nestedText as string).trim().length > 0) {
              fragments.push((nestedText as string).trim());
            }
          }
        }
        content = fragments.join('\n').trim();
      } else if (messageContent && typeof messageContent === 'object') {
        const contentRecord = messageContent as Record<string, Object>;
        const text = contentRecord['text'];
        if (typeof text === 'string') {
          content = (text as string).trim();
        } else {
          content = AiService.toSafeString(messageContent).trim();
        }
      }
    }
    if (content.length === 0) {
      const choiceText = choiceRecord['text'];
      if (typeof choiceText === 'string') {
        content = (choiceText as string).trim();
      }
    }
    hilog.info(
      0x0000,
      AiService.TAG,
      `[airest]AI_REPLAN_TRACE[ai_response_meta] finishReason=${finishReason || 'none'}, contentLen=${content.length}`
    );
    if (content.length === 0) {
      throw new Error('AI 响应内容为空');
    }
    try {
      return AiService.parseItemsFromContent(content);
    } catch (error) {
      const reason = error instanceof Error ? error.message : JSON.stringify(error);
      hilog.error(
        0x0000,
        AiService.TAG,
        `[airest]AI_REPLAN_TRACE[ai_response_parse_fail] finishReason=${finishReason || 'none'}, reason=${reason}, preview=${AiService.buildParsePreview(content)}`
      );
      if (error instanceof Error) {
        throw error;
      }
      throw new Error(reason);
    }
  }

  private static dedupeItemsByName(items: AiRawItem[]): AiRawItem[] {
    const usedKeys: Set<string> = new Set<string>();
    const deduped: AiRawItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const key = item.name.trim().toLowerCase();
      if (key.length === 0 || usedKeys.has(key)) {
        continue;
      }
      usedKeys.add(key);
      deduped.push(item);
    }
    return deduped;
  }

  private static sanitizeItemsByRequirement(
    items: AiRawItem[],
    requirement: AiGenerationRequirement
  ): AiRawItem[] {
    let normalized = AiService.dedupeItemsByName(items);

    if (!requirement.allowAccommodation) {
      normalized = normalized.filter((item: AiRawItem) => item.type !== 2);
    } else {
      const capped: AiRawItem[] = [];
      let hotelCount = 0;
      for (let i = 0; i < normalized.length; i++) {
        const item = normalized[i];
        if (item.type === 2) {
          if (hotelCount >= requirement.requestedDays) {
            continue;
          }
          hotelCount += 1;
        }
        capped.push(item);
      }
      normalized = capped;
    }

    return AiService.enforceMaxItems(normalized, requirement.totalMaxItems);
  }

  private static isSufficientForRequirement(
    items: AiRawItem[],
    requirement: AiGenerationRequirement
  ): boolean {
    if (!items || items.length === 0) {
      return false;
    }

    const total = items.length;
    if (total < requirement.totalMinItems) {
      return false;
    }

    if (!requirement.allowAccommodation && items.some((item: AiRawItem) => item.type === 2)) {
      return false;
    }

    const nonHotelCount = items.filter((item: AiRawItem) => item.type !== 2).length;
    if (nonHotelCount < requirement.requestedDays) {
      return false;
    }

    if (requirement.allowAccommodation) {
      const hotelCount = items.filter((item: AiRawItem) => item.type === 2).length;
      if (hotelCount > requirement.requestedDays) {
        return false;
      }
    }
    return true;
  }

  private static isFallbackAcceptableForMultiDay(
    items: AiRawItem[],
    requirement: AiGenerationRequirement
  ): boolean {
    if (requirement.requestedDays <= 1 || !items || items.length === 0) {
      return false;
    }

    const fallbackDailyMin = Math.max(
      AiService.MULTI_DAY_FALLBACK_DAILY_FLOOR,
      requirement.dailyMinItems - 1
    );
    const minTotalItems = requirement.requestedDays * fallbackDailyMin;
    if (items.length < minTotalItems) {
      return false;
    }

    if (!requirement.allowAccommodation && items.some((item: AiRawItem) => item.type === 2)) {
      return false;
    }

    const nonHotelCount = items.filter((item: AiRawItem) => item.type !== 2).length;
    if (nonHotelCount < requirement.requestedDays) {
      return false;
    }

    if (requirement.allowAccommodation) {
      const hotelCount = items.filter((item: AiRawItem) => item.type === 2).length;
      if (hotelCount > requirement.requestedDays) {
        return false;
      }
    }

    return true;
  }

  private static isBestEffortAcceptableForLongTrip(
    items: AiRawItem[],
    requirement: AiGenerationRequirement
  ): boolean {
    if (requirement.requestedDays < 10 || !items || items.length === 0) {
      return false;
    }

    if (!requirement.allowAccommodation && items.some((item: AiRawItem) => item.type === 2)) {
      return false;
    }

    const nonHotelCount = items.filter((item: AiRawItem) => item.type !== 2).length;
    const minAcceptable = Math.max(6, Math.ceil(requirement.requestedDays * 0.4));
    return nonHotelCount >= minAcceptable;
  }

  private static isTimeoutLikeError(error: Object): boolean {
    if (!(error instanceof Error)) {
      return false;
    }
    const message = (error.message || '').toLowerCase();
    return message.indexOf('timeout') >= 0 ||
      message.indexOf('2300028') >= 0 ||
      message.indexOf('ai_upstream_timeout') >= 0;
  }

  private static resolveNon200ErrorMessage(response: HttpResponseLike): string {
    const status = Number(response.responseCode || 0);
    const raw = typeof response.result === 'string'
      ? response.result
      : JSON.stringify(response.result);
    const normalized = (raw || '').trim();
    let backendMessage = '';
    if (normalized.length > 0) {
      const parsed = AiService.tryParseJson(normalized);
      if (parsed && typeof parsed === 'object') {
        const record = parsed as Record<string, Object>;
        const messageValue = record['message'];
        if (typeof messageValue === 'string' && (messageValue as string).trim().length > 0) {
          backendMessage = (messageValue as string).trim();
        }
      }
    }
    const upperMessage = backendMessage.toUpperCase();
    if (status === 429 || upperMessage.indexOf('AI_DEEPSEEK_RATE_LIMIT') >= 0) {
      return 'AI 服务请求过于频繁，请稍后重试';
    }
    if (status === 401 || upperMessage.indexOf('AI_DEEPSEEK_AUTH_FAILED') >= 0) {
      return 'AI 服务鉴权失败，请联系管理员检查后端 AI KEY';
    }
    if (status === 402 || upperMessage.indexOf('AI_DEEPSEEK_INSUFFICIENT_BALANCE') >= 0) {
      return 'AI 账户余额不足，请充值后重试';
    }
    if (status === 400 || status === 422 ||
      upperMessage.indexOf('AI_DEEPSEEK_BAD_REQUEST') >= 0 ||
      upperMessage.indexOf('AI_DEEPSEEK_INVALID_PARAMETERS') >= 0) {
      return 'AI 请求参数异常，请调整输入后重试';
    }
    if (status === 500 || status === 503 ||
      upperMessage.indexOf('AI_DEEPSEEK_SERVER_ERROR') >= 0 ||
      upperMessage.indexOf('AI_DEEPSEEK_SERVER_BUSY') >= 0) {
      return 'AI 服务暂时不可用，请稍后重试';
    }
    if (upperMessage.indexOf('AI_UPSTREAM_TIMEOUT') >= 0) {
      return 'AI 服务响应超时，请稍后重试';
    }
    if (status >= 500) {
      return 'AI 服务暂时不可用，请稍后重试';
    }
    return '网络请求失败';
  }

  private static getInsufficientReason(
    items: AiRawItem[],
    requirement: AiGenerationRequirement
  ): string {
    if (!items || items.length === 0) {
      return 'empty_items';
    }
    if (items.length < requirement.totalMinItems) {
      return `insufficient_total_${items.length}_lt_${requirement.totalMinItems}`;
    }
    if (!requirement.allowAccommodation && items.some((item: AiRawItem) => item.type === 2)) {
      return 'unexpected_accommodation';
    }
    const nonHotelCount = items.filter((item: AiRawItem) => item.type !== 2).length;
    if (nonHotelCount < requirement.requestedDays) {
      return `insufficient_non_hotel_${nonHotelCount}_lt_${requirement.requestedDays}`;
    }
    if (requirement.allowAccommodation) {
      const hotelCount = items.filter((item: AiRawItem) => item.type === 2).length;
      if (hotelCount > requirement.requestedDays) {
        return `too_many_hotels_${hotelCount}_gt_${requirement.requestedDays}`;
      }
    }
    return 'unknown';
  }

  private static buildMultiDayConstraintPrompt(requirement: AiGenerationRequirement): string {
    if (requirement.requestedDays <= 1) {
      return '';
    }
    const accommodationRule = requirement.allowAccommodation
      ? `住宿(type=2)最多 ${requirement.requestedDays} 个，且每天最多 1 个。`
      : '用户未明确要求住宿，禁止输出 type=2。';
    return `
【多天刚性约束】
1. 必须覆盖 ${requirement.requestedDays} 天，按天连续规划。
2. 每天至少 ${requirement.dailyMinItems} 个地点，总地点数必须在 ${requirement.totalMinItems}-${requirement.totalMaxItems} 之间。
3. 严禁通过拉长少量地点停留时间来凑天数，必须给出真实且不同的地点。
4. 多天结果请按日期先后排序输出。
5. ${accommodationRule}
`.trim();
  }

  private static buildDailyRangeConstraintPrompt(requirement: AiGenerationRequirement): string {
    return `【地点数量约束】每天应安排 ${requirement.dailyMinItems}-${requirement.dailyMaxItems} 个地点。`;
  }

  private static buildRetryPrompt(baseUserPrompt: string, requirement: AiGenerationRequirement): string {
    if (requirement.requestedDays <= 1) {
      return baseUserPrompt;
    }
    const accommodationRule = requirement.allowAccommodation
      ? `住宿(type=2)最多 ${requirement.requestedDays} 个，且每天最多 1 个。`
      : '不要输出住宿(type=2)。';
    return `${baseUserPrompt}
【补充硬约束】
- 严格返回 ${requirement.totalMinItems}-${requirement.totalMaxItems} 个不同地点
- 覆盖 ${requirement.requestedDays} 天且每天至少 ${requirement.dailyMinItems} 个地点
- 严禁用少量地点+超长停留时间来凑多天
- ${accommodationRule}`.trim();
  }

  private static resolveMaxTokensForAttempt(requirement: AiGenerationRequirement, retry: number): number {
    const dayExtra = Math.max(0, requirement.requestedDays - 3) * AiService.LONG_TRIP_TOKEN_PER_DAY;
    const retryBonus = retry > 0 ? AiService.RETRY_TOKEN_BONUS : 0;
    const base = retry > 0 ? AiService.RETRY_MAX_TOKENS : AiService.DEFAULT_MAX_TOKENS;
    const budget = base + dayExtra + retryBonus;
    return Math.min(
      AiService.MAX_TOKENS_CEILING,
      Math.max(AiService.DEFAULT_MAX_TOKENS, Math.floor(budget))
    );
  }

  private static async requestItineraryItems(
    systemPrompt: string,
    userPrompt: string,
    readTimeoutMs: number = AiService.DEFAULT_READ_TIMEOUT_MS,
    maxTokens: number = AiService.DEFAULT_MAX_TOKENS
  ): Promise<AiRawItem[]> {
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: {
        model: 'deepseek-chat',
        max_tokens: maxTokens,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt }
        ],
        response_format: { type: 'json_object' },
        stream: false
      },
      expectDataType: http.HttpDataType.STRING,
      readTimeout: readTimeoutMs
    };

    const response = await AiService.doRequest(AppConfig.AI_API_URL, options);
    if (response.responseCode !== 200) {
      throw new Error(AiService.resolveNon200ErrorMessage(response));
    }
    const resultStr = typeof response.result === 'string'
      ? response.result
      : JSON.stringify(response.result);
    return AiService.parseModelResponseForTest(resultStr);
  }

  static async generateItinerary(userRequest: string): Promise<AiRawItem[]> {
    AppConfig.validateAiConfig();

    const systemPrompt = `
        你是一个专业的行程规划助手。请根据用户需求生成行程列表。
        【输出规则】
        1. 必须返回纯 json 数组，严禁包含 Markdown 格式。
        2. 数组对象字段：
           - "name": (String) 名称
           - "duration": (Number) 分钟数
           - "ai_reasoning": (String) 推荐理由
           - "type": (Number) 0=景点, 1=美食, 2=住宿
      `;

    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: {
        model: 'deepseek-chat',
        max_tokens: 2000,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userRequest }
        ],
        response_format: { type: 'json_object' },
        stream: false
      },
      expectDataType: http.HttpDataType.STRING,
      readTimeout: AiService.DEFAULT_READ_TIMEOUT_MS
    };

    try {
      const response = await AiService.doRequest(AppConfig.AI_API_URL, options);

      if (response.responseCode !== 200) {
        hilog.error(0x0000, AiService.TAG, `[AI_TRACE][generateItinerary] non-200 responseCode=${response.responseCode}`);
        throw new Error(AiService.resolveNon200ErrorMessage(response));
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
    const allowPartialResult = request.allowPartialResult === true;
    const strategyFragment = request.customStrategy
      ? StrategyService.buildComposablePrompt(request.customStrategy)
      : StrategyService.buildStrategyPrompt(mode);
    const requirement = await AiService.resolveGenerationRequirementRuntime(request);
    hilog.info(
      0x0000,
      AiService.TAG,
      `[AI_DEBUG][strategy_req] mode=${mode}, custom=${request.customStrategy ? 1 : 0}, promptLen=${request.userPrompt.length}, days=${requirement.requestedDays}, dailyMin=${requirement.dailyMinItems}, dailyMax=${requirement.dailyMaxItems}, totalMin=${requirement.totalMinItems}, totalMax=${requirement.totalMaxItems}, allowHotel=${requirement.allowAccommodation ? 1 : 0}`
    );
    const multiDayConstraintPrompt = AiService.buildMultiDayConstraintPrompt(requirement);
    const dailyRangeConstraintPrompt = AiService.buildDailyRangeConstraintPrompt(requirement);

    const systemPrompt = `
你是一个专业的行程规划助手。请根据用户需求生成行程列表。
${strategyFragment}
${dailyRangeConstraintPrompt}
${multiDayConstraintPrompt}
【时间合理性约束】
1. 景点(type=0)：适合8:00-20:00，避免深夜或凌晨
2. 美食(type=1)：早餐6:00-9:00，午餐11:00-14:00，晚餐17:00-21:00，避免深夜用餐
3. 住宿(type=2)：仅当用户明确提到住宿/酒店时可输出，且适合20:00-次日8:00
4. 按时间顺序安排，确保活动时间段合理衔接
【输出规则】
1. 必须返回纯 json 数组，严禁包含 Markdown 格式。
2. 数组对象字段：
   - "name": (String) 名称
   - "duration": (Number) 分钟数
   - "ai_reasoning": (String) 推荐理由
   - "type": (Number) 0=景点, 1=美食, 2=住宿
  `.trim();

    try {
      let finalItems: AiRawItem[] = [];
      let bestEffortItems: AiRawItem[] = [];
      let currentPrompt = request.userPrompt;

      for (let retry = 0; retry <= AiService.RETRY_TIMES; retry++) {
        let parsedItems: AiRawItem[] = [];
        const readTimeout = retry > 0 ? AiService.RETRY_READ_TIMEOUT_MS : AiService.DEFAULT_READ_TIMEOUT_MS;
        const maxTokens = AiService.resolveMaxTokensForAttempt(requirement, retry);
        const attemptStartedAt = Date.now();
        hilog.info(
          0x0000,
          AiService.TAG,
          `[AI_DEBUG][strategy_attempt_begin] mode=${mode}, retry=${retry}, readTimeoutMs=${readTimeout}, maxTokens=${maxTokens}, promptLen=${currentPrompt.length}`
        );
        try {
          parsedItems = await AiService.requestItineraryItems(systemPrompt, currentPrompt, readTimeout, maxTokens);
          hilog.info(
            0x0000,
            AiService.TAG,
            `[AI_DEBUG][strategy_attempt_request_ok] mode=${mode}, retry=${retry}, elapsedMs=${Date.now() - attemptStartedAt}, rawCount=${parsedItems.length}`
          );
        } catch (error) {
          const elapsedMs = Date.now() - attemptStartedAt;
          const timeoutLike = AiService.isTimeoutLikeError(error as Object);
          const canUseFallback = retry > 0 &&
            bestEffortItems.length > 0 &&
            timeoutLike &&
            AiService.isFallbackAcceptableForMultiDay(bestEffortItems, requirement);
          hilog.error(
            0x0000,
            AiService.TAG,
            `[AI_DEBUG][strategy_attempt_error] mode=${mode}, retry=${retry}, elapsedMs=${elapsedMs}, timeoutLike=${timeoutLike ? 1 : 0}, reason=${error instanceof Error ? error.message : JSON.stringify(error)}, canFallback=${canUseFallback ? 1 : 0}, bestEffortCount=${bestEffortItems.length}`
          );
          if (canUseFallback) {
            finalItems = bestEffortItems;
            hilog.warn(
              0x0000,
              AiService.TAG,
              `[AI_DEBUG][strategy_retry_fallback] mode=${mode}, retry=${retry}, finalCount=${finalItems.length}`
            );
            break;
          }
          if (retry < AiService.RETRY_TIMES) {
            if (timeoutLike) {
              // timeout 场景下不叠加更复杂约束，避免模型负担继续升高
              currentPrompt = request.userPrompt;
              hilog.warn(
                0x0000,
                AiService.TAG,
                `[AI_DEBUG][strategy_retry_after_timeout] mode=${mode}, retry=${retry}, nextRetry=${retry + 1}`
              );
            } else {
              currentPrompt = AiService.buildRetryPrompt(request.userPrompt, requirement);
              hilog.warn(
                0x0000,
                AiService.TAG,
                `[AI_DEBUG][strategy_retry_after_error] mode=${mode}, retry=${retry}, nextRetry=${retry + 1}`
              );
            }
            continue;
          }
          const retryError = error instanceof Error ? error.message : JSON.stringify(error);
          throw new Error(retryError);
        }

        finalItems = AiService.sanitizeItemsByRequirement(parsedItems, requirement);
        if (bestEffortItems.length === 0 || finalItems.length > bestEffortItems.length) {
          bestEffortItems = finalItems;
        }
        const enough = AiService.isSufficientForRequirement(finalItems, requirement);
        const reason = enough ? 'ok' : AiService.getInsufficientReason(finalItems, requirement);
        hilog.info(
          0x0000,
          AiService.TAG,
          `[AI_DEBUG][strategy_attempt] mode=${mode}, retry=${retry}, parsedCount=${parsedItems.length}, sanitizedCount=${finalItems.length}, enough=${enough ? 1 : 0}, reason=${reason}`
        );
        if (enough) {
          break;
        }
        if (retry < AiService.RETRY_TIMES) {
          currentPrompt = AiService.buildRetryPrompt(request.userPrompt, requirement);
          hilog.warn(
            0x0000,
            AiService.TAG,
            `[AI_DEBUG][strategy_retry_after_insufficient] mode=${mode}, retry=${retry}, nextRetry=${retry + 1}, reason=${reason}`
          );
        }
      }

      if (finalItems.length === 0) {
        hilog.error(0x0000, AiService.TAG, `[AI_DEBUG][strategy_fail] mode=${mode}, reason=empty_items`);
        throw new Error('AI 未返回可用地点，请调整描述后重试');
      }
      if (!AiService.isSufficientForRequirement(finalItems, requirement)) {
        const reason = AiService.getInsufficientReason(finalItems, requirement);
        hilog.error(
          0x0000,
          AiService.TAG,
          `[AI_DEBUG][strategy_fail] mode=${mode}, allowPartial=${allowPartialResult ? 1 : 0}, reason=${reason}, finalCount=${finalItems.length}`
        );
        if (allowPartialResult && finalItems.length > 0) {
          hilog.warn(
            0x0000,
            AiService.TAG,
            `[AI_DEBUG][strategy_soft_accept_partial] mode=${mode}, reason=${reason}, finalCount=${finalItems.length}, requestedDays=${requirement.requestedDays}`
          );
          return finalItems;
        }
        if (AiService.isFallbackAcceptableForMultiDay(finalItems, requirement)) {
          hilog.warn(
            0x0000,
            AiService.TAG,
            `[AI_DEBUG][strategy_soft_accept] mode=${mode}, reason=${reason}, finalCount=${finalItems.length}`
          );
          return finalItems;
        }
        if (AiService.isBestEffortAcceptableForLongTrip(finalItems, requirement)) {
          hilog.warn(
            0x0000,
            AiService.TAG,
            `[AI_DEBUG][strategy_soft_accept_long_trip] mode=${mode}, reason=${reason}, finalCount=${finalItems.length}, requestedDays=${requirement.requestedDays}`
          );
          return finalItems;
        }
        if (requirement.requestedDays > 1) {
          throw new Error(`AI 返回地点数量不足，无法满足${requirement.requestedDays}天行程，请补充更多偏好后重试`);
        }
        throw new Error('AI 未返回可用地点，请调整描述后重试');
      }
      return finalItems;
    } catch (error) {
      const rethrowMessage = error instanceof Error ? error.message : 'AI 请求失败';
      if (AiService.isTimeoutLikeError(error as Object)) {
        throw new Error('AI 服务响应超时，请稍后重试');
      }
      throw new Error(rethrowMessage);
    }
  }

}
