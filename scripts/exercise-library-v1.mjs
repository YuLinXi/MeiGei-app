#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const repo = path.resolve(import.meta.dirname, "..");
const docsPath = path.join(repo, "docs/exercise-library-preset-v1.md");
const swiftFiles = [
  path.join(repo, "ios/DontLift/DontLift/Models/BuiltinExercise.swift"),
  path.join(repo, "ios/DontLift/DontLift/Models/BuiltinExercise+Imported.swift"),
];
const outDir = path.join(repo, "ios/DontLift/DontLift/Resources/ExerciseLibrary");
const presetPath = path.join(outDir, "preset_exercises_v1.json");
const aliasesPath = path.join(outDir, "exercise_aliases_v1.json");
const removedPath = path.join(outDir, "removed_exercises_v1.json");

const command = process.argv[2] ?? "validate";

const manualCodes = new Map(Object.entries({
  "器械推胸": "MACHINE_CHEST_PRESS",
  "蝴蝶机夹胸": "PEC_DECK_FLY",
  "绳索夹胸": "CABLE_CROSSOVER",
  "哑铃推肩": "DB_OVERHEAD_PRESS",
  "蝴蝶机反向飞鸟": "MACHINE_REVERSE_FLY",
  "绳索面拉": "FACE_PULL",
  "器械倒蹬机": "MACHINE_LEG_PRESS",
  "坐姿腿屈伸": "LEG_EXTENSION",
  "单腿腿屈伸": "MACHINE_SINGLE_LEG_EXTENSION",
  "站姿腿弯举": "STANDING_LEG_CURL",
  "站姿哑铃提踵": "DB_CALF_RAISE",
  "坐姿器械划船": "MACHINE_ROW",
  "单臂器械划船": "MACHINE_SINGLE_ARM_ROW",
  "单臂绳索下拉": "CABLE_SINGLE_ARM_PULLDOWN",
  "绳索臂屈伸": "CABLE_TRICEP_EXT",
  "直杆绳索弯举": "BB_STRAIGHT_BAR_CURL",
  "坐姿绳索拉杆二头弯举": "CABLE_SEATED_BAR_CURL",
  "牧师凳俯身飞鸟": "PREACHER_BENCH_REAR_DELT_FLY",
  "单臂牧师凳弯举": "SINGLE_ARM_PREACHER_CURL",
  "单臂绳索下压": "SINGLE_ARM_CABLE_PUSHDOWN",
  "肩部热身": "SHOULDER_WARMUP",
  "弹力带绕肩": "BAND_SHOULDER_PASS_THROUGH",
  "俯卧臂画圈": "PRONE_ARM_CIRCLE",
  "胸椎旋转": "THORACIC_ROTATION",
  "泡沫轴背部放松": "FOAM_ROLL_BACK",
  "泡沫轴小腿放松": "FOAM_ROLL_CALF",
  "平板蝴蝶收腹": "PLANK_BUTTERFLY_CRUNCH",
  "上斜卷腹转体": "INCLINE_TWIST_CRUNCH",
  "反向山羊挺身": "REVERSE_HYPEREXTENSION",
  "史密斯正手划船": "SMITH_OVERHAND_ROW",
  "史密斯反手划船": "SMITH_REVERSE_ROW",
  "下斜史密斯卧推": "DECLINE_SMITH_BENCH_PRESS",
  "上斜史密斯卧推": "INCLINE_SMITH_BENCH_PRESS",
  "哈克深蹲": "HACK_SQUAT",
  "壶铃摆荡": "KETTLEBELL_SWING",
  "农夫行走": "FARMER_CARRY",
  "双杠臂屈伸（胸）": "CHEST_DIP",
  "双杠臂屈伸（三头）": "TRICEP_DIP",
  "反握引体向上": "CHIN_UP",
  "宽握引体向上": "WIDE_PULL_UP",
  "反握高位下拉": "REVERSE_LAT_PULLDOWN",
  "单臂高位下拉": "SINGLE_ARM_LAT_PULLDOWN",
  "悍马机下拉": "HAMMER_PULLDOWN",
  "单臂悍马机下拉": "SINGLE_ARM_HAMMER_PULLDOWN",
  "哑铃划船": "DB_BENT_OVER_ROW",
  "单臂哑铃划船": "SINGLE_ARM_DB_ROW",
  "宽握坐姿划船": "WIDE_SEATED_ROW",
  "单臂悍马机划船": "SINGLE_ARM_HAMMER_ROW",
  "史密斯肩推": "SMITH_SHOULDER_PRESS",
  "单臂绳索侧平举": "SINGLE_ARM_CABLE_LATERAL_RAISE",
  "交叉锤式弯举": "DB_CROSS_HAMMER_CURL",
  "双杠臂屈伸(胸)": "CHEST_DIP",
  "双杠臂屈伸(三头)": "TRICEP_DIP",
  "器械臀推": "MACHINE_HIP_THRUST",
  "臀桥": "GLUTE_BRIDGE",
  "哑铃臀桥": "DB_GLUTE_BRIDGE",
  "弹力带侧走": "BAND_LATERAL_WALK",
  "仰卧起坐": "SIT_UP",
  "悬挂举腿": "HANGING_LEG_RAISE",
  "死虫": "DEAD_BUG",
  "鸟狗": "BIRD_DOG",
  "上斜卷腹": "INCLINE_CRUNCH",
  "战绳": "BATTLE_ROPE",
  "猫牛式": "CAT_COW",
}));

const manualAliases = [
  { targetName: "高位下拉", legacyCodes: ["LAT_PULLDOWN"], legacyNames: ["宽距下拉", "宽握高位下拉", "高位下拉"] },
  { targetName: "绳索臂屈伸", legacyCodes: ["CABLE_TRICEP_EXT"], legacyNames: ["绳索臂屈伸"] },
  { targetName: "蝴蝶机反向飞鸟", legacyCodes: ["MACHINE_REVERSE_FLY", "REVERSE_PEC_DECK"], legacyNames: ["蝴蝶机反向飞鸟", "反向蝴蝶机"] },
  { targetName: "蝴蝶机夹胸", legacyCodes: ["PEC_DECK", "PEC_DECK_FLY"], legacyNames: ["蝴蝶机飞鸟", "器械飞鸟", "蝴蝶机夹胸"] },
  { targetName: "坐姿器械划船", legacyCodes: ["MACHINE_ROW"], legacyNames: ["器械划船1", "坐姿器械划船"], requiresNameMatch: true },
  { targetName: "单臂器械划船", legacyCodes: ["MACHINE_ROW"], legacyNames: ["器械单臂划船"], requiresNameMatch: true },
  { targetName: "器械推胸", legacyCodes: ["MACHINE_CHEST_PRESS"], legacyNames: ["器械推胸", "器械推胸（版本3）", "器械推胸（版本4）"] },
  { targetName: "悍马机划船", legacyCodes: ["HAMMER_ROW"], legacyNames: ["悍马机划船", "悍马机划船（版本2）"] },
  { targetName: "悍马机下拉", legacyCodes: ["HAMMER_PULLDOWN"], legacyNames: ["悍马机下拉", "悍马机正手下拉", "悍马机下拉（版本2）"] },
  { targetName: "器械下拉", legacyCodes: ["MACHINE_PULLDOWN"], legacyNames: ["器械下拉", "器械下拉（版本2）"] },
  { targetName: "器械倒蹬机", legacyCodes: ["MACHINE_LEG_PRESS"], legacyNames: ["器械倒蹬", "器械倒蹬(版本2)", "器械倒蹬机"] },
  { targetName: "绳索夹胸", legacyCodes: ["CABLE_FLY", "CABLE_CROSSOVER"], legacyNames: ["绳索十字夹胸", "绳索夹胸"] },
  { targetName: "哑铃交替弯举", legacyCodes: ["DB_ROTATING_CURL"], legacyNames: ["哑铃轮换弯举", "哑铃交替弯举"] },
  { targetName: "绳索面拉", legacyCodes: ["FACE_PULL"], legacyNames: ["面拉", "绳索面拉"] },
  { targetName: "交叉锤式弯举", legacyCodes: ["DB_CROSS_HAMMER_CURL"], legacyNames: ["哑铃交叉锤式弯举（版本2）", "交叉锤式弯举"] },
  { targetName: "T杠划船", legacyCodes: ["CLOSE_T_BAR_ROW"], legacyNames: ["窄握 T杠划船", "窄握T杠划船"] },
  { targetName: "EZ 杠弯举", legacyCodes: ["BB_EZ_BAR_CURL", "EZ_BAR_CURL"], legacyNames: ["EZ杆二头弯举", "EZ杠弯举", "EZ 杠弯举"] },
  { targetName: "直杆绳索弯举", legacyCodes: ["BB_STRAIGHT_BAR_CURL"], legacyNames: ["直杆绳索弯举"] },
  { targetName: "直臂下压", legacyCodes: ["BB_STRAIGHT_ARM_PUSHDOWN", "STRAIGHT_ARM_PULLDOWN"], legacyNames: ["铁杆直臂下压", "直臂下压"] },
  { targetName: "直杆绳索下压", legacyCodes: ["BB_STRAIGHT_BAR_PUSHDOWN"], legacyNames: ["直杆绳索下压"] },
  { targetName: "V-bar 绳索下压", legacyCodes: ["CABLE_V_BAR_PUSHDOWN"], legacyNames: ["V-Bar 绳索下压", "V-bar 绳索下压"] },
  { targetName: "哑铃推肩", legacyCodes: ["DB_OVERHEAD_PRESS", "DB_SHOULDER_PRESS"], legacyNames: ["哑铃推肩", "哑铃肩推"] },
  { targetName: "杠铃深蹲", legacyCodes: ["BB_SQUAT"], legacyNames: ["深蹲", "杠铃深蹲"] },
  { targetName: "罗马尼亚硬拉", legacyCodes: ["ROMANIAN_DL"], legacyNames: ["杠铃罗马尼亚硬拉", "罗马尼亚硬拉"] },
  { targetName: "单臂绳索下拉", legacyNames: ["龙门架单边下拉练胸", "单臂绳索下拉下压", "单臂绳索下拉"] },
  { targetName: "哑铃直立划船", legacyNames: ["站姿哑铃划船", "哑铃直立划船"] },
  { targetName: "窄距卧推", legacyNames: ["窄距卧推(靠近式)", "窄距卧推"] },
  { targetName: "单臂牧师凳弯举", legacyNames: ["坐姿单手牧师凳弯举", "单臂牧师凳弯举"] },
  { targetName: "坐姿绳索拉杆二头弯举", legacyNames: ["坐姿绳索拉杆二头弯举"] },
  { targetName: "牧师凳俯身飞鸟", legacyNames: ["牧师凳 附身飞鸟", "牧师凳俯身飞鸟"] },
  { targetName: "肩部热身", legacyNames: ["练肩热身", "肩部热身"] },
  { targetName: "反握高位下拉", legacyCodes: ["WIDE_REVERSE_PULLDOWN"], legacyNames: ["宽握反手下拉"] },
  { targetName: "宽握坐姿划船", legacyCodes: ["BB_WIDE_SEATED_ROW"], legacyNames: ["拉杆坐姿划船(宽握)"] },
  { targetName: "窄握高位下拉", legacyCodes: ["CLOSE_PULLDOWN"], legacyNames: ["窄距下拉"] },
  { targetName: "单臂悍马机划船", legacyCodes: ["HAMMER_SEATED_SINGLE_ARM_ROW"], legacyNames: ["单手坐姿悍马机划船"] },
  { targetName: "单臂绳索下拉", legacyCodes: ["SINGLE_ARM_PULLDOWN"], legacyNames: ["单手下拉", "龙门架绳索单臂侧拉"] },
  { targetName: "俯卧哑铃划船", legacyCodes: ["DB_PRONE_HAMMER_ROW"], legacyNames: ["俯卧哑铃划船（锤式）"] },
  { targetName: "悬挂举腿", legacyCodes: ["BAR_HANGING_LEG_RAISE"], legacyNames: ["悬挂抬腿"] },
  { targetName: "哑铃仰卧上拉", legacyCodes: ["DB_FLAT_BENCH_PULL"], legacyNames: ["平板哑铃提拉"] },
  { targetName: "器械肩推", legacyCodes: ["MACHINE_SEATED_PRESS"], legacyNames: ["器械坐姿推举"] },
  { targetName: "哑铃飞鸟", legacyCodes: ["FLAT_DB_FLY"], legacyNames: ["平躺哑铃飞鸟"] },
  { targetName: "俯身飞鸟", legacyCodes: ["HALF_BENT_LATERAL_RAISE"], legacyNames: ["半俯身侧平举"] },
  { targetName: "单臂哑铃划船", legacyCodes: ["DB_ROW"], legacyNames: ["哑铃划船（手扶）"], requiresNameMatch: true },
  { targetName: "保加利亚分腿蹲", legacyCodes: ["DB_BULGARIAN_SQUAT", "WEIGHTED_BULGARIAN_SQUAT"], legacyNames: ["哑铃保加利亚蹲", "保加利亚蹲"] },
  { targetName: "上斜俯卧撑", legacyCodes: ["STEP_PUSH_UP"], legacyNames: ["上台阶俯卧撑"] },
  { targetName: "单臂绳索下压", legacyCodes: ["CABLE_SINGLE_ARM_TRICEP_EXT"], legacyNames: ["单手绳索臂屈伸"] },
  { targetName: "仰卧臂屈伸", legacyCodes: ["BODYWEIGHT_SKULL_CRUSHER"], legacyNames: ["碎颅者"] },
];

const removedRecords = [
  ["杠铃单臂推", "lowValue", "不进入新预置库"],
  ["派克俯卧撑", "lowValue", "不进入新预置库"],
  ["扎特曼弯举", "lowValue", "不进入新预置库"],
  ["JM 推", "lowValue", "不进入新预置库"],
  ["JM推", "lowValue", "不进入新预置库"],
  ["西西深蹲", "lowValue", "不进入新预置库"],
  ["西西里深蹲", "lowValue", "不进入新预置库"],
  ["哑铃腿弯举", "lowValue", "不进入新预置库"],
  ["腿举机提踵", "lowValue", "不进入新预置库"],
  ["弹力带蚌式", "lowValue", "不进入新预置库"],
  ["平板臂屈伸", "lowValue", "不进入新预置库"],
  ["跑步", "timedCardio", "计时型训练动作，历史保留原名"],
  ["椭圆机", "timedCardio", "计时型训练动作，历史保留原名"],
  ["划船机", "timedCardio", "计时型训练动作，历史保留原名"],
  ["动感单车", "timedCardio", "计时型训练动作，历史保留原名"],
  ["跳绳", "timedCardio", "计时型训练动作，历史保留原名"],
  ["跑步（有氧）", "timedCardio", "计时型训练动作，历史保留原名"],
  ["四足向后旋转", "lowValue", "不进入新预置库"],
  ["TraditionalStrengthTraining", "healthKitGeneric", "HealthKit 泛称，不进入动作库"],
  ["沙发伸展", "lowValue", "不进入新预置库"],
].map(([name, reason, note]) => ({ name, reason, note, allowNewSelection: false, keepHistoricalDisplay: true }));

const extraPresetRows = [
  { name: "单臂绳索下拉", equipmentType: "绳索", category: "背", detail: "背阔肌", note: "保留，覆盖线上自定义旧名称" },
  { name: "直杆绳索下压", equipmentType: "绳索", category: "手臂", detail: "肱三头肌", note: "保留，线上有历史" },
  { name: "V-bar 绳索下压", equipmentType: "绳索", category: "手臂", detail: "肱三头肌", note: "保留，线上有历史" },
  { name: "单臂绳索下压", equipmentType: "绳索", category: "手臂", detail: "肱三头肌", note: "保留，线上有历史" },
  { name: "单臂牧师凳弯举", equipmentType: "哑铃/器械", category: "手臂", detail: "肱二头肌", note: "保留，覆盖线上自定义" },
];

function readText(file) {
  return fs.readFileSync(file, "utf8");
}

function parseExistingSwiftExercises() {
  const map = new Map();
  const rows = [];
  const pattern = /\.init\(code:\s*"([^"]+)",\s*name:\s*"([^"]+)",\s*category:\s*"([^"]+)"(?:,\s*subcategory:\s*"([^"]+)")?,\s*equipmentType:\s*"([^"]+)"\)/g;
  for (const file of swiftFiles) {
    const text = readText(file);
    for (const m of text.matchAll(pattern)) {
      const row = { code: m[1], name: m[2], category: m[3], subcategory: m[4] ?? null, equipmentType: m[5] };
      rows.push(row);
      if (!map.has(row.name)) map.set(row.name, []);
      map.get(row.name).push(row);
    }
  }
  return { rows, byName: map };
}

function parsePresetRows() {
  const text = readText(docsPath);
  const sectionPattern = /### 5\.(\d+) ([^\n]+)\n([\s\S]*?)(?=\n### 5\.|\n## 6\.|\n$)/g;
  const rows = [];
  for (const section of text.matchAll(sectionPattern)) {
    const number = Number(section[1]);
    const title = section[2].trim();
    if (number === 9) continue;
    const lines = section[3].split("\n").map((line) => line.trim()).filter((line) => line.startsWith("| "));
    for (const line of lines) {
      if (line.includes("---") || line.includes("建议标准名")) continue;
      const cells = line.split("|").slice(1, -1).map((cell) => cell.trim());
      if (number === 8) {
        const [name, type, note] = cells;
        rows.push({ name, equipmentType: equipmentFromType(type), category: categoryFromType(type), detail: null, note });
      } else {
        const [name, equipmentType, detail, note] = cells;
        rows.push({ name, equipmentType, category: title.trim(), detail, note });
      }
    }
  }
  return rows;
}

function categoryFromType(type) {
  if (type.includes("功能性") || type.includes("有氧")) return "功能性";
  return "热身拉伸";
}

function equipmentFromType(type) {
  if (type.includes("壶铃")) return "壶铃";
  if (type.includes("弹力")) return "弹力带";
  if (type.includes("泡沫轴")) return "其他";
  return "自重";
}

function normalizeEquipment(value) {
  if (value === "杠铃/器械") return "器械";
  if (value === "哑铃/器械") return "哑铃";
  return value;
}

function fallbackCode(name, used) {
  const explicit = {
    "V-bar 下拉": "V_BAR_PULLDOWN",
    "V-bar 划船": "V_BAR_ROW",
    "V-bar 绳索下压": "CABLE_V_BAR_PUSHDOWN",
    "EZ 杠弯举": "EZ_BAR_CURL",
  }[name];
  let code = explicit ?? `PRESET_${String(used.size + 1).padStart(3, "0")}`;
  while (used.has(code)) code = `${code}_2`;
  return code;
}

function primaryRegionsFor(row) {
  const detail = row.detail ?? "";
  const name = row.name;
  const category = row.category;
  const regions = new Set();
  const add = (...items) => items.forEach((item) => regions.add(item));

  if (category === "胸") add("chest");
  if (category === "背") {
    if (detail.includes("背阔")) add("lats");
    if (detail.includes("中背")) add("rhomboids");
    if (detail.includes("斜方")) add("traps");
    if (detail.includes("竖脊") || detail.includes("下背")) add("lowerBack");
    if (detail.includes("臀")) add("glutes");
    if (regions.size === 0) add("lats");
  }
  if (category === "肩") {
    if (detail.includes("前束")) add("deltFront");
    if (detail.includes("中束")) add("deltSide");
    if (detail.includes("后束")) add("deltRear");
    if (detail.includes("斜方")) add("traps");
    if (regions.size === 0) add("deltFront");
  }
  if (category === "手臂") {
    if (detail.includes("二头")) add("biceps");
    if (detail.includes("三头")) add("triceps");
    if (detail.includes("前臂")) add("forearms");
    if (regions.size === 0) add("biceps");
  }
  if (category === "腿") {
    if (detail.includes("股四")) add("quads");
    if (detail.includes("腘绳")) add("hams");
    if (detail.includes("内收")) add("adductors");
    if (detail.includes("小腿")) add("calves");
    if (detail.includes("臀")) add("glutes");
    if (regions.size === 0) add("quads");
  }
  if (category === "臀") {
    if (detail.includes("臀中")) add("gluteMed");
    if (detail.includes("腘绳")) add("hams");
    add("glutes");
  }
  if (category === "核心") {
    if (detail.includes("腹斜")) add("obliques");
    else if (detail.includes("核心")) add("abs", "obliques");
    else add("abs");
  }
  if (category === "功能性") {
    if (name.includes("农夫")) add("forearms", "traps");
    else if (name.includes("壶铃摆荡")) add("glutes", "hams");
    else if (name.includes("土耳其")) add("abs", "deltFront");
    else if (name.includes("战绳")) add("deltFront", "forearms");
    else if (name.includes("波比")) add("quads", "chest");
  }
  return Array.from(regions);
}

function secondaryRegionsFor(row) {
  const name = row.name;
  const category = row.category;
  const regions = new Set();
  const add = (...items) => items.forEach((item) => regions.add(item));
  if (category === "胸") add("deltFront", "triceps");
  if (category === "背" && !name.includes("硬拉") && !name.includes("山羊") && !name.includes("早安")) add("biceps", "deltRear");
  if (category === "肩" && name.includes("推")) add("triceps");
  if (category === "腿" && name.includes("罗马尼亚")) add("glutes");
  if (category === "臀" && name.includes("单腿哑铃硬拉")) add("hams");
  return Array.from(regions);
}

function normalizedSubcategory(row) {
  if (row.category === "胸" && ["上胸", "中下胸"].includes(row.detail)) return row.detail;
  if (row.category === "肩" && ["前束", "中束", "后束"].includes(row.detail)) return row.detail;
  if (row.category === "核心" && ["上腹", "下腹"].includes(row.detail)) return row.detail;
  return null;
}

function buildPresetManifest() {
  const existing = parseExistingSwiftExercises();
  const usedCodes = new Set();
  const rows = parsePresetRows();
  const presentNames = new Set(rows.map((row) => row.name));
  for (const row of extraPresetRows) {
    if (!presentNames.has(row.name)) {
      rows.push(row);
      presentNames.add(row.name);
    }
  }
  const exercises = rows.map((row, index) => {
    const exact = existing.byName.get(row.name)?.[0];
    const code = manualCodes.get(row.name) ?? exact?.code ?? fallbackCode(row.name, usedCodes);
    usedCodes.add(code);
    return {
      code,
      name: row.name,
      category: row.category,
      subcategory: normalizedSubcategory(row),
      equipmentType: normalizeEquipment(row.equipmentType),
      primaryRegions: primaryRegionsFor(row),
      secondaryRegions: secondaryRegionsFor(row),
      formCues: [],
      source: "preset-v1",
      order: index,
      note: row.note || undefined,
    };
  });
  return { schemaVersion: 1, generatedFrom: "docs/exercise-library-preset-v1.md", exercises };
}

function buildAliasManifest(preset) {
  const byName = new Map(preset.exercises.map((ex) => [ex.name, ex]));
  const aliases = manualAliases.map((raw) => {
    const target = byName.get(raw.targetName);
    if (!target) throw new Error(`别名目标不存在: ${raw.targetName}`);
    return {
      targetCode: target.code,
      targetName: target.name,
      legacyCodes: raw.legacyCodes ?? [],
      legacyNames: raw.legacyNames ?? [],
      requiresNameMatch: raw.requiresNameMatch ?? false,
    };
  });
  return { schemaVersion: 1, generatedFrom: "docs/exercise-library-preset-v1.md", aliases };
}

function buildRemovedManifest() {
  return { schemaVersion: 1, generatedFrom: "docs/exercise-library-preset-v1.md", removed: removedRecords };
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function loadJson(file) {
  return JSON.parse(readText(file));
}

function validateManifests(preset = loadJson(presetPath), aliases = loadJson(aliasesPath), removed = loadJson(removedPath)) {
  const errors = [];
  const validCategories = new Set(["胸", "背", "肩", "手臂", "腿", "臀", "核心", "颈部", "有氧", "功能性", "热身拉伸"]);
  const validEquipment = new Set(["杠铃", "哑铃", "壶铃", "器械", "史密斯", "悍马机", "T杠", "绳索", "弹力带", "悬挂", "自重", "其他"]);
  const codes = new Set();
  const names = new Set();
  const removedNames = new Set(removed.removed.map((item) => item.name));
  for (const ex of preset.exercises) {
    if (codes.has(ex.code)) errors.push(`重复 code: ${ex.code}`);
    codes.add(ex.code);
    if (names.has(ex.name)) errors.push(`重复标准名: ${ex.name}`);
    names.add(ex.name);
    if (!validCategories.has(ex.category)) errors.push(`非法部位: ${ex.name} ${ex.category}`);
    if (!validEquipment.has(ex.equipmentType)) errors.push(`非法器械: ${ex.name} ${ex.equipmentType}`);
    if (removedNames.has(ex.name)) errors.push(`移除动作出现在预置库: ${ex.name}`);
  }
  for (const alias of aliases.aliases) {
    if (!codes.has(alias.targetCode)) errors.push(`别名指向不存在 code: ${alias.targetName} -> ${alias.targetCode}`);
    if (!names.has(alias.targetName)) errors.push(`别名指向不存在标准名: ${alias.targetName}`);
    for (const n of alias.legacyNames ?? []) {
      if (removedNames.has(n) && alias.targetName !== n) continue;
    }
  }
  for (const must of ["下斜史密斯卧推", "悍马机卧推", "绳索面拉", "器械倒蹬机", "坐姿绳索拉杆二头弯举", "农夫行走", "壶铃摆荡"]) {
    if (!names.has(must)) errors.push(`缺关键保留动作: ${must}`);
  }
  for (const gone of ["派克俯卧撑", "扎特曼弯举", "JM 推", "西西深蹲", "弹力带蚌式", "TraditionalStrengthTraining"]) {
    if (names.has(gone)) errors.push(`明确移除动作仍在预置库: ${gone}`);
  }
  return errors;
}

function key(s) {
  return (s ?? "").trim();
}

function coverageRows(file) {
  if (!file) return [];
  const text = readText(file).trim();
  if (!text) return [];
  const lines = text.split(/\r?\n/);
  const header = lines.shift().split(",");
  const idx = Object.fromEntries(header.map((h, i) => [h.trim(), i]));
  return lines.map((line) => {
    const cells = line.split(",");
    return {
      kind: cells[idx.kind] ?? "",
      code: cells[idx.code] ?? "",
      exerciseName: cells[idx.exercise_name] ?? cells[idx.exerciseName] ?? "",
      count: Number(cells[idx.workout_count] ?? cells[idx.plan_item_count] ?? "0"),
    };
  });
}

function coverage(preset, aliases, removed, workoutFile, planFile) {
  const codes = new Set(preset.exercises.map((ex) => ex.code));
  const names = new Set(preset.exercises.map((ex) => ex.name));
  const removedNames = new Set(removed.removed.map((item) => item.name));
  const aliasMatches = [];
  for (const alias of aliases.aliases) {
    for (const code of alias.legacyCodes ?? []) aliasMatches.push({ code, names: alias.legacyNames ?? [], requiresNameMatch: alias.requiresNameMatch });
    for (const name of alias.legacyNames ?? []) aliasMatches.push({ code: "", names: [name], requiresNameMatch: true });
  }
  function covered(row) {
    const code = key(row.code);
    const name = key(row.exerciseName);
    if (code && codes.has(code)) return true;
    if (name && names.has(name)) return true;
    if (name && removedNames.has(name)) return true;
    return aliasMatches.some((alias) => {
      const codeMatches = alias.code && code === alias.code;
      const nameMatches = alias.names.some((n) => n === name);
      return alias.requiresNameMatch ? (codeMatches || !alias.code) && nameMatches : codeMatches || nameMatches;
    });
  }
  const workoutMissing = coverageRows(workoutFile).filter((row) => !covered(row));
  const planMissing = coverageRows(planFile).filter((row) => !covered(row));
  return { workoutMissing, planMissing };
}

if (command === "generate") {
  const preset = buildPresetManifest();
  const aliases = buildAliasManifest(preset);
  const removed = buildRemovedManifest();
  const errors = validateManifests(preset, aliases, removed);
  if (errors.length) {
    console.error(errors.join("\n"));
    process.exit(1);
  }
  writeJson(presetPath, preset);
  writeJson(aliasesPath, aliases);
  writeJson(removedPath, removed);
  console.log(`generated ${preset.exercises.length} preset exercises`);
} else if (command === "validate") {
  const errors = validateManifests();
  if (errors.length) {
    console.error(errors.join("\n"));
    process.exit(1);
  }
  console.log("exercise library manifests valid");
} else if (command === "coverage") {
  const result = coverage(loadJson(presetPath), loadJson(aliasesPath), loadJson(removedPath), process.argv[3], process.argv[4]);
  console.log(JSON.stringify(result, null, 2));
  if (result.workoutMissing.length || result.planMissing.length) process.exit(1);
} else {
  console.error(`unknown command: ${command}`);
  process.exit(2);
}
