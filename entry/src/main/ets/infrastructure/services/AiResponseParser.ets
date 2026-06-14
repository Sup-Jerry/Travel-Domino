export interface AiParserItem {
  name: string;
  duration: number;
  ai_reasoning: string;
  type: number;
}

type ItemNormalizer = (item: AiParserItem) => AiParserItem;

interface MessageContentRecord {
  role?: string;
  content?: string | Object | Object[];
}

interface ChoiceRecord {
  index?: number;
  message?: MessageContentRecord;
  finish_reason?: string;
  text?: string;
}

interface ModelResponseRecord {
  choices?: ChoiceRecord[];
}

export class AiResponseParser {
  private static readonly MAX_PARSE_DEPTH = 4;

  private static stripMarkdownFence(raw: string): string {
    const trimmed = (raw || '').trim();
    const fence = trimmed.match(/```[a-zA-Z]*\s*([\s\S]*?)```/);
    if (fence && fence.length > 1) {
      return fence[1].trim();
    }
    return trimmed.replace(/```json/gi, '').replace(/```/g, '').trim();
  }

  private static unwrapContent(raw: string): string {
    let content = (raw || '').trim();
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

  private static removeJsonTrailingCommas(raw: string): string {
    return (raw || '').replace(/,\s*([}\]])/g, '$1');
  }

  private static normalizeJsonLikeText(raw: string): string {
    let text = AiResponseParser.stripMarkdownFence(raw)
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
    return AiResponseParser.removeJsonTrailingCommas(text).trim();
  }

  private static tryParseJson(raw: string): Object | null {
    try {
      return JSON.parse(raw) as Object;
    } catch (_error) {
      return null;
    }
  }

  private static pickArrayFromObject(parsed: Object): AiParserItem[] | null {
    const record = parsed as Record<string, Object>;
    const preferredKeys: string[] = ['items', 'data', 'list', 'itinerary', 'result', '地点', '行程', '列表', '数据'];
    for (let i = 0; i < preferredKeys.length; i++) {
      const value = record[preferredKeys[i]];
      if (Array.isArray(value)) {
        return value as AiParserItem[];
      }
    }
    const keys = Object.keys(record);
    for (let i = 0; i < keys.length; i++) {
      const value = record[keys[i]];
      if (Array.isArray(value)) {
        return value as AiParserItem[];
      }
    }
    return null;
  }

  private static inferItemTypeFromText(raw: string): number {
    const text = (raw || '').toLowerCase();
    if (text.length === 0) {
      return 0;
    }
    const accommodationKeywords: string[] = ['住宿', '酒店', '宾馆', '民宿', '过夜', '留宿', 'hotel', 'accommodation'];
    const foodKeywords: string[] = ['美食', '餐', '小吃', '吃', 'dining', 'food', 'restaurant', 'lunch', 'dinner', 'breakfast'];
    for (let i = 0; i < accommodationKeywords.length; i++) {
      if (text.indexOf(accommodationKeywords[i]) >= 0) {
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

  private static tryParseItemsFromLineText(contentRaw: string): AiParserItem[] | null {
    const raw = AiResponseParser.stripMarkdownFence(contentRaw);
    if (!raw) {
      return null;
    }
    const lines = raw
      .split(/\r?\n/)
      .map((line: string) => line.trim())
      .filter((line: string) => line.length > 0);
    const items: AiParserItem[] = [];
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
        candidate = candidate.split(/[-—–]/)[0].trim();
        name = candidate;
      }
      if (!name) {
        continue;
      }
      if (type < 0 || type > 2) {
        type = AiResponseParser.inferItemTypeFromText(`${name} ${line}`);
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

  private static tryExtractItemsFromParsed(parsed: Object, depth: number = 0): AiParserItem[] | null {
    if (depth > AiResponseParser.MAX_PARSE_DEPTH || parsed === null || parsed === undefined) {
      return null;
    }
    if (Array.isArray(parsed)) {
      return parsed as AiParserItem[];
    }
    if (typeof parsed === 'string') {
      const text = (parsed as string).trim();
      if (text.length === 0) {
        return null;
      }
      const strictParsed = AiResponseParser.tryParseJson(text);
      if (strictParsed) {
        const nested = AiResponseParser.tryExtractItemsFromParsed(strictParsed, depth + 1);
        if (nested) {
          return nested;
        }
      }
      const normalized = AiResponseParser.unwrapContent(text);
      if (normalized.length > 0 && normalized !== text) {
        const normalizedParsed = AiResponseParser.tryParseJson(normalized);
        if (normalizedParsed) {
          const nested = AiResponseParser.tryExtractItemsFromParsed(normalizedParsed, depth + 1);
          if (nested) {
            return nested;
          }
        }
      }
      const lineParsed = AiResponseParser.tryParseItemsFromLineText(text);
      if (lineParsed) {
        return lineParsed;
      }
      return null;
    }
    if (typeof parsed !== 'object') {
      return null;
    }
    const fromObject = AiResponseParser.pickArrayFromObject(parsed as Object);
    if (fromObject) {
      return fromObject;
    }
    const record = parsed as Record<string, Object>;
    const preferredNestedKeys: string[] = ['content', 'text', 'message', 'result', 'output', 'data', 'itinerary', 'items', 'list'];
    for (let i = 0; i < preferredNestedKeys.length; i++) {
      const value = record[preferredNestedKeys[i]];
      if (value === undefined || value === null) {
        continue;
      }
      const nested = AiResponseParser.tryExtractItemsFromParsed(value, depth + 1);
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
      const nested = AiResponseParser.tryExtractItemsFromParsed(value, depth + 1);
      if (nested) {
        return nested;
      }
    }
    return null;
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

    const rawNoFence = AiResponseParser.stripMarkdownFence(contentRaw);
    const jsonLike = AiResponseParser.normalizeJsonLikeText(contentRaw);
    pushCandidate(normalized);
    pushCandidate(AiResponseParser.removeJsonTrailingCommas(normalized));
    pushCandidate(rawNoFence);
    pushCandidate(AiResponseParser.removeJsonTrailingCommas(rawNoFence));
    pushCandidate(jsonLike);
    pushCandidate(AiResponseParser.removeJsonTrailingCommas(jsonLike));

    const firstBracket = rawNoFence.indexOf('[');
    const lastBracket = rawNoFence.lastIndexOf(']');
    if (firstBracket >= 0 && lastBracket > firstBracket) {
      const arraySlice = rawNoFence.slice(firstBracket, lastBracket + 1);
      pushCandidate(arraySlice);
      pushCandidate(AiResponseParser.removeJsonTrailingCommas(arraySlice));
    }
    const firstBracketJsonLike = jsonLike.indexOf('[');
    const lastBracketJsonLike = jsonLike.lastIndexOf(']');
    if (firstBracketJsonLike >= 0 && lastBracketJsonLike > firstBracketJsonLike) {
      const arraySliceJsonLike = jsonLike.slice(firstBracketJsonLike, lastBracketJsonLike + 1);
      pushCandidate(arraySliceJsonLike);
      pushCandidate(AiResponseParser.removeJsonTrailingCommas(arraySliceJsonLike));
    }

    return candidates;
  }

  private static parseItemsFromContentRaw(contentRaw: string): AiParserItem[] {
    const normalized = AiResponseParser.unwrapContent(contentRaw);
    const strictParsed = AiResponseParser.tryParseJson(normalized);
    let items = null as AiParserItem[] | null;
    if (strictParsed) {
      items = AiResponseParser.tryExtractItemsFromParsed(strictParsed, 0);
    }
    if (!items) {
      const candidates = AiResponseParser.buildLooseParseCandidates(contentRaw, normalized);
      for (let i = 0; i < candidates.length; i++) {
        const parsed = AiResponseParser.tryParseJson(candidates[i]);
        if (!parsed) {
          continue;
        }
        const extracted = AiResponseParser.tryExtractItemsFromParsed(parsed, 0);
        if (extracted) {
          items = extracted;
          break;
        }
      }
    }
    if (!items) {
      const lineParsed = AiResponseParser.tryParseItemsFromLineText(contentRaw);
      if (lineParsed) {
        items = lineParsed;
      }
    }
    if (!items) {
      throw new Error('AI 返回内容不是合法 JSON');
    }
    return items;
  }

  private static normalizeAndValidateItems(items: AiParserItem[], normalize: ItemNormalizer): AiParserItem[] {
    const normalizedItems: AiParserItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const validName = typeof item.name === 'string' && item.name.trim().length > 0;
      const validDuration = Number.isFinite(Number(item.duration)) && Number(item.duration) > 0;
      if (!validName || !validDuration) {
        throw new Error(`AI 返回项格式错误:index=${i}`);
      }
      normalizedItems.push(normalize(item));
    }
    return normalizedItems;
  }

  public static parseItemsFromContent(contentRaw: string, normalize: ItemNormalizer): AiParserItem[] {
    const rawItems = AiResponseParser.parseItemsFromContentRaw(contentRaw);
    return AiResponseParser.normalizeAndValidateItems(rawItems, normalize);
  }

  public static parseModelResponseForTest(resultStr: string, normalize: ItemNormalizer): AiParserItem[] {
    let resultObj = null as ModelResponseRecord | null;
    try {
      resultObj = JSON.parse(resultStr) as ModelResponseRecord;
    } catch (_error) {
      throw new Error('AI 顶层响应不是合法 JSON');
    }
    if (!resultObj.choices || resultObj.choices.length === 0) {
      throw new Error('AI 响应格式为空');
    }
    const firstChoice = resultObj.choices[0] || {};
    let content = '';
    const message = firstChoice.message;
    if (message && typeof message === 'object') {
      const messageContent = message.content;
      if (typeof messageContent === 'string') {
        content = messageContent.trim();
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
        }
      }
    }
    if (content.length === 0 && typeof firstChoice.text === 'string') {
      content = firstChoice.text.trim();
    }
    if (content.length === 0) {
      throw new Error('AI 响应内容为空');
    }
    return AiResponseParser.parseItemsFromContent(content, normalize);
  }
}
