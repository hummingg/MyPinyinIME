// 本地词库与候选生成（离线、无网络）
// 主词库：rime-luna-pinyin + rime-essay 转换的 rawfile/dict.json（约 37 万词）
// 兜底词库：内置手写词，rime 加载前/失败时使用
import { digitsToPinyins, digitsToSyllablePlans } from './T9';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';

const DOMAIN = 0x0500;
const TAG = 'Dictionary';

interface WordFreq {
  word: string;
  freq: number;
}

// 兜底词库原始数据：[拼音, 词语, 词频]
const FALLBACK_DATA: Array<[string, string, number]> = [
  ['nihao', '你好', 10000],
  ['nimen', '你们', 9000],
  ['nishi', '你是', 8500],
  ['nishuo', '你说', 8000],
  ['nihaoma', '你好吗', 8800],
  ['zhongguo', '中国', 12000],
  ['beijing', '北京', 9500],
  ['shanghai', '上海', 9000],
  ['shouji', '手机', 9800],
  ['diannao', '电脑', 8500],
  ['shurufa', '输入法', 7000],
  ['hongmeng', '鸿蒙', 8000],
  ['huawei', '华为', 8500],
  ['weixin', '微信', 9500],
  ['kaifa', '开发', 8000],
  ['chengxu', '程序', 7500],
  ['xiangmu', '项目', 7000],
  ['jintian', '今天', 9000],
  ['mingtian', '明天', 8500],
  ['xiexie', '谢谢', 8800],
  ['zaijian', '再见', 8000],
  ['de', '的', 20000],
  ['shi', '是', 17000],
  ['wo', '我', 16000],
  ['ni', '你', 15000],
  ['ta', '他', 14000],
  ['zhe', '这', 13000],
  ['ge', '个', 12000],
  ['zai', '在', 10000],
  ['you', '有', 9500],
  ['he', '和', 9000],
  ['bu', '不', 8800],
  ['ye', '也', 7800],
  ['hui', '会', 7700],
  ['neng', '能', 7600],
  ['shuo', '说', 7500],
  ['kan', '看', 7300],
  ['zuo', '做', 7000],
  ['hao', '好', 6600],
  ['baba', '爸爸', 16000],
  ['mama', '妈妈', 16000],
  ['yinyin', '银行', 36000]
];

let fallbackDict: Map<string, WordFreq[]> = new Map();
let fbInited = false;

function ensureFallback(): void {
  if (fbInited) {
    return;
  }
  for (const item of FALLBACK_DATA) {
    const entry: WordFreq = { word: item[1], freq: item[2] };
    const arr = fallbackDict.get(item[0]);
    if (arr === undefined) {
      fallbackDict.set(item[0], [entry]);
    } else {
      arr.push(entry);
    }
  }
  fallbackDict.forEach((arr: WordFreq[]) => {
    arr.sort((a: WordFreq, b: WordFreq) => b.freq - a.freq);
  });
  fbInited = true;
}

// rime 词库：拼音 → 候选词数组（已按词频降序）
let rimeDict: Map<string, WordFreq[]> | null = null;
let rimeLoaded = false;
let rimeLoading = false;

// 用户词频：用户选过的词自动加分，持久化存储
let userFreqMap: Map<string, number> = new Map();
let userPrefsStore: preferences.Preferences | null = null;

async function loadUserFreq(context: common.Context): Promise<void> {
  try {
    const store = await preferences.getPreferences(context, 'user_dict');
    userPrefsStore = store;
    const raw = await store.get('data', '{}') as string;
    const parsed: Object = JSON.parse(raw);
    const keys = Object.keys(parsed);
    for (const k of keys) {
      userFreqMap.set(k, (parsed as Record<string, number>)[k]);
    }
    hilog.info(DOMAIN, TAG, 'user freq loaded, words=%{public}d', userFreqMap.size);
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'load user freq failed');
  }
}

async function saveUserFreq(): Promise<void> {
  if (userPrefsStore === null) {
    return;
  }
  try {
    const data: Record<string, number> = {};
    userFreqMap.forEach((v: number, k: string) => {
      data[k] = v;
    });
    await userPrefsStore.put('data', JSON.stringify(data));
    await userPrefsStore.flush();
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'save user freq failed');
  }
}

export function recordUserWord(word: string): void {
  const prev = userFreqMap.get(word) || 0;
  userFreqMap.set(word, prev + 1);
  saveUserFreq();
  hilog.info(DOMAIN, TAG, 'record user word: %{public}s (%{public}d)', word, prev + 1);
}

function getUserFreq(word: string): number {
  return userFreqMap.get(word) || 0;
}

// 从 rawfile/dict.json 异步加载 rime 词库（仅加载一次）
export async function initRimeDict(context: common.Context): Promise<void> {
  if (rimeLoaded || rimeLoading) {
    return;
  }
  rimeLoading = true;
  try {
    const data = await context.resourceManager.getRawFileContent('dict.json');
    const text = buffer.from(data).toString('utf-8');
    const parsed: Object = JSON.parse(text);
    const m: Map<string, WordFreq[]> = new Map();
    const keys = Object.keys(parsed);
    for (const k of keys) {
      const rawArr: Object[] = (parsed as Record<string, Object[]>)[k];
      const wf: WordFreq[] = [];
      for (const item of rawArr) {
        const entry: Object[] = item as Object[];
        wf.push({ word: entry[0] as string, freq: entry[1] as number });
      }
      m.set(k, wf);
    }
    rimeDict = m;
    rimeLoaded = true;
    hilog.info(DOMAIN, TAG, 'rime dict loaded, keys=%{public}d', m.size);
  } catch (e) {
    hilog.error(DOMAIN, TAG, 'load rime dict failed: %{public}s', JSON.stringify(e));
  } finally {
    rimeLoading = false;
  }
  // 加载用户词频（独立于 rime 词库）
  await loadUserFreq(context);
}

// 查询某拼音的候选词（优先 rime，兜底 fallback）
function lookup(py: string): WordFreq[] | null {
  if (rimeDict !== null) {
    const arr = rimeDict.get(py);
    if (arr !== undefined) {
      return arr;
    }
  }
  ensureFallback();
  const arr = fallbackDict.get(py);
  return arr !== undefined ? arr : null;
}

// 数字序列 → 候选词列表（按词频排序，词优先于单字）
export function generateCandidates(digits: string): string[] {
  if (digits.length === 0) {
    return [];
  }
  const pinyins = digitsToPinyins(digits);
  const plans = digitsToSyllablePlans(digits);
  const scoreMap = new Map<string, number>();

  // 词候选（完整拼音匹配，去隔音符查 key）
  // 多字词加基础分 100000 优先于单字词（如"西安"优先于"先"）
  for (const py of pinyins) {
    const key = py.replace(/'/g, '');
    const arr = lookup(key);
    if (arr !== null) {
      for (const e of arr) {
        const score = (e.word.length >= 2 ? e.freq + 100000 : e.freq) + getUserFreq(e.word) * 500;
        const prev = scoreMap.get(e.word);
        if (prev === undefined || score > prev) {
          scoreMap.set(e.word, score);
        }
      }
    }
  }

  // 单字候选（第一个音节，降权 0.5，让词优先）
  const firstSyllables = new Set<string>();
  for (const plan of plans) {
    if (plan.length > 0 && plan[0] !== "'") {
      firstSyllables.add(plan[0]);
    }
  }
  firstSyllables.forEach((syl: string) => {
    const arr = lookup(syl);
    if (arr !== null) {
      for (const e of arr) {
        const weighted = e.freq * 0.5 + getUserFreq(e.word) * 500;
        const prev = scoreMap.get(e.word);
        if (prev === undefined || weighted > prev) {
          scoreMap.set(e.word, weighted);
        }
      }
    }
  });

  // 按分数降序排序
  const words: string[] = Array.from(scoreMap.keys());
  words.sort((a: string, b: string) => {
    const fa = scoreMap.get(a) as number;
    const fb = scoreMap.get(b) as number;
    return fb - fa;
  });
  return words;
}

// 数字序列 → 最优拼音显示（优先词库有匹配且词频最高的）
export function bestPinyin(digits: string): string {
  if (digits.length === 0) {
    return '';
  }
  const pys = digitsToPinyins(digits);
  if (pys.length === 0) {
    return digits;
  }
  let best: string = pys[0];
  let bestFreq: number = -1;
  for (const py of pys) {
    const key = py.replace(/'/g, '');
    const arr = lookup(key);
    if (arr !== null && arr.length > 0) {
      const freq = arr[0].freq;
      if (freq > bestFreq) {
        bestFreq = freq;
        best = py;
      }
    }
  }
  return best;
}
