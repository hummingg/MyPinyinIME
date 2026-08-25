import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';
import { commonEventManager } from '@kit.BasicServicesKit';
import image from '@ohos.multimedia.image';

const DOMAIN = 0x0000;
const TAG = 'EmojiAddTplPage';

@Entry
@Component
struct EmojiAddTemplatePage {
  @State toast: string = '正在打开图库...';

  async aboutToAppear(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.BaseSelectOptions = { maxSelectNumber: 1 };
      const result = await picker.select(options);
      hilog.info(DOMAIN, TAG, 'picker count=%{public}d', result.photoUris.length);
      if (result.photoUris.length === 0) {
        context.terminateSelf();
        return;
      }
      const srcUri = result.photoUris[0];
      const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(srcUri);
      const fileBuf = new ArrayBuffer(stat.size);
      fs.readSync(srcFile.fd, fileBuf);
      fs.closeSync(srcFile);

      const source = image.createImageSource(fileBuf);
      const pm = await source.createPixelMap({ editable: true, desiredSize: { width: 160, height: 160 } });
      source.release();
      const packer = image.createImagePacker();
      const packed = await packer.packing(pm, { format: 'image/png', quality: 80 });
      packer.release();
      pm.release();
      const base64Str = buffer.from(packed).toString('base64');
      hilog.info(DOMAIN, TAG, 'packed base64 len=%{public}d', base64Str.length);

      commonEventManager.publish('emoji_template_added', { data: base64Str }, (err: Object) => {
        if (err) {
          hilog.error(DOMAIN, TAG, 'publish failed: %{public}s', JSON.stringify(err));
        } else {
          hilog.info(DOMAIN, TAG, 'publish ok');
        }
        context.terminateSelf();
      });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'failed: %{public}s', String(e));
      this.toast = '添加失败';
      setTimeout(() => (getContext(this) as common.UIAbilityContext).terminateSelf(), 1000);
    }
  }

  build() {
    Column() {
      Text(this.toast)
        .fontSize(16)
        .margin({ top: 120 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
  }
}
