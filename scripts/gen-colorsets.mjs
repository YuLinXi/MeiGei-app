#!/usr/bin/env node
// 生成 11 个 Asset Catalog Color Set（仅 Any Appearance，sRGB）。
// 用法: node scripts/gen-colorsets.mjs
import { converter, clampChroma } from 'culori';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

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
];

const root = 'ios/DontLift/DontLift/Assets.xcassets';
const fmt = (v) => Math.max(0, Math.min(1, v)).toFixed(3);

for (const [name, L, C, H] of tokens) {
  const oklch = clampChroma({ mode: 'oklch', l: L, c: C, h: H }, 'rgb');
  const { r, g, b } = toRgb(oklch);
  const dir = join(root, `${name}.colorset`);
  mkdirSync(dir, { recursive: true });
  const json = {
    colors: [
      {
        color: {
          'color-space': 'srgb',
          components: {
            alpha: '1.000',
            red:   fmt(r),
            green: fmt(g),
            blue:  fmt(b),
          },
        },
        idiom: 'universal',
      },
    ],
    info: { author: 'xcode', version: 1 },
  };
  writeFileSync(join(dir, 'Contents.json'), JSON.stringify(json, null, 2) + '\n');
  console.log(`✓ ${name}.colorset`);
}
