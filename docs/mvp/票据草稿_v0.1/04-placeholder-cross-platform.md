## Parent

Part of [Spec #1](https://github.com/Bacsonlx/NineTripodCauldrons/issues/1)。

## What to build

使用者在Apple Silicon Mac与Windows x64各至少一台实机解压运行占位版ZIP，完成房间操作；窗口缩放留边后仍瞄得准，必要资源出错时看到明确失败。交付阶段A的真实双平台功能结果，作为开始代表美术制作的关口。

沿用父Spec的TypeScript／Phaser WebGL／Electron／Forge基线；此MVP保持固定等距2.5D、单屏二维平面，不新增骨骼运行时或逐帧IPC。阶段A先用占位素材，阶段B才验证代表画风。所有结果须标明实际执行平台，未测试不得记通过。

覆盖父规格用户故事：8, 35, 38, 39, 40, 42。覆盖验收：AC-01、AC-02、AC-03、AC-04、AC-05、AC-06、AC-07、AC-08、AC-09、AC-10、AC-11、AC-12、AC-13、AC-14、AC-15、AC-16、AC-19；引用用例有拆分时以本票验收条目明确的部分为准。相关资产：MVP-A01、MVP-A02、MVP-A03、MVP-A04、MVP-A05、MVP-A06、MVP-A07、MVP-A08、MVP-A09、MVP-A10、MVP-A11。

## Acceptance criteria

- [ ] 沿用Electron、TypeScript、Phaser WebGL和Forge／Webpack；产出两端ZIP并在对应实机解压运行，不以开发服务、构建成功或单Mac结果代替Windows。
- [ ] 1280×720、1920×1080及带留边窗口下准星、弓口与弹道映射正确；黑边不发箭，UI不遮人物、靶与弹道，调整窗口不改变房间布局。
- [ ] 必要资源加载完成前不接受操作；模拟资源缺失有明确错误，不进入空白或半失效房间；实际ZIP包含所需资源并可离线加载。
- [ ] 两端分别执行AC-01至AC-16的占位功能及AC-19占位产物部分，修复本阶段发现的缩放、焦点、资源加载和平台差异，不跳过已定行为。
- [ ] 记录应用版本、修订标识、ZIP名称、系统、CPU架构、CPU／GPU、内存、缩放与显示配置、实际玩法参数、用例结论和操作证据；Windows设备细节在实测时补录。
- [ ] 任一端缺实机或未通过保持本票未完成；不虚构测试记录。此票只完成占位功能，不声称动态画风或最终性能通过。
- [ ] 不新增安装向导、发行签名、Intel Mac／Windows ARM支持、CI平台或手柄作为本票强制内容；只做当前闭环必需修改。

## Blocked by

- T3（草稿编号，获批发布时替换为真实Issue并建立原生阻塞关系）
