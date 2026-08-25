// 九宫格键盘页面（输入法面板内容）
// 布局对齐小艺输入法：
//   ，  1  2  3  删除
//   。  4  5  6  清空
//   ？  7  8  9  ⏎
//   符号 中/英 0 123
import { ImeState } from '../inputmethod/InputMethodService';
import { generateCandidates } from '../pinyin/Dictionary';
import { digitsToPinyins } from '../pinyin/T9';
import { hilog } from '@kit.PerformanceAnalysisKit';
import display from '@ohos.display';

const DOMAIN = 0x0500;
const TAG = 'KeyboardPage';

@Entry
@Component
struct KeyboardPage {
  @State isChinese: boolean = true;
  @State inputDigits: string = '';
  @State candidates: string[] = [];
  // 英文滑动选择状态
  @State showPicker: boolean = false;
  @State pickerChars: string[] = [];
  @State pickerIndex: number = 0;
  private touchStartX: number = 0;
  private readonly pickerCellWidth: number = 13;
  private readonly pickerRenderWidth: number = 28;
  private engLetters: Record<string, string[]> = {
    '2': ['a', 'b', 'c'], '3': ['d', 'e', 'f'], '4': ['g', 'h', 'i'],
    '5': ['j', 'k', 'l'], '6': ['m', 'n', 'o'], '7': ['p', 'q', 'r', 's'],
    '8': ['t', 'u', 'v'], '9': ['w', 'x', 'y', 'z']
  };
  // 主键盘三行：[label, sub, action]
  private kbRows: Array<Array<[string, string, string]>> = [
    [['，', '', 'punct'], ['1', '分词', 'digit'], ['2', 'abc', 'digit'], ['3', 'def', 'digit'], ['删除', '', 'delete']],
    [['。', '', 'punct'], ['4', 'ghi', 'digit'], ['5', 'jkl', 'digit'], ['6', 'mno', 'digit'], ['清空', '', 'clear']],
    [['？', '', 'punct'], ['7', 'pqrs', 'digit'], ['8', 'tuv', 'digit'], ['9', 'wxyz', 'digit'], ['⏎', '', 'enter']]
  ];
  private symbols: string[] = ['～', '·', '°', '±', '×', '÷', '√', '≈', '≠', '≤', '≥', '《', '》', '「', '」', '『', '』', '〔', '〕', '‰', '℃', '￥', '＄', '€', '§', '★', '○', '●', '◇', '◆', '□', '■', '△', '▲', '※', '→', '←', '↑', '↓', '⇒', '⇔', '∈', '∏', '∑', '∞', '∠', '⊥', '⊕', '⊗'];

  // 生成滑动选择字符列表：数字 + 小写字母 + 大写字母
  private getPickerChars(d: string): string[] {
    const letters = this.engLetters[d];
    if (letters === undefined) {
      return [d];
    }
    const result: string[] = [d];
    for (const ch of letters) {
      result.push(ch);
    }
    for (const ch of letters) {
      result.push(ch.toUpperCase());
    }
    return result;
  }

  // 候选栏显示的拼音（解析后带隔音符，如 xi'an）
  private displayPinyin(): string {
    if (this.inputDigits.length === 0) {
      return '';
    }
    const pys = digitsToPinyins(this.inputDigits);
    return pys.length > 0 ? pys.slice(0, 4).join('  ') : this.inputDigits;
  }

  private commitText(text: string): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      try {
        client.insertTextSync(text);
        hilog.info(DOMAIN, TAG, 'insertTextSync ok');
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'insertTextSync failed: %{public}s', JSON.stringify(e));
      }
    }
  }

  private deleteBackward(): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      try {
        client.deleteForwardSync(1);
        hilog.info(DOMAIN, TAG, 'deleteForwardSync ok');
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'deleteForwardSync failed: %{public}s', JSON.stringify(e));
      }
    } else {
      hilog.warn(DOMAIN, TAG, 'deleteBackward: inputClient null');
    }
  }

  // 清空输入框中光标前的全部已提交文本
  private clearAllInputText(): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      let len = 0;
      try {
        const text = client.getForwardSync(1024);
        len = text.length;
        hilog.info(DOMAIN, TAG, 'clearAllInputText getForwardSync len=%{public}d', len);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'clearAllInputText getForwardSync failed: %{public}s', JSON.stringify(e));
      }
      if (len <= 0) {
        len = 64;
      }
      let deleted = 0;
      for (let i = 0; i < len; i++) {
        try {
          client.deleteForwardSync(1);
          deleted++;
        } catch (e) {
          break;
        }
      }
      hilog.info(DOMAIN, TAG, 'clearAllInputText deleted %{public}d chars', deleted);
    } else {
      hilog.warn(DOMAIN, TAG, 'clearAllInputText: inputClient null');
    }
  }

  // 按键动作分发
  private onKey(action: string, label: string): void {
    switch (action) {
      case 'punct':
        this.commitText(label);
        break;
      case 'digit':
        this.onDigit(label);
        break;
      case 'delete':
        this.onDelete();
        break;
      case 'clear':
        if (this.inputDigits.length > 0) {
          this.inputDigits = '';
          this.candidates = [];
        } else {
          this.clearAllInputText();
        }
        break;
      case 'enter':
        this.commitText('\n');
        break;
      default:
        break;
    }
  }

  private onDigit(d: string): void {
    if (this.isChinese) {
      if (d >= '2' && d <= '9') {
        this.inputDigits += d;
        this.candidates = generateCandidates(this.inputDigits);
      } else if (d === '1') {
        // 中文模式 1 作为隔音符（分词），如 xi'an
        if (this.inputDigits.length > 0) {
          this.inputDigits += "'";
          this.candidates = generateCandidates(this.inputDigits);
        } else {
          this.commitText('1');
        }
      } else {
        this.commitText(d);
      }
    } else if (d === '1') {
      this.commitText(d);
    }
    // 英文模式 2-9 由 onTouch 滑动选择处理
  }

  private onCandidateClick(word: string): void {
    this.commitText(word);
    this.inputDigits = '';
    this.candidates = [];
  }

  private onSpace(): void {
    if (this.isChinese) {
      if (this.candidates.length > 0) {
        this.onCandidateClick(this.candidates[0]);
      } else {
        this.commitText(' ');
      }
    } else {
      this.commitText(' ');
    }
  }

  private onDelete(): void {
    if (this.isChinese) {
      if (this.inputDigits.length > 0) {
        this.inputDigits = this.inputDigits.substring(0, this.inputDigits.length - 1);
        this.candidates = generateCandidates(this.inputDigits);
      } else {
        this.deleteBackward();
      }
    } else {
      this.deleteBackward();
    }
  }

  private onSymbol(): void {
    this.inputDigits = '';
    this.candidates = this.symbols.slice();
  }

  private onLangSwitch(): void {
    this.isChinese = !this.isChinese;
    this.inputDigits = '';
    this.candidates = [];
    this.showPicker = false;
  }

  private onNumSwitch(): void {
    this.inputDigits = '';
    this.candidates = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
  }

  // 英文模式0键滑动选择：0 / 空格
  private onZeroTouch(event: TouchEvent): void {
    if (this.isChinese) {
      if (event.type === TouchType.Up) {
        this.onSpace();
      }
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchStartX = event.touches[0].screenX;
      this.pickerChars = ['0', ' '];
      this.pickerIndex = 1;
      this.showPicker = true;
    } else if (event.type === TouchType.Move) {
      const deltaX = event.touches[0].screenX - this.touchStartX;
      const newIndex = 1 + Math.round(deltaX / this.pickerCellWidth);
      this.pickerIndex = Math.max(0, Math.min(newIndex, this.pickerChars.length - 1));
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.showPicker && this.pickerChars.length > 0) {
        this.commitText(this.pickerChars[this.pickerIndex]);
      }
      this.showPicker = false;
      this.pickerChars = [];
      this.pickerIndex = 0;
    }
  }

  // 英文模式滑动选择：onTouch 绑定单个键，手指滑出按键时 Cancel 提交当前字母
  private onDigitTouch(event: TouchEvent, d: string): void {
    if (this.isChinese) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchStartX = event.touches[0].screenX;
      this.pickerChars = this.getPickerChars(d);
      this.pickerIndex = 1;
      this.showPicker = true;
    } else if (event.type === TouchType.Move) {
      const deltaX = event.touches[0].screenX - this.touchStartX;
      const newIndex = 1 + Math.round(deltaX / this.pickerCellWidth);
      this.pickerIndex = Math.max(0, Math.min(newIndex, this.pickerChars.length - 1));
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.showPicker && this.pickerChars.length > 0) {
        this.commitText(this.pickerChars[this.pickerIndex]);
      }
      this.showPicker = false;
      this.pickerChars = [];
      this.pickerIndex = 0;
    }
  }

  build() {
    Column() {
      // 滑动选择栏 / 候选栏
      if (this.showPicker) {
        Row() {
          ForEach(this.pickerChars, (ch: string, index: number) => {
            Text(ch === ' ' ? '空格' : ch)
              .fontSize(index === this.pickerIndex ? 18 : 14)
              .fontWeight(index === this.pickerIndex ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(index === this.pickerIndex ? '#FFFFFF' : '#666666')
              .width(this.pickerRenderWidth)
              .height(40)
              .textAlign(TextAlign.Center)
              .backgroundColor(index === this.pickerIndex ? '#1A73E8' : '#F0F0F0')
              .borderRadius(4)
          }, (ch: string, index: number) => ch + index)
        }
        .width('100%')
        .height(40)
        .justifyContent(FlexAlign.Start)
        .padding({ left: 4 })
        .backgroundColor('#F5F5F5')
      } else {
        // 候选栏：拼音序列 + 候选词水平滚动（左对齐，贴左边框）
        List({ space: 0 }) {
          if (this.inputDigits.length > 0) {
            ListItem() {
              Text(this.displayPinyin())
                .fontSize(13)
                .fontColor('#888888')
                .padding({ left: 10, right: 6 })
                .height(40)
            }
          }
          if (this.inputDigits.length === 0 && this.candidates.length === 0) {
            ListItem() {
              Text(this.isChinese ? '九宫格拼音 · 输入数字' : '英文模式 · 按住键滑动选字母')
                .fontSize(14)
                .fontColor('#AAAAAA')
                .padding({ left: 12 })
                .height(40)
            }
          }
          ForEach(this.candidates, (word: string) => {
            ListItem() {
              Text(word)
                .fontSize(16)
                .fontColor('#1A73E8')
                .padding({ left: 14, right: 14 })
                .height(40)
                .onClick(() => this.onCandidateClick(word))
            }
          }, (word: string) => word)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(40)
        .alignListItem(ListItemAlign.Start)
        .backgroundColor('#F5F5F5')
      }

      // 主键盘三行（每行5键）
      ForEach(this.kbRows, (row: Array<[string, string, string]>) => {
        Row() {
          ForEach(row, (key: [string, string, string]) => {
            Column() {
              if (key[1].length > 0) {
                Text(key[0])
                  .fontSize(10)
                  .fontColor('#999999')
                Text(key[1])
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#222222')
                  .margin({ top: 1 })
              } else {
                Text(key[0])
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#222222')
              }
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(key[2] === 'punct' ? '#F9F9F9' : '#FFFFFF')
            .onClick(() => this.onKey(key[2], key[0]))
            .onTouch((event: TouchEvent) => {
              if (key[2] === 'digit' && key[0] >= '2' && key[0] <= '9') {
                this.onDigitTouch(event, key[0]);
              }
            })

          }, (key: [string, string, string]) => key[0])
        }
        .width('100%')
        .layoutWeight(1)
      }, (row: Array<[string, string, string]>) => row[0][0])

      // 底部功能栏：符号 中/英 0
      Row() {
        Text('符号')
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#EEEEEE')
          .onClick(() => this.onSymbol())
        Text(this.isChinese ? '中' : 'A')
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(16)
          .backgroundColor('#EEEEEE')
          .onClick(() => this.onLangSwitch())
        Column() {
          Text('0')
            .fontSize(10)
            .fontColor('#999999')
          Text('空格')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#222222')
            .margin({ top: 1 })
        }
          .layoutWeight(1)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F5F5F5')
          .onTouch((event: TouchEvent) => this.onZeroTouch(event))
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
