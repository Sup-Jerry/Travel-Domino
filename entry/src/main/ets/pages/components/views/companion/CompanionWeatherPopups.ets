@Builder
export function CompanionWeatherScorePopupBuilder(lines: string[]) {
  Scroll() {
    Column({ space: 2 }) {
      Text(lines[0] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1565C0')
        .fontWeight(FontWeight.Bold)
      Text(lines[1] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#2E7D32')
        .fontWeight(FontWeight.Medium)
      Text(lines[2] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#6A1B9A')
        .fontWeight(FontWeight.Medium)
      Text(lines[3] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#455A64')
        .fontWeight(FontWeight.Medium)
      Text(lines[4] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#EF6C00')
        .fontWeight(FontWeight.Medium)
      Text(lines[5] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1B5E20')
        .fontWeight(FontWeight.Medium)
    }
    .padding(10)
    .width('100%');
  }
  .height(230)
  .width(280);
}

@Builder
export function CompanionWeatherHintPopupBuilder(lines: string[]) {
  Scroll() {
    Column({ space: 2 }) {
      Text(lines[0] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1565C0')
        .fontWeight(FontWeight.Medium)
      Text(lines[1] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#2E7D32')
        .fontWeight(FontWeight.Medium)
      Text(lines[2] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#6A1B9A')
        .fontWeight(FontWeight.Medium)
      Text(lines[3] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#455A64')
        .fontWeight(FontWeight.Medium)
    }
    .padding(10)
    .width('100%');
  }
  .height(230)
  .width(280);
}

@Builder
export function CompanionWeatherSuggestionPopupBuilder(lines: string[]) {
  Scroll() {
    Column({ space: 2 }) {
      Text(lines[0] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#1565C0')
        .fontWeight(FontWeight.Bold)
      Text(lines[1] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#2E7D32')
        .fontWeight(FontWeight.Medium)
      Text(lines[2] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#6A1B9A')
        .fontWeight(FontWeight.Medium)
      Text(lines[3] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#EF6C00')
        .fontWeight(FontWeight.Medium)
      Text(lines[4] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#455A64')
        .fontWeight(FontWeight.Medium)
      Text(lines[5] ?? '')
        .fontSize(12)
        .lineHeight(20)
        .fontColor('#D32F2F')
        .fontWeight(FontWeight.Bold)
    }
    .padding(10)
    .width('100%');
  }
  .height(240)
  .width(290);
}
