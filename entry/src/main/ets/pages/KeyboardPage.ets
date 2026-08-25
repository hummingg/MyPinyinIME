// 九宫格键盘页面（输入法面板内容）
// 布局对齐小艺输入法：
//   ，  1  2  3  删除
//   。  4  5  6  清空
//   ？  7  8  9  ⏎
//   符号 中/英 0 123
import { ImeState } from '../inputmethod/InputMethodService';
import { generateCandidates, recordUserWord, bestPinyin } from '../pinyin/Dictionary';
import { hilog } from '@kit.PerformanceAnalysisKit';
import display from '@ohos.display';
import image from '@ohos.multimedia.image';

import { common, Want } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { preferences } from '@kit.ArkData';
import fs from '@ohos.file.fs';
import { buffer } from '@kit.ArkTS';
import { commonEventManager } from '@kit.BasicServicesKit';

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
  // 符号面板状态
  @State showSymbolPanel: boolean = false;
  @State symbolPage: number = 0;
  // 表情图状态
  @State emojiTemplate: number = 0;
  @State emojiGenerating: boolean = false;
  @State emojiToast: string = '';
  @State userTemplates: string[] = [];
  @State committedText: string = '';  // 已上屏文字
  @State emojiResultPath: string = '';  // 生成图片文件路径
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
  // 符号分页：标点 / 数学 / 特殊，每页30个（6列×5行）
private symbolPages: Array<Array<string>> = [
    ['，', '。', '？', '！', '、', '；', '：', '"', '"', '\'', '\'', '（', '）', '【', '】', '《', '》', '「', '」', '『', '』', '…', '—', '～', '·', '°', '％', '＆', '＊', '＠'],
    ['＋', '－', '×', '÷', '＝', '±', '≈', '≠', '≤', '≥', '√', '∑', '∏', '∞', '∠', '⊥', 'π', '‰', '℃', '∫', '∂', '∇', '∝', '≡', '∈', '∪', '∩', '⊕', '⊗', '∀'],
    ['￥', '＄', '€', '￡', '¥', '§', '★', '○', '●', '◇', '◆', '□', '■', '△', '▲', '※', '→', '←', '↑', '↓', '⇒', '⇔', '∃', '∅', '∴', '∵', '⊕', '⊗', '∩', '∪']
  ];
  private enPunctuation: string[] = [',', '.', '?', '!', ';', ':', '\'', '"', '(', ')', '[', ']', '{', '}', '<', '>', '/', '\\', '|', '-', '_', '+', '=', '*', '&', '%', '$', '#', '@', '~'];
  private symbolPageNames: string[] = ['标点', '数学', '特殊', '表情'];
  private emojiTemplates: string[] = ['tpl_white.png', 'tpl_yellow.png', 'tpl_blue_grad.png', 'tpl_pink_grad.png', 'tpl_dark.png', 'tpl_green_grad.png'];
  private emojiCanvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  private currentSymbolPage(): string[] {
    if (this.symbolPage === 0) {
      return this.isChinese ? this.symbolPages[0] : this.enPunctuation;
    }
    return this.symbolPages[this.symbolPage];
  }


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
    return bestPinyin(this.inputDigits);
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
    recordUserWord(word);
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
    this.candidates = [];
    this.showSymbolPanel = true;
    this.symbolPage = 0;
  }

  private onSymbolClick(s: string): void {
    this.commitText(s);
  }

  private onSymbolBack(): void {
    this.showSymbolPanel = false;
  }

  private onSymbolPageChange(idx: number): void {
    this.symbolPage = idx;
    if (idx === 3) {
      this.loadUserTemplates();
      this.loadCommittedText();
    }
  }

  private async loadUserTemplates(): Promise<void> {
    try {
      const context = getContext(this) as common.Context;
      const dir = context.filesDir + '/emoji_templates';
      if (!fs.accessSync(dir)) {
        this.userTemplates = [];
        return;
      }
      const files = fs.listFileSync(dir);
      this.userTemplates = files.filter((name: string) => name.startsWith('user_')).map((name: string) => dir + '/' + name);
      hilog.info(DOMAIN, TAG, 'loadUserTemplates count=%{public}d', this.userTemplates.length);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'load user templates failed: %{public}s', String(e));
    }
  }

  private async subscribeTemplateAdded(): Promise<void> {
    const subscriber = await commonEventManager.createSubscriber({ events: ['emoji_template_added'] });
    hilog.info(DOMAIN, TAG, 'subscribeTemplateAdded subscriber created');
    commonEventManager.subscribe(subscriber, (err: Object, data: commonEventManager.CommonEventData) => {
      if (err) {
        hilog.error(DOMAIN, TAG, 'subscribe err: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'received emoji_template_added');
      const base64Str = data.data;
      if (!base64Str || base64Str.length === 0) {
        hilog.warn(DOMAIN, TAG, 'no templateBase64 in event');
        return;
      }
      try {
        const context = getContext(this) as common.Context;
        const dir = context.filesDir + '/emoji_templates';
        if (!fs.accessSync(dir)) {
          fs.mkdirSync(dir, true);
        }
        const dstPath = dir + '/user_' + Date.now() + '.png';
        const buf = buffer.from(base64Str, 'base64').buffer;
        const f = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
        fs.writeSync(f.fd, buf);
        fs.closeSync(f);
        hilog.info(DOMAIN, TAG, 'saved template to %{public}s', dstPath);
        this.loadUserTemplates();
        this.emojiToast = '模板已添加';
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'save template failed: %{public}s', String(e));
      }
    });
  }

  private async onEmojiAddTemplate(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onEmojiAddTemplate start');
    try {
      const want: Want = {
        bundleName: 'com.hummingg.mypinyinime',
        abilityName: 'EntryAbility',
        action: 'add_template',
      };
      await ImeState.context?.startAbility(want);
      hilog.info(DOMAIN, TAG, 'add_template startAbility done');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'add template failed: %{public}s', String(e));
      this.emojiToast = '添加失败';
    }
  }

  private async onEmojiDeleteTemplate(idx: number): Promise<void> {
    const userIdx = idx - this.emojiTemplates.length;
    if (userIdx < 0 || userIdx >= this.userTemplates.length) {
      return;
    }
    try {
      const path = this.userTemplates[userIdx];
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
      this.userTemplates.splice(userIdx, 1);
      this.emojiTemplate = 0;
      this.emojiToast = '模板已删除';
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'delete template failed: %{public}s', String(e));
    }
  }

  private async onEmojiCanvasReady(): Promise<void> {
    this.subscribeTemplateAdded();
    await this.loadCommittedText();
    await this.drawEmoji();
  }

  // 从输入框读取已上屏的文字
  private async loadCommittedText(): Promise<void> {
    const client = ImeState.inputClient;
    if (client !== null) {
      try {
        const text = client.getForwardSync(1024);
        this.committedText = text !== null ? text : '';
        hilog.info(DOMAIN, TAG, 'loadCommittedText: %{public}s', this.committedText);
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'loadCommittedText failed: %{public}s', JSON.stringify(e));
        this.committedText = '';
      }
    } else {
      this.committedText = '';
    }
  }

  private async drawEmoji(): Promise<void> {
    const ctx = this.emojiCanvasCtx;
    ctx.clearRect(0, 0, 160, 160);
    try {
      let pixelMap: image.PixelMap | null = null;
      if (this.emojiTemplate < this.emojiTemplates.length) {
        const context = getContext(this) as common.Context;
        const tplFile = this.emojiTemplates[this.emojiTemplate];
        const data = await context.resourceManager.getRawFileContent('emoji_templates/' + tplFile);
        const source = image.createImageSource(data.buffer);
        const opts: image.DecodingOptions = {
          editable: false,
          desiredSize: { width: 160, height: 160 }
        };
        pixelMap = await source.createPixelMap(opts);
        source.release();
      } else {
        const userIdx = this.emojiTemplate - this.emojiTemplates.length;
        if (userIdx >= 0 && userIdx < this.userTemplates.length) {
          const path = this.userTemplates[userIdx];
          const source = image.createImageSource(path);
          const opts: image.DecodingOptions = {
            editable: false,
            desiredSize: { width: 160, height: 160 }
          };
          pixelMap = await source.createPixelMap(opts);
          source.release();
        }
      }
      if (pixelMap !== null) {
        ctx.drawImage(pixelMap, 0, 0, 160, 160);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'drawEmoji template failed: %{public}s', JSON.stringify(e));
    }
    if (this.committedText.length > 0) {
      ctx.fillStyle = '#000000';
      ctx.font = '20px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(this.committedText, 80, 90);
    }
  }

  private async onEmojiGenerate(): Promise<void> {
    this.emojiGenerating = true;
    this.emojiToast = '生成中...';
    try {
      hilog.info(DOMAIN, TAG, 'onEmojiGenerate start, committedText=%{public}s', this.committedText);
      await this.loadCommittedText();
      hilog.info(DOMAIN, TAG, 'after loadCommittedText, text=%{public}s', this.committedText);
      await this.drawEmoji();
      hilog.info(DOMAIN, TAG, 'after drawEmoji');

      // 从 Canvas 获取像素数据并创建 PixelMap
      const ctx = this.emojiCanvasCtx;
      const imageData = ctx.getImageData(0, 0, 160, 160);
      const imgW = imageData.width;
      const imgH = imageData.height;
      hilog.info(DOMAIN, TAG, 'after getImageData, w=%{public}d h=%{public}d size=%{public}d', imgW, imgH, imageData.data.byteLength);

      const indepBuf = new ArrayBuffer(imageData.data.byteLength);
      new Uint8Array(indepBuf).set(imageData.data);
      const opts: image.InitializationOptions = {
        editable: true,
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        size: { width: imgW, height: imgH }
      };
      const pixelMap = await image.createPixelMap(indepBuf, opts);
      hilog.info(DOMAIN, TAG, 'after createPixelMap');

      // 编码为 PNG 并保存到应用沙盒
      const imagePacker = image.createImagePacker();
      const packOpts: image.PackingOption = { format: 'image/png', quality: 100 };
      const pngData = await imagePacker.packing(pixelMap, packOpts);
      imagePacker.release();
      pixelMap.release();
      hilog.info(DOMAIN, TAG, 'after packing, size=%{public}d', pngData.byteLength);

      const context = getContext(this) as common.Context;
      const outDir = context.filesDir + '/emoji_output';
      if (!fs.accessSync(outDir)) {
        fs.mkdirSync(outDir, true);
      }
      const outPath = outDir + '/emoji_' + Date.now() + '.png';
      const f = fs.openSync(outPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.writeSync(f.fd, pngData);
      fs.closeSync(f);
      hilog.info(DOMAIN, TAG, 'after save file: %{public}s', outPath);
      this.emojiResultPath = outPath;

    } catch (e) {
      hilog.error(DOMAIN, TAG, 'emoji generate failed: %{public}s', String(e));
      this.emojiToast = '生成失败';
    }
    this.emojiGenerating = false;
  }

  // SaveButton 点击后临时授权，把沙盒 PNG 写入系统图库
  private async saveEmojiToGallery(): Promise<void> {
    if (this.emojiResultPath.length === 0 || !fs.accessSync(this.emojiResultPath)) {
      this.emojiToast = '请先生成图片';
      return;
    }
    try {
      const context = getContext(this) as common.Context;
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
      hilog.info(DOMAIN, TAG, 'createAsset uri=%{public}s', uri);
      const srcFile = fs.openSync(this.emojiResultPath, fs.OpenMode.READ_ONLY);
      const dstFile = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
      const buf = new ArrayBuffer(4096);
      let readLen = fs.readSync(srcFile.fd, buf);
      while (readLen > 0) {
        fs.writeSync(dstFile.fd, buf, { length: readLen });
        readLen = fs.readSync(srcFile.fd, buf);
      }
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);
      this.emojiToast = '已保存到图库，可在聊天里发送';
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveEmojiToGallery failed: %{public}s', String(e));
      this.emojiToast = '保存图库失败';
    }
  }

  // 生成图片后启动主 EntryAbility 代理写剪贴板（扩展进程被 SELinux 隔离无法直接写）
  private async onEmojiGenerateAndCopy(): Promise<void> {
    await this.loadCommittedText();
    if (this.committedText.length === 0) {
      return;
    }
    try {
      const want: Want = {
        bundleName: 'com.hummingg.mypinyinime',
        abilityName: 'EntryAbility',
        action: 'generate_emoji',
        parameters: { emojiText: this.committedText }
      };
      await ImeState.context?.startAbility(want);
      this.clearAllInputText();
      this.committedText = '';
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'startAbility failed: %{public}s', String(e));
    }
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

      if (!this.showSymbolPanel) {
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
      } else {
        // 符号面板：分页标签 + 6×5网格
        Row() {
          ForEach(this.symbolPageNames, (name: string, idx: number) => {
            Text(name)
              .layoutWeight(1)
              .height(44)
              .textAlign(TextAlign.Center)
              .fontSize(15)
              .fontColor(idx === this.symbolPage ? '#1A73E8' : '#666666')
              .backgroundColor(idx === this.symbolPage ? '#E8F0FE' : '#EEEEEE')
              .onClick(() => this.onSymbolPageChange(idx))
          }, (name: string, idx: number) => `${name}${idx}`)
          Text('返回')
            .layoutWeight(1)
            .height(44)
            .textAlign(TextAlign.Center)
            .fontSize(15)
            .backgroundColor('#EEEEEE')
            .onClick(() => this.onSymbolBack())
        }
        .width('100%')
        .height(44)

        if (this.symbolPage < 3) {
          Grid() {
            ForEach(this.currentSymbolPage(), (s: string, idx: number) => {
              GridItem() {
                Text(s)
                  .fontSize(20)
                  .fontColor('#222222')
                  .textAlign(TextAlign.Center)
              }
              .backgroundColor('#FFFFFF')
              .onClick(() => this.onSymbolClick(s))
            }, (s: string, idx: number) => `${s}${idx}`)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr 1fr 1fr')
          .width('100%')
          .layoutWeight(1)
        } else {
          Column() {
            Text(this.committedText.length > 0 ? this.committedText : '（请先输入文字）')
              .height(44)
              .fontSize(16)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .margin({ bottom: 16 })
            Button('生成表情')
              .width(160)
              .height(48)
              .fontSize(16)
              .enabled(this.committedText.length > 0)
              .onClick(() => this.onEmojiGenerateAndCopy())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
