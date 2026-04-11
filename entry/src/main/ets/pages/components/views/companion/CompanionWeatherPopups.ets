export function getCompanionPopupLine(lines: string[], index: number): string {
  if (index < 0 || index >= lines.length) {
    return '';
  }
  const value = lines[index];
  return value ? value : '';
}

export function getCompanionPopupHeight(kind: string): number {
  return kind === 'suggestion' ? 240 : 230;
}

export function getCompanionPopupWidth(kind: string): number {
  return kind === 'suggestion' ? 290 : 280;
}

@Builder
export function CompanionWeatherScorePopupBuilder(lines: string[]) {
  Scroll() {
    Column({ space: 2 }) {
      Text(getCompanionPopupLine(lines, 0))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1565C0')
        .fontWeight(FontWeight.Bold)
      Text(getCompanionPopupLine(lines, 1))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#2E7D32')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 2))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#6A1B9A')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 3))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#455A64')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 4))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#EF6C00')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 5))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1B5E20')
        .fontWeight(FontWeight.Medium)
    }
    .padding(10)
    .width('100%');
  }
  .height(getCompanionPopupHeight('score'))
  .width(getCompanionPopupWidth('score'));
}

@Builder
export function CompanionWeatherHintPopupBuilder(lines: string[]) {
  Scroll() {
    Column({ space: 2 }) {
      Text(getCompanionPopupLine(lines, 0))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1565C0')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 1))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#2E7D32')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 2))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#6A1B9A')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 3))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#455A64')
        .fontWeight(FontWeight.Medium)
    }
    .padding(10)
    .width('100%');
  }
  .height(getCompanionPopupHeight('hint'))
  .width(getCompanionPopupWidth('hint'));
}

@Builder
export function CompanionWeatherSuggestionPopupBuilder(lines: string[]) {
  Scroll() {
    Column({ space: 2 }) {
      Text(getCompanionPopupLine(lines, 0))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1565C0')
        .fontWeight(FontWeight.Bold)
      Text(getCompanionPopupLine(lines, 1))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#2E7D32')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 2))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#6A1B9A')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 3))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#EF6C00')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 4))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#455A64')
        .fontWeight(FontWeight.Medium)
      Text(getCompanionPopupLine(lines, 5))
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#D32F2F')
        .fontWeight(FontWeight.Bold)
    }
    .padding(10)
    .width('100%');
  }
  .height(getCompanionPopupHeight('suggestion'))
  .width(getCompanionPopupWidth('suggestion'));
}
