// T9 九宫格数字编码与拼音解析
// 数字序列 → 所有可能的拼音音节切分 → 拼音串
import { PINYIN_SYLLABLES } from './Syllables';

// 字母到数字键映射（2=abc, 3=def, ..., 9=wxyz）
const LETTER_DIGIT: Record<string, string> = {
  'a': '2', 'b': '2', 'c': '2',
  'd': '3', 'e': '3', 'f': '3',
  'g': '4', 'h': '4', 'i': '4',
  'j': '5', 'k': '5', 'l': '5',
  'm': '6', 'n': '6', 'o': '6',
  'p': '7', 'q': '7', 'r': '7', 's': '7',
  't': '8', 'u': '8', 'v': '8',
  'w': '9', 'x': '9', 'y': '9', 'z': '9'
};

// 预计算：数字编码 → 该编码对应的所有音节
let digitsToSyllables: Map<string, string[]> = new Map();

function buildIndex(): void {
  for (const syl of PINYIN_SYLLABLES) {
    let code = '';
    for (const ch of syl) {
      code += LETTER_DIGIT[ch];
    }
    const arr = digitsToSyllables.get(code);
    if (arr === undefined) {
      digitsToSyllables.set(code, [syl]);
    } else {
      arr.push(syl);
    }
  }
}

let inited = false;
function ensureInit(): void {
  if (!inited) {
    buildIndex();
    inited = true;
  }
}

// 数字序列 → 所有可能的音节切分方案（每方案为音节数组）
// 限制方案数避免爆炸
function splitDigits(digits: string, pos: number, cur: string[], out: string[][], maxOut: number): void {
  if (out.length >= maxOut) {
    return;
  }
  if (pos === digits.length) {
    if (cur.length > 0) {
      out.push(cur.slice());
    }
    return;
  }
  // 尝试所有可能的音节长度（1~6 位）
  for (let len = 1; len <= 6 && pos + len <= digits.length; len++) {
    const code = digits.substring(pos, pos + len);
    const syls = digitsToSyllables.get(code);
    if (syls !== undefined) {
      for (const syl of syls) {
        cur.push(syl);
        splitDigits(digits, pos + len, cur, out, maxOut);
        cur.pop();
      }
    }
  }
}

// 数字序列 → 所有可能的拼音串（音节拼接，去重）
export function digitsToPinyins(digits: string): string[] {
  ensureInit();
  if (digits.length === 0) {
    return [];
  }
  const plans: string[][] = [];
  splitDigits(digits, 0, [], plans, 64);
  const set = new Set<string>();
  for (const plan of plans) {
    set.add(plan.join(''));
  }
  return Array.from(set);
}

// 数字序列 → 所有可能的音节切分方案（用于单字候选）
export function digitsToSyllablePlans(digits: string): string[][] {
  ensureInit();
  if (digits.length === 0) {
    return [];
  }
  const plans: string[][] = [];
  splitDigits(digits, 0, [], plans, 64);
  return plans;
}