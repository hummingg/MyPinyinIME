import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import image from '@ohos.multimedia.image';

const DOMAIN = 0x0000;
const TAG = 'EmojiSavePage';

@Entry
@Component
struct EmojiSavePage {
  @StorageLink('emojiBase64') base64Data: string = '';
  @State toast: string = '';
  @State pixelMap: image.PixelMap | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    if (this.base64Data.length > 0) {
      try {
        const buf = buffer.from(this.base64Data, 'base64').buffer;
        const source = image.createImageSource(buf);
        this.pixelMap = await source.createPixelMap();
        hilog.info(DOMAIN, TAG, 'aboutToAppear createPixelMap ok');
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'aboutToAppear failed: %{public}s', String(e));
      }
    }
  }

  build() {
    Column() {
      Text('表情已生成，点按钮存图库')
        .fontSize(16)
        .margin({ top: 60, bottom: 20 })
      if (this.pixelMap) {
        Image(this.pixelMap)
          .width(200)
          .height(200)
          .backgroundColor('#F0F0F0')
          .margin({ bottom: 30 })
      } else {
        Column()
          .width(200)
          .height(200)
          .backgroundColor('#F0F0F0')
          .margin({ bottom: 30 })
      }
      SaveButton({ text: SaveDescription.SAVE_TO_GALLERY })
        .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
          hilog.info(DOMAIN, TAG, 'SaveButton result=%{public}d', result);
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.saveToGallery();
          }
        })
      if (this.toast.length > 0) {
        Text(this.toast)
          .fontSize(14)
          .fontColor('#1A73E8')
          .margin({ top: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
  }

  private async saveToGallery(): Promise<void> {
    if (this.base64Data.length === 0) {
      this.toast = '图片数据为空';
      return;
    }
    try {
      const buf = buffer.from(this.base64Data, 'base64').buffer;
      const context = getContext(this) as common.UIAbilityContext;
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
      hilog.info(DOMAIN, TAG, 'createAsset uri=%{public}s', uri);
      const dstFile = fs.openSync(uri, fs.OpenMode.WRITE_ONLY);
      fs.writeSync(dstFile.fd, buf);
      fs.closeSync(dstFile);
      this.toast = '已保存到图库';
      hilog.info(DOMAIN, TAG, 'save to gallery ok');
      setTimeout(() => context.terminateSelf(), 800);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'saveToGallery failed: %{public}s', String(e));
      this.toast = '保存失败';
    }
  }
}
