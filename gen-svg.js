const fs = require('fs');

const CONTRIB_GRID = [[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,4,0,0,0],[0,0,0,0,0,1,4],[2,4,4,3,0,2,0],[4,3,0,4,4,0,0],[3,4,3,3,2,0,0],[1,3,4,3,3,2,1],[1,4,3,3,3,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]];

const COLS = 53, ROWS = 7, CELL = 11, STEP = 14;
const W = COLS * STEP - 3 + 2, H = ROWS * STEP - 3 + 2;
const TOTAL = 26; // animation loop duration in seconds

const LEVEL_COLORS = ['#161b22','#0e4429','#006d32','#26a641','#39d353'];
const NUM_COLORS   = ['','#58a6ff','#3fb950','#f85149','#d2a8ff','#ffa657','#76e3ea','#e6edf3','#7d8590'];

const isMine = (r, c) => r >= 0 && r < ROWS && c >= 0 && c < COLS && (CONTRIB_GRID[c] && CONTRIB_GRID[c][r]) > 0;
const getLv   = (r, c) => (CONTRIB_GRID[c] && CONTRIB_GRID[c][r]) || 1;

// compute numbers
const num = Array.from({length: ROWS}, () => Array(COLS).fill(0));
for (let r = 0; r < ROWS; r++)
  for (let c = 0; c < COLS; c++) {
    if (isMine(r, c)) continue;
    let n = 0;
    for (let dr = -1; dr <= 1; dr++)
      for (let dc = -1; dc <= 1; dc++)
        if ((dr || dc) && isMine(r+dr, c+dc)) n++;
    num[r][c] = n;
  }

// flood fill reveal order
const revealed = Array.from({length: ROWS}, () => Array(COLS).fill(false));
const revealOrder = [];
function flood(r, c) {
  if (r < 0 || r >= ROWS || c < 0 || c >= COLS || revealed[r][c] || isMine(r, c)) return;
  revealed[r][c] = true;
  revealOrder.push([r, c]);
  if (num[r][c] === 0)
    for (let dr = -1; dr <= 1; dr++)
      for (let dc = -1; dc <= 1; dc++)
        if (dr || dc) flood(r+dr, c+dc);
}
flood(0, 0); flood(0, 20); flood(3, 30); flood(6, 40);

// mine list
const mines = [];
for (let r = 0; r < ROWS; r++)
  for (let c = 0; c < COLS; c++)
    if (isMine(r, c)) mines.push([r, c]);

// build event timeline
// phase1: reveal safe cells
// phase2: flag mines
// phase3: reveal green (mines become green blocks)
// phase4: hold, then restart
const revealEnd = revealOrder.length * 0.035;
const flagStart = revealEnd + 0.5;
const flagEnd   = flagStart + mines.length * 0.18;
const greenStart = flagEnd + 0.8;
const greenEnd   = greenStart + mines.length * 0.06;
// TOTAL should be > greenEnd + hold
// greenEnd ≈ 12.5 + 2 hold = 14.5 → use 26 for comfortable loop

// per-cell timing lookup
const revealTime = {};
revealOrder.forEach(([r, c], i) => { revealTime[r + ',' + c] = +(i * 0.035).toFixed(3); });
const flagTime = {};
mines.forEach(([r, c], i) => { flagTime[r + ',' + c] = +(flagStart + i * 0.18).toFixed(3); });
const greenTime = {};
mines.forEach(([r, c], i) => { greenTime[r + ',' + c] = +(greenStart + i * 0.06).toFixed(3); });

function pct(t) { return (t / TOTAL).toFixed(5); }

// build SVG elements
let rects = '';
let overlays = ''; // numbers + flags on top

for (let r = 0; r < ROWS; r++) {
  for (let c = 0; c < COLS; c++) {
    const x = c * STEP + 1;
    const y = r * STEP + 1;
    const key = r + ',' + c;

    if (isMine(r, c)) {
      // mine cell: hidden → flag bg → green block
      const ft = flagTime[key];
      const gt = greenTime[key];
      const lvColor = LEVEL_COLORS[getLv(r, c)];
      rects += `<rect x="${x}" y="${y}" width="${CELL}" height="${CELL}" rx="2">` +
        `<animate attributeName="fill" calcMode="discrete" dur="${TOTAL}s" repeatCount="indefinite"` +
        ` keyTimes="0;${pct(ft)};${pct(gt)};1"` +
        ` values="#2d333b;#2d1b1b;${lvColor};${lvColor}"/>` +
        `</rect>`;
      // flag text
      overlays += `<text x="${x + CELL/2}" y="${y + CELL/2 + 3}" text-anchor="middle" font-size="8" fill="#f85149">` +
        `<animate attributeName="opacity" calcMode="discrete" dur="${TOTAL}s" repeatCount="indefinite"` +
        ` keyTimes="0;${pct(ft)};${pct(gt)};1" values="0;1;0;0"/>` +
        `⚑</text>`;
    } else if (revealTime[key] !== undefined) {
      // safe revealed cell: hidden → open
      const rt = revealTime[key];
      rects += `<rect x="${x}" y="${y}" width="${CELL}" height="${CELL}" rx="2">` +
        `<animate attributeName="fill" calcMode="discrete" dur="${TOTAL}s" repeatCount="indefinite"` +
        ` keyTimes="0;${pct(rt)};1"` +
        ` values="#2d333b;#161b22;#161b22"/>` +
        `</rect>`;
      const n = num[r][c];
      if (n > 0) {
        overlays += `<text x="${x + CELL/2}" y="${y + CELL/2 + 3}" text-anchor="middle" font-size="7" font-weight="bold" fill="${NUM_COLORS[n]}">` +
          `<animate attributeName="opacity" calcMode="discrete" dur="${TOTAL}s" repeatCount="indefinite"` +
          ` keyTimes="0;${pct(rt)};1" values="0;1;1"/>` +
          `${n}</text>`;
      }
    } else {
      // unrevealed safe cell (stays hidden)
      rects += `<rect x="${x}" y="${y}" width="${CELL}" height="${CELL}" rx="2" fill="#2d333b"/>`;
    }
  }
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<rect width="100%" height="100%" fill="#161b22"/>
${rects}
${overlays}
</svg>`;

fs.writeFileSync('E:/Travel/minesweeper.svg', svg);
console.log('done, size:', (svg.length/1024).toFixed(1), 'KB');
