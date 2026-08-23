// 输入法扩展服务（InputMethodExtensionAbility）
// 第一阶段：验证 IME Kit 接入、面板创建与测试上屏通路
import { InputMethodExtensionAbility, inputMethodEngine } from '@kit.IMEKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import display from '@ohos.display';
import { initRimeDict } from '../pinyin/Dictionary';

const DOMAIN = 0x0500;
const TAG = 'InputMethodService';

// 输入法运行时状态，供键盘页 KeyboardPage 调用提交/删除
// 扩展与面板页面同处一个进程，通过类静态字段共享引用
export class ImeState {
  static inputClient: inputMethodEngine.InputClient | null = null;
  static kbController: inputMethodEngine.KeyboardController | null = null;
  static panel: inputMethodEngine.Panel | null = null;
}

export default class InputMethodService extends InputMethodExtensionAbility {
  private ability: inputMethodEngine.InputMethodAbility = inputMethodEngine.getInputMethodAbility();

  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'onCreate');

    // 后台加载 rime 词库（不阻塞 onCreate）
    initRimeDict(this.context);

    // 输入开始：保存客户端引用，创建并显示键盘面板
    this.ability.on('inputStart', (kbController: inputMethodEngine.KeyboardController,
      inputClient: inputMethodEngine.InputClient) => {
      hilog.info(DOMAIN, TAG, 'inputStart');
      ImeState.kbController = kbController;
      ImeState.inputClient = inputClient;
      this.showPanel();
    });

    // 输入结束：隐藏面板
    this.ability.on('inputStop', () => {
      hilog.info(DOMAIN, TAG, 'inputStop');
      this.hidePanel();
    });

    this.ability.on('keyboardShow', () => {
      hilog.info(DOMAIN, TAG, 'keyboardShow');
    });
    this.ability.on('keyboardHide', () => {
      hilog.info(DOMAIN, TAG, 'keyboardHide');
    });
  }

  // 创建（若未创建）并显示软键盘面板
  private async showPanel(): Promise<void> {
    try {
      if (ImeState.panel === null) {
        const panelInfo: inputMethodEngine.PanelInfo = {
          type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
          flag: inputMethodEngine.PanelFlag.FLG_FIXED
        };
        ImeState.panel = await this.ability.createPanel(this.context, panelInfo);
        await ImeState.panel.setUiContent('pages/KeyboardPage');
        const disp = display.getDefaultDisplaySync();
        const panelWidth = disp.width;
        const panelHeight = Math.floor(disp.height * 0.45);
        await ImeState.panel.resize(panelWidth, panelHeight);
        hilog.info(DOMAIN, TAG, 'panel created, resized to %{public}d x %{public}d', panelWidth, panelHeight);
      }
      await ImeState.panel.show();
      hilog.info(DOMAIN, TAG, 'panel shown');
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'showPanel failed: %{public}s', JSON.stringify(e));
    }
  }

  // 隐藏软键盘面板
  private async hidePanel(): Promise<void> {
    try {
      if (ImeState.panel !== null) {
        await ImeState.panel.hide();
        hilog.info(DOMAIN, TAG, 'panel hidden');
      }
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'hidePanel failed: %{public}s', JSON.stringify(e));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
    // 销毁面板（异步，不阻塞 onDestroy）
    if (ImeState.panel !== null) {
      this.ability.destroyPanel(ImeState.panel).then(() => {
        hilog.info(DOMAIN, TAG, 'panel destroyed');
      }).catch((e: object) => {
        hilog.error(DOMAIN, TAG, 'destroyPanel failed: %{public}s', JSON.stringify(e));
      });
    }
    ImeState.inputClient = null;
    ImeState.kbController = null;
    ImeState.panel = null;
  }
}