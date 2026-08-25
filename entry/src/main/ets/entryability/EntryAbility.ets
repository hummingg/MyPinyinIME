import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  private emojiBase64: string = '';
  private emojiText: string = '';
  private action: string = '';
  private windowStage: window.WindowStage | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setColorMode failed: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'onCreate action=%{public}s', want.action ?? '');
    this.handleEmojiWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onNewWant action=%{public}s', want.action ?? '');
    this.handleEmojiWant(want);
    if (this.windowStage !== null) {
      this.loadPage(this.windowStage);
    }
  }

  private loadPage(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'loadPage action=%{public}s', this.action);
    if (this.action === 'add_template') {
      this.action = '';
      windowStage.loadContent('pages/EmojiAddTemplatePage', (err) => {
        if (err.code) { hilog.error(DOMAIN, TAG, 'load EmojiAddTemplatePage failed: %{public}s', JSON.stringify(err)); }
      });
    } else if (this.action === 'generate_emoji') {
      this.action = '';
      AppStorage.setOrCreate('emojiText', this.emojiText);
      this.emojiText = '';
      windowStage.loadContent('pages/EmojiGeneratePage', (err) => {
        if (err.code) { hilog.error(DOMAIN, TAG, 'load EmojiGeneratePage failed: %{public}s', JSON.stringify(err)); }
      });
    } else if (this.emojiBase64.length > 0) {
      AppStorage.setOrCreate('emojiBase64', this.emojiBase64);
      this.emojiBase64 = '';
      windowStage.loadContent('pages/EmojiSavePage', (err) => {
        if (err.code) { hilog.error(DOMAIN, TAG, 'load EmojiSavePage failed: %{public}s', JSON.stringify(err)); }
      });
    } else {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) { hilog.error(DOMAIN, TAG, 'load Index failed: %{public}s', JSON.stringify(err)); }
      });
    }
  }

  private handleEmojiWant(want: Want): void {
    this.action = want.action ?? '';
    if (want.action === 'copy_emoji' && want.parameters) {
      const b64 = want.parameters.emojiBase64 as string;
      if (b64 && b64.length > 0) {
        this.emojiBase64 = b64;
      }
    } else if (want.action === 'generate_emoji' && want.parameters) {
      const t = want.parameters.emojiText as string;
      if (t && t.length > 0) {
        this.emojiText = t;
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStage = windowStage;
    this.loadPage(windowStage);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'onBackground');
  }
}
