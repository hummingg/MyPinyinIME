// 输入法说明页（EntryAbility 主页）
// 提示用户如何在系统中启用本输入法
@Entry
@Component
struct Index {
  build() {
    Column() {
      Text('MyPinyinIME 九宫格拼音输入法')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 60, bottom: 24 })

      Text('启用步骤：')
        .fontSize(16)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 24, bottom: 8 })

      Text('1. 打开 设置 → 系统和更新 → 语言和输入法 → 输入法\n'
        + '2. 开启 MyPinyinIME\n'
        + '3. 在任意文本框长按或切换输入法，选择 MyPinyinIME\n'
        + '4. 点击键盘数字键可上屏"你好"（第一阶段验证）')
        .fontSize(14)
        .fontColor('#444444')
        .lineHeight(24)
        .margin({ left: 24, right: 24 })

      Blank()

      Text('第一阶段：输入法框架验证')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
