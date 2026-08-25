import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import image from '@ohos.multimedia.image';
import { preferences } from '@kit.ArkData';

const DOMAIN = 0x0000;
const TAG = 'EmojiGeneratePage';
const CANVAS_SIZE = 400;

@Entry
@Component
struct EmojiGeneratePage {
  @StorageLink('emojiText') text: string = '';
  @State toast: string = '';
  @State templateIdx: number = 0;
  @State userTemplates: string[] = [];
  @State pixelMap: image.PixelMap | undefined = undefined;
  @State generating: boolean = false;

  private presetTemplates: string[] = ['tpl_white.png'];
  private canvasCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  async aboutToAppear(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'aboutToAppear text=%{public}s', this.text);
    await this.loadUserTemplates();

  }

  private async loadUserTemplates(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const store = await preferences.getPreferences(context, 'emoji_templates');
      const raw = await store.get('list', '[]') as string;
      const arr: string[] = JSON.parse(raw) as string[];
      this.userTemplates = arr.filter((p: string) => fs.accessSync(p));
      hilog.info(DOMAIN, TAG, 'loadUserTemplates count=%{public}d', this.userTemplates.length);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'loadUserTemplates failed: %{public}s', String(e));
    }
  }

  private async drawEmoji(): Promise<void> {
    const ctx = this.canvasCtx;
    ctx.clearRect(0, 0, CANVAS_SIZE, CANVAS_SIZE);
    try {
      let pm: image.PixelMap | null = null;
      if (this.templateIdx < this.presetTemplates.length) {
        const context = getContext(this) as common.UIAbilityContext;
        const tplFile = this.presetTemplates[this.templateIdx];
        const data = await context.resourceManager.getRawFileContent('emoji_templates/' + tplFile);
        const source = image.createImageSource(data.buffer);
        pm = await source.createPixelMap({ editable: false, desiredSize: { width: CANVAS_SIZE, height: CANVAS_SIZE } });
        source.release();
      } else {
        const userIdx = this.templateIdx - this.presetTemplates.length;
        if (userIdx >= 0 && userIdx < this.userTemplates.length) {
          const source = image.createImageSource(this.userTemplates[userIdx]);
          pm = await source.createPixelMap({ editable: false, desiredSize: { width: CANVAS_SIZE, height: CANVAS_SIZE } });
          source.release();
        }
      }
      if (pm !== null) {
        ctx.drawImage(pm, 0, 0, CANVAS_SIZE, CANVAS_SIZE);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'drawEmoji template failed: %{public}s', String(e));
    }
    if (this.text.length > 0) {
      ctx.fillStyle = '#000000';
      ctx.textAlign = 'center';
      const targetWidth = CANVAS_SIZE - 20;
      const maxWidth = CANVAS_SIZE - 16;
      const maxFontSize = 180;
      const minFontSize = 20;
      let fontSize = 40;
      ctx.font = `${fontSize}px sans-serif`;
      let tw = ctx.measureText(this.text).width;
      while (tw < targetWidth && fontSize < maxFontSize) {
        fontSize += 2;
        ctx.font = `${fontSize}px sans-serif`;
        tw = ctx.measureText(this.text).width;
      }
      while (tw > maxWidth && fontSize > minFontSize) {
        fontSize -= 2;
        ctx.font = `${fontSize}px sans-serif`;
        tw = ctx.measureText(this.text).width;
      }
      const lines: string[] = [];
      if (tw > maxWidth) {
        let cur = '';
        for (let i = 0; i < this.text.length; i++) {
          const test = cur + this.text[i];
          if (ctx.measureText(test).width > maxWidth && cur.length > 0) {
            lines.push(cur);
            cur = this.text[i];
          } else {
            cur = test;
          }
        }
        if (cur.length > 0) lines.push(cur);
      } else {
        lines.push(this.text);
      }
      const lineH = fontSize * 1.3;
      let y = CANVAS_SIZE / 2 - (lines.length * lineH) / 2 + lineH / 2;
      for (const line of lines) {
        ctx.fillText(line, CANVAS_SIZE / 2, y);
        y += lineH;
      }
    }
  }

  private async onGenerate(): Promise<void> {

    try {
      await this.drawEmoji();
      const ctx = this.canvasCtx;
      const dataUrl = ctx.toDataURL('image/png');
      const base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
      const buf = buffer.from(base64, 'base64').buffer;
      const source = image.createImageSource(buf);
      this.pixelMap = await source.createPixelMap();
      source.release();
      hilog.info(DOMAIN, TAG, 'generate ok, pixelMap=%{public}s', this.pixelMap ? 'yes' : 'no');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'generate failed: %{public}s', String(e));
      this.toast = '生成失败';
    }
    this.generating = false;
  }

  private async onSaveToGallery(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onSaveToGallery pixelMap=%{public}s', this.pixelMap ? 'yes' : 'no');
    if (!this.pixelMap) {
      this.toast = '请先生成';
      return;
    }
    try {
      const packer = image.createImagePacker();
      const pngData = await packer.packing(this.pixelMap, { format: 'image/png', quality: 100 });
      packer.release();
      const context = getContext(this) as common.UIAbilityContext;
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
      hilog.info(DOMAIN, TAG, 'createAsset uri=%{public}s', uri);
      const dstFile = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
      fs.writeSync(dstFile.fd, pngData);
      fs.closeSync(dstFile);
      this.toast = '已保存到图库';
      hilog.info(DOMAIN, TAG, 'save ok');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'save failed: %{public}s', String(e));
      this.toast = '保存失败';
    }
  }

  private async onAddTemplate(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({ maxSelectNumber: 1 });
      if (result.photoUris.length === 0) return;
      const srcUri = result.photoUris[0];
      const dir = context.filesDir + '/emoji_templates';
      if (!fs.accessSync(dir)) {
        fs.mkdirSync(dir, true);
      }
      const dstPath = dir + '/user_' + Date.now() + '.png';
      const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(srcUri);
      const dstFile = fs.openSync(dstPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(srcFile.fd, buf);
      fs.writeSync(dstFile.fd, buf);
      fs.closeSync(srcFile);
      fs.closeSync(dstFile);
      const store = await preferences.getPreferences(context, 'emoji_templates');
      const raw = await store.get('list', '[]') as string;
      const arr: string[] = JSON.parse(raw) as string[];
      arr.push(dstPath);
      await store.put('list', JSON.stringify(arr));
      await store.flush();
      await this.loadUserTemplates();
      this.toast = '模板已添加';
      hilog.info(DOMAIN, TAG, 'add template ok');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'add template failed: %{public}s', String(e));
      this.toast = '添加失败';
    }
  }

  private async onDeleteTemplate(idx: number): Promise<void> {
    try {
      const path = this.userTemplates[idx];
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
      const context = getContext(this) as common.UIAbilityContext;
      const store = await preferences.getPreferences(context, 'emoji_templates');
      const raw = await store.get('list', '[]') as string;
      const arr: string[] = JSON.parse(raw) as string[];
      const filtered = arr.filter((p: string) => p !== path);
      await store.put('list', JSON.stringify(filtered));
      await store.flush();
      await this.loadUserTemplates();
      this.templateIdx = 0;
      this.toast = '已删除';
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'delete failed: %{public}s', String(e));
    }
  }

  build() {
    Column() {
      Row() {
        Text('返回')
          .fontSize(16)
          .fontColor('#1A73E8')
          .margin({ left: 16 })
          .onClick(() => (getContext(this) as common.UIAbilityContext).terminateSelf())
        Text('表情生成')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(48)
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FFFFFF')

      List() {
        ListItem() {
          Row() {
            ForEach(this.presetTemplates, (tpl: string, idx: number) => {
              Image($rawfile('emoji_templates/' + tpl))
                .width(48)
                .height(48)
                .border({ width: idx === this.templateIdx ? 2 : 0, color: '#1A73E8' })
                .margin({ left: 4, right: 4 })
                .onClick(() => { this.templateIdx = idx; this.drawEmoji(); })
            }, (tpl: string) => tpl)
            ForEach(this.userTemplates, (path: string, uIdx: number) => {
              Image('file://' + path)
                .width(48)
                .height(48)
                .border({ width: this.presetTemplates.length + uIdx === this.templateIdx ? 2 : 0, color: '#1A73E8' })
                .margin({ left: 4, right: 4 })
                .onClick(() => { this.templateIdx = this.presetTemplates.length + uIdx; this.drawEmoji(); })
                .bindMenu([{ value: '删除', action: (): void => { this.onDeleteTemplate(uIdx); } }])
            }, (path: string) => path)
            Text('+')
              .width(48)
              .height(48)
              .fontSize(24)
              .fontColor('#1A73E8')
              .textAlign(TextAlign.Center)
              .backgroundColor('#F0F0F0')
              .borderRadius(8)
              .margin({ left: 4, right: 4 })
              .onClick(() => this.onAddTemplate())
          }
        }
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(64)
      .padding({ left: 8, right: 8 })

      Canvas(this.canvasCtx)
        .id('emojiCanvas')
        .width(CANVAS_SIZE)
        .height(CANVAS_SIZE)
        .backgroundColor('#F0F0F0')
        .margin({ top: 20 })
        .onReady(() => this.drawEmoji())

      Text(this.text.length > 0 ? this.text : '（无文字）')
        .fontSize(16)
        .fontColor('#666666')
        .margin({ top: 12 })

      Blank()
        .height(20)
      SaveButton({ text: SaveDescription.SAVE_TO_GALLERY })
        .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.onGenerate().then(() => this.onSaveToGallery());
          }
        })

      if (this.toast.length > 0) {
        Text(this.toast)
          .fontSize(14)
          .fontColor('#1A73E8')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Center)
  }
}