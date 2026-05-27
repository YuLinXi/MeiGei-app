#!/usr/bin/env node
// 把设计稿 oklch 色板转成 sRGB hex，供 Asset Catalog 录入。
// 用法: node scripts/oklch-to-srgb.mjs
// 依赖: culori (见 scripts/package.json)
import { converter, formatHex, clampChroma } from 'culori';

const toRgb = converter('rgb');

const tokens = [
  ['bg',            0.11, 0.012, 250],
  ['surface',       0.18, 0.016, 250],
  ['surface2',      0.23, 0.018, 250],
  ['border',        0.30, 0.025, 250],
  ['fg',            0.97, 0.008, 220],
  ['fg2',           0.78, 0.015, 220],
  ['muted',         0.58, 0.018, 250],
  ['accentCyan',    0.78, 0.17,  195],
  ['accentMagenta', 0.68, 0.26,  350],
  ['danger',        0.68, 0.24,   25],
  ['ok',            0.78, 0.20,  145],
  // 仅用于「饮食 - 脂肪进度条」语义，禁止外泄到非脂肪场景。
  ['macroFat',      0.72, 0.18,   35],
];

const pad = (s, n) => (s + ' '.repeat(n)).slice(0, n);
console.log('# Token            sRGB hex   r        g        b');
for (const [name, L, C, H] of tokens) {
  const oklch = clampChroma({ mode: 'oklch', l: L, c: C, h: H }, 'rgb');
  const rgb = toRgb(oklch);
  const hex = formatHex(rgb);
  const f = (v) => v.toFixed(4);
  console.log(`${pad(name, 16)} ${hex.toUpperCase()}    ${f(rgb.r)}   ${f(rgb.g)}   ${f(rgb.b)}`);
}
