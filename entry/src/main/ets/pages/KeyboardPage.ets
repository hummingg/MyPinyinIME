// 九宫格键盘页面（输入法面板内容）
// 第二阶段：数字序列 → 拼音解析 → 候选词 → 上屏
import { ImeState } from '../inputmethod/InputMethodService';
import { generateCandidates } from '../pinyin/Dictionary';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0500;
const TAG = 'KeyboardPage';

@Entry
@Component
struct KeyboardPage {
  @State isChinese: boolean = true;
  @State isFullWidth: boolean = false;
  @State inputDigits: string = '';
  @State candidates: string[] = [];
  private puncts: string[] = ['，', '。', '！', '？', '、', '…', '：', '；', '（', '）', '【', '】', '“', '”'];
  private keys: Array<[string, string]> = [
    ['1', ''], ['2', 'abc'], ['3', 'def'],
    ['4', 'ghi'], ['5', 'jkl'], ['6', 'mno'],
    ['7', 'pqrs'], ['8', 'tuv'], ['9', 'wxyz'],
    ['*', ''], ['0', ''], ['#', '']
  ];
  private englishFirst: Record<string, string> = {
    '2': 'a', '3': 'd', '4': 'g', '5': 'j', '6': 'm', '7': 'p', '8': 't', '9': 'w'
  };

  private commitText(text: string): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      client.insertText(text).then((ok: boolean) => {
        hilog.info(DOMAIN, TAG, 'insertText ok=%{public}d', ok ? 1 : 0);
      }).catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'insertText failed: %{public}s', JSON.stringify(e));
      });
    } else {
      hilog.warn(DOMAIN, TAG, 'inputClient is null');
    }
  }

  private deleteBackward(): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      client.deleteBackward(1).catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'deleteBackward failed: %{public}s', JSON.stringify(e));
      });
    }
  }

  private onDigitKey(key: [string, string]): void {
    const d = key[0];
    if (this.isChinese) {
      if (d >= '2' && d <= '9') {
        this.inputDigits += d;
        this.candidates = generateCandidates(this.inputDigits);
      } else if (d === '1') {
        this.inputDigits = '';
        this.candidates = this.puncts.slice();
      } else if (d === '0') {
        this.commitText(' ');
      } else if (d === '*') {
        this.isChinese = false;
        this.inputDigits = '';
        this.candidates = [];
      } else if (d === '#') {
        this.isFullWidth = !this.isFullWidth;
      }
    } else {
      if (d >= '2' && d <= '9') {
        const ch = this.englishFirst[d];
        if (ch !== undefined) {
          this.commitText(ch);
        }
      } else if (d === '0') {
        this.commitText(' ');
      } else if (d === '*') {
        this.isChinese = true;
        this.inputDigits = '';
        this.candidates = [];
      } else if (d === '#') {
        this.isFullWidth = !this.isFullWidth;
      } else {
        this.commitText(d);
      }
    }
  }

  private onCandidateClick(word: string): void {
    this.commitText(word);
    this.inputDigits = '';
    this.candidates = [];
  }

  private onSpace(): void {
    if (this.candidates.length > 0) {
      this.onCandidateClick(this.candidates[0]);
    } else {
      this.commitText(' ');
    }
  }

  private onDelete(): void {
    if (this.inputDigits.length > 0) {
      this.inputDigits = this.inputDigits.substring(0, this.inputDigits.length - 1);
      this.candidates = generateCandidates(this.inputDigits);
    } else {
      this.deleteBackward();
    }
  }

  build() {
    Column() {
      // 候选栏：拼音序列 + 候选词水平滚动
      Scroll() {
        Row() {
          if (this.inputDigits.length > 0) {
            Text(this.inputDigits)
              .fontSize(15)
              .fontColor('#888888')
              .padding({ left: 10, right: 10 })
              .height(40)
          }
          ForEach(this.candidates, (word: string) => {
            Text(word)
              .fontSize(17)
              .fontColor('#1A73E8')
              .padding({ left: 14, right: 14 })
              .height(40)
              .onClick(() => this.onCandidateClick(word))
          }, (word: string) => word)
          if (this.inputDigits.length === 0 && this.candidates.length === 0) {
            Text(this.isChinese ? (this.isFullWidth ? '九宫格拼音 · 全角' : '九宫格拼音 · 半角') : '英文模式')
              .fontSize(14)
              .fontColor('#AAAAAA')
              .padding({ left: 12 })
              .height(40)
          }
        }
        .height(40)
        .alignItems(VerticalAlign.Center)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(40)
      .backgroundColor('#F5F5F5')

      // 九宫格按键区
      Grid() {
        ForEach(this.keys, (item: [string, string]) => {
          GridItem() {
            Column() {
              Text(item[0])
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#222222')
              if (item[1].length > 0) {
                Text(item[1])
                  .fontSize(10)
                  .fontColor('#999999')
                  .margin({ top: 2 })
              }
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.onDigitKey(item))
          }
        }, (item: [string, string]) => item[0])
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsTemplate('1fr 1fr 1fr 1fr')
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#FFFFFF')

      // 底部功能栏
      Row() {
        Text(this.isChinese ? '中' : 'A')
          .width('20%')
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(16)
          .backgroundColor('#EEEEEE')
          .onClick(() => {
            this.isChinese = !this.isChinese;
            this.inputDigits = '';
            this.candidates = [];
          })
        Text('空格')
          .width('50%')
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#F5F5F5')
          .onClick(() => this.onSpace())
        Text('删除')
          .width('30%')
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#EEEEEE')
          .onClick(() => this.onDelete())
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
