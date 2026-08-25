# MyPinyinIME

HarmonyOS 拼音输入法，基于 InputMethod ExtensionAbility 实现的九宫格拼音输入法。

## 功能

- **拼音输入**：九宫格键盘，T9 滑动选词，候选词无限滑动
- **英文输入**：半角标点，滑动选字母
- **符号面板**：标点 / 数学 / 特殊 / 表情四个分页
- **表情图生成**：文字 + 模板生成表情图，保存到系统图库
  - 内置纯白模板，支持从图库添加自定义模板
  - 文字字号自适应，自动占满图片宽度
  - SaveButton 安全控件授权保存到图库
- **用户词频学习**：持久化存储用户用词偏好

## 技术栈

- HarmonyOS API 12（compatibleSdkVersion 6.1.1(24)）
- ArkTS + ArkUI 声明式 UI
- ExtensionAbility（InputMethod 输入法扩展）
- UIAbility（EntryAbility 主 Ability，代理图库操作）

## 架构

```
entry/src/main/ets/
├── inputmethod/
│   └── InputMethodService.ets    # 输入法扩展服务，面板创建与生命周期
├── pages/
│   ├── KeyboardPage.ets          # 九宫格键盘页面（拼音/英文/符号/表情入口）
│   ├── EmojiGeneratePage.ets     # 表情生成全屏页（模板选择+生成+保存）
│   ├── EmojiSavePage.ets         # 表情保存页（SaveButton 存图库）
│   └── EmojiAddTemplatePage.ets  # 添加自定义模板页（PhotoViewPicker）
├── entryability/
│   └── EntryAbility.ets          # 主 Ability，处理表情相关 action
└── pinyin/
    ├── Dictionary.ets            # 拼音字典与候选词生成
    └── T9.ets                    # T9 按键映射
```

### 表情生成架构说明

inputMethod 扩展进程被 SELinux 隔离（`input_isolate_debug_hap` 域），无法直接访问剪贴板、图库、PhotoViewPicker 等系统服务。因此表情生成采用 EntryAbility 代理方案：

1. 输入法面板点击"生成表情" → `startAbility` 启动 EntryAbility，传递已上屏文字
2. EntryAbility 加载 `EmojiGeneratePage` 全屏页面
3. 用户在页面中选模板、添加自定义模板、保存到图库
4. 保存成功后自动返回聊天应用

## 构建与安装

```bash
# 设置环境变量
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
export NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node

# 构建
node /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

# 安装到设备
hdc install -r entry/build/default/outputs/default/entry-default-signed.hap
```

## 许可

个人项目，未经授权不得商用。