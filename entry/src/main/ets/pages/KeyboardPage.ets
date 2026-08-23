// 九宫格键盘页面（输入法面板内容）
// 第一阶段：点击数字键提交测试文字"你好"验证上屏
import { ImeState } from '../inputmethod/InputMethodService';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0500;
const TAG = 'KeyboardPage';

@Entry
@Component
struct KeyboardPage {
  // 九宫格按键：[主字符, 副字符]
  private keys: Array<[string, string]> = [
    ['1', ''], ['2', 'abc'], ['3', 'def'],
    ['4', 'ghi'], ['5', 'jkl'], ['6', 'mno'],
    ['7', 'pqrs'], ['8', 'tuv'], ['9', 'wxyz'],
    ['*', ''], ['0', ''], ['#', '']
  ];

  // 提交文本到当前输入框
  private commitText(text: string): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      client.insertText(text).then((ok: boolean) => {
        hilog.info(DOMAIN, TAG, 'insertText result: %{public}s', String(ok));
      }).catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'insertText failed: %{public}s', JSON.stringify(e));
      });
    } else {
      hilog.warn(DOMAIN, TAG, 'inputClient is null');
    }
  }

  // 向前删除一个字符
  private deleteBackward(): void {
    const client = ImeState.inputClient;
    if (client !== null) {
      client.deleteBackward(1).catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'deleteBackward failed: %{public}s', JSON.stringify(e));
      });
    }
  }

  build() {
    Column() {
      // 顶部候选栏（第一阶段占位）
      Text('测试输入法 · 点数字键上屏"你好"')
        .width('100%')
        .height(44)
        .fontSize(14)
        .textAlign(TextAlign.Center)
        .fontColor('#333333')
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
            .onClick(() => this.commitText('你好'))
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
        Text('中/英')
          .width('25%')
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#EEEEEE')
        Text('空格')
          .width('50%')
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#F5F5F5')
          .onClick(() => this.commitText(' '))
        Text('删除')
          .width('25%')
          .height(44)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .backgroundColor('#EEEEEE')
          .onClick(() => this.deleteBackward())
      }
      .width('100%')
      .height(44)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}