// 九宫格键盘页面（输入法面板内容）
// 布局对齐小艺输入法：
//   ，  1  2  3  删除
//   。  4  5  6  清空
//   ？  7  8  9  ⏎
//   符号 中/英 0 123
import { ImeState } from '../inputmethod/InputMethodService';
import { generateCandidates } from '../pinyin/Dictionary';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0500;
const TAG = 'KeyboardPage';

@Entry
@Component
struct KeyboardPage {
  @State isChinese: boolean = true;
  @State inputDigits: string = '';
  @State candidates: string[] = [];
  private englishFirst: Record<string, string> = {
    '2': 'a', '3': 'd', '4': 'g', '5': 'j', '6': 'm', '7': 'p', '8': 't', '9': 'w'
  };
  // 主键盘三行：[label, sub, action]
  private kbRows: Array<Array<[string, string, string]>> = [
    [['，', '', 'punct'], ['1', '', 'digit'], ['2', 'abc', 'digit'], ['3', 'def', 'digit'], ['删除', '', 'delete']],
    [['。', '', 'punct'], ['4', 'ghi', 'digit'], ['5', 'jkl', 'digit'], ['6', 'mno', 'digit'], ['清空', '', 'clear']],
    [['？', '', 'punct'], ['7', 'pqrs', 'digit'], ['8', 'tuv', 'digit'], ['9', 'wxyz', 'digit'], ['⏎', '', 'enter']]
  ];
  private symbols: string[] = ['～', '·', '°', '±', '×', '÷', '√', '≈', '≠', '≤', '≥', '《', '》', '「', '」', '『', '』', '〔', '〕', '‰', '℃', '￥', '＄', '€', '§', '★', '○', '●', '◇', '◆', '□', '■', '△', '▲', '※', '→', '←', '↑', '↓', '⇒', '⇔', '∈', '∏', '∑', '∞', '∠', '⊥', '⊕', '⊗'];

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
      // 先尝试获取光标前文本长度，失败则用固定上限循环退格
      let len = 0;
      try {
        const text = client.getForwardSync(1024);
        len = text.length;
        hilog.info(DOMAIN, TAG, 'clearAllInputText getForwardSync len=%{public}d', len);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'clearAllInputText getForwardSync failed: %{public}s', JSON.stringify(e));
      }
      if (len <= 0) {
        len = 64; // 获取失败时退格上限
      }
      let deleted = 0;
      for (let i = 0; i < len; i++) {
        try {
          client.deleteForwardSync(1);
          deleted++;
        } catch (e) {
          break; // 没有更多字符可删
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
      } else {
        this.commitText(d);
      }
    } else {
      if (d >= '2' && d <= '9') {
        const ch = this.englishFirst[d];
        if (ch !== undefined) {
          this.commitText(ch);
        }
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

  private onSymbol(): void {
    this.inputDigits = '';
    this.candidates = this.symbols.slice();
  }

  private onLangSwitch(): void {
    this.isChinese = !this.isChinese;
    this.inputDigits = '';
    this.candidates = [];
  }

  private onNumSwitch(): void {
    this.inputDigits = '';
    this.candidates = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
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
            Text(this.isChinese ? '九宫格拼音 · 输入数字' : '英文模式')
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

      // 主键盘三行（每行5键）
      ForEach(this.kbRows, (row: Array<[string, string, string]>) => {
        Row() {
          ForEach(row, (key: [string, string, string]) => {
            Column() {
              Text(key[0])
                .fontSize(key[2] === 'punct' || key[2] === 'delete' || key[2] === 'clear' || key[2] === 'enter' ? 18 : 22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#222222')
              if (key[1].length > 0) {
                Text(key[1])
                  .fontSize(10)
                  .fontColor('#999999')
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor(key[2] === 'punct' ? '#F9F9F9' : '#FFFFFF')
            .onClick(() => this.onKey(key[2], key[0]))
          }, (key: [string, string, string]) => key[0])
        }
        .width('100%')
        .layoutWeight(1)
      }, (row: Array<[string, string, string]>) => row[0][0])

      // 底部功能栏：符号 中/英 0 123
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
        Text('0')
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#F5F5F5')
          .onClick(() => this.onSpace())
        Text('123')
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#EEEEEE')
          .onClick(() => this.onNumSwitch())
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
