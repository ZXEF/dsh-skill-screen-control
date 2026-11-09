## 0. 硬性前提（先确认，否则一定失败）

1. **当前模型必须支持图像输入**。若 `read_image` 报 `model "xxx" does not declare image input`，本 skill 不可用：要么切到视觉模型，要么降级用 §9 的 OCR 方案（只能读文字）。
2. 需要能执行 PowerShell 且允许模拟输入（本机桌面会话）。

---

## 1. 每次调用 PowerShell 的固定开头（必须）

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

**每个新的 pwsh 进程都要加**，否则 `& script.ps1` 会报「禁止运行脚本」。

---

## 2. 文件

| 文件 | 作用 |
|---|---|
| `scripts/ui.ps1` | 核心：截图、移动/单击/右键/双击、拖动、滚轮、按键、组合键/修饰键点击、按住、打字、粘贴、列窗口、激活窗口 |
| `scripts/zoom.ps1` | 裁剪 + 放大指定区域（读小字、认小图标），并打印坐标映射公式 |
| `scripts/calibrate.ps1` | 坐标标定：`HoverDiff`（悬停差分）/ `BorderScan`（边框颜色扫描），直接给出 bbox 与中心点 |
| `scripts/waitchange.ps1` | 等待画面变化（加载完成 / 弹窗出现 / 顾客进店），带超时 |
| `scripts/think.ps1` | 写思考流：一行更新浮窗头部状态，一行追加带时间戳的日志 |
| `scripts/start-overlay.ps1` / `scripts/stop-overlay.ps1` | 启动 / 关闭浮窗，用 pid 文件管理，不用记 job id |
| `scripts/overlay.ps1` | 浮窗本体（一般由 start-overlay 调用） |

以下路径都相对本 skill 目录（`scripts/ui.ps1`）。

---

## 3. 看：截图

```powershell
& "scripts\ui.ps1" -Shot -Out "$env:TEMP\sc\s.png"
# 输出: saved ...\s.png 1920x1080
```

然后 `read_image` 读该文件。

### 坐标换算（最高频错误，务必做）
- 截图是**物理分辨率**（如 1920×1080）。
- `read_image` 给你的常是**缩小预览**，并在返回里注明 `request preview 1708x961px`。
- 你在预览上量出的坐标，必须换算回物理坐标：

```
x_real = x_prev * realW / prevW
y_real = y_prev * realH / prevH
```

不换算 → 所有点击整体偏移，表现为「点了没反应 / 点到了旁边」。

### 坐标标定（别靠目测，实测误差能到 30–60px）

**方法 1：悬停差分**（最通用，适用于有 hover 高亮的界面）
在同一个 x、两个不同 y 各停一次光标，各截一张图，做像素差分，差出来的包围盒就是按钮的真实位置：

```powershell
& "scripts\ui.ps1" -Move -X 800 -Y 400 ; & "scripts\ui.ps1" -Shot -Out "$env:TEMP\sc\a.png"
& "scripts\ui.ps1" -Move -X 800 -Y 560 ; & "scripts\ui.ps1" -Shot -Out "$env:TEMP\sc\b.png"
# 然后在 PowerShell 里比对 a/b 两张图，取差异像素的 bounding box（x/y 范围）
```

**方法 2：边框颜色扫描**（按钮有描边时最快）
遍历目标区域，统计满足条件（如青色边 `G>140 and B>140 and R<190`）的像素，求 bbox 取中心。

**方法 3：1:1 裁剪再量**
从**原始 1920×1080 截图**里裁一块（不缩放或整倍放大），用已知偏移换算，避免在缩略预览上量。

> 三种方法都要记住：**先扫描出坐标，再点击**，不要「大概在中间」。

### 看不清就裁剪放大
用 System.Drawing 裁一块、最近邻放大 3–6 倍，再 `read_image`：

```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile("$env:TEMP\sc\s.png")
$rect = New-Object System.Drawing.Rectangle 660, 450, 500, 280
$crop = New-Object System.Drawing.Bitmap 500, 280
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($img, (New-Object System.Drawing.Rectangle 0,0,500,280), $rect, [System.Drawing.GraphicsUnit]::Pixel)
$big = New-Object System.Drawing.Bitmap 1500, 840
$g2 = [System.Drawing.Graphics]::FromImage($big)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g2.DrawImage($crop, 0, 0, 1500, 840)
$big.Save("$env:TEMP\sc\crop.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $g2.Dispose(); $crop.Dispose(); $big.Dispose(); $img.Dispose()
```

---

## 4. 动：输入

```powershell
# 指针
& "scripts\ui.ps1" -Move   -X 800 -Y 400
& "scripts\ui.ps1" -Click  -X 800 -Y 400
& "scripts\ui.ps1" -RightClick -X 800 -Y 400
& "scripts\ui.ps1" -DoubleClick -X 800 -Y 400
& "scripts\ui.ps1" -Drag   -X 900 -Y 500 -X2 300 -Y2 500   # 拖地图/滑块
& "scripts\ui.ps1" -Wheel 120                               # 上滚
& "scripts\ui.ps1" -Wheel -120                              # 下滚

# 键盘
& "scripts\ui.ps1" -PressKey SPACE
& "scripts\ui.ps1" -HoldKey W -HoldMs 1500                  # 按住走路
& "scripts\ui.ps1" -Combo 'SHIFT,W' -HoldMs 3000            # 同时按住=冲刺
& "scripts\ui.ps1" -Type 'hello'                            # 仅 ASCII
& "scripts\ui.ps1" -Paste '中文文本'                        # 剪贴板 + Ctrl+V

# 组合键 + 点击（软件/游戏里常见的 Ctrl+点击、Shift+点击）
& "scripts\ui.ps1" -Modifier CTRL  -Click -X 800 -Y 400
& "scripts\ui.ps1" -Modifier SHIFT -Click -X 800 -Y 400
& "scripts\ui.ps1" -Modifier CTRL  -Drag  -X 900 -Y 500 -X2 300 -Y2 500
```

支持的键名：`A`–`Z`、`0`–`9`、`SPACE TAB ESC ENTER BACKSPACE DELETE SHIFT CTRL ALT LEFT UP RIGHT DOWN F1`–`F12`。

---

## 5. 焦点（第二大坑）

- `SetForegroundWindow` 常因 **Windows 前台锁** 失败，静默返回 false。
- 用内置的激活逻辑（AppActivate + 校验 + ALT 解锁 + 重试）：

```powershell
& "scripts\ui.ps1" -Activate '原神'
# 输出: activate '原神' ok=True title='原神'
```

- **每一批动作前都重新激活**：用户切到别的窗口、或别的程序抢焦点，会让按键发给错误窗口。典型症状：截图里显示的是别的程序，或「按了没反应」。
- 排查工具：`-Active`（打印当前前台窗口）、`-Windows`（列出所有有标题的窗口）。

---

## 6. 浮窗：思考流

两个 **UTF-8 数据文件** + 一个后台窗口进程。

```powershell
# 一行启动浮窗（默认数据文件在 %TEMP%\screen-control\）
& "scripts\start-overlay.ps1" -State "● 已接管控制 · 思考流"

# 每步追加（自动加 [HH:mm] 时间戳；文字随意写，文件是 UTF-8）
& "scripts\think.ps1" -Lines "看  屏幕上是游戏主界面","想  点新游戏","动  点击(1207,511)"

# 交还控制权
& "scripts\think.ps1" -State "● 已交还控制"

# 关闭浮窗
& "scripts\stop-overlay.ps1"
```

`start-overlay.ps1` 会把进程号写进 `%TEMP%\screen-control\overlay.pid`，所以**不需要记 job id**；`stop-overlay.ps1` 读该文件杀进程并清理，重复调用也安全。

浮窗特性：置顶（TopMost）、鼠标穿透（`WS_EX_TRANSPARENT`，不会挡住点击）、半透明、只显示日志尾部 N 行、可调 `-X -Y -W -H -TailLines`、可调 `Opacity`（改脚本）。挡住界面时换位置即可。

---

## 7. 可靠性纪律（照做才不会翻车）

1. **每轮只做 1–3 个动作，然后必须截图验证**。点击会落空、方向会走反。
2. **用可观测信号判定**：距离读数、血量、金币、文字、高亮/选中状态，而不是「我觉得点到了」。
3. **记录试错**：例如「距离 200 → 214m，说明走反了」，立刻反向；不要盲目重复。
4. **坐标不确定就先裁剪放大**再量，别猜。
5. **结束清理**：kill 浮窗后台 job；光标移到屏幕角落；把窗口恢复成用户能直接接手的状态。

---

## 8. 已知坑（务必读）

| 坑 | 现象 | 对策 |
|---|---|---|
| PS 5.1 按 ANSI 读 .ps1 | 脚本里有中文时报「字符串缺少终止符」 | **脚本保持纯 ASCII**；中文只放数据文件，用 `[IO.File]::ReadAllText(path, [Text.Encoding]::UTF8)` 读 |
| Raw Input | 游戏/部分程序忽略合成滚轮，缩放无效 | 滚轮多半没救；改用拖动，或让用户手动缩放 |
| 前台锁 | `SetForegroundWindow` 返回 false，输入发错窗口 | 用 `-Activate`；每批动作前重激活 |
| 中文打字 | `-Type` 打不出中文 | 用 `-Paste` |
| 全屏独占 | 截图黑屏 / 浮窗被盖住 | 让用户改「无边框窗口」模式 |
| 多显示器 | 只截主屏 | 需要副屏时改脚本用 `Screen.AllScreens` |
| 目测预览坐标 | 误差可达 30–60px，点空/点偏 | 用 §3 的三种标定法，别猜 |
| 双击 | 容易误触发设置/面板 | 优先单击；需要「打开」时先单击看提示再决定 |
| 模态文档/弹窗 | 右上角 X 很小，容易点空 | 先试 **ESC**（多数模态框都响应），再退而点 X |
| 拖拽不生效 | 目标程序可能不把合成拖拽当拖拽 | 改用 `-Modifier CTRL -Click`（很多程序支持 Ctrl+点击 直接转移） |
| 反作弊 | 可能违反游戏协议 | 本方案是 OS 级模拟输入（不注入进程、不改内存）；不要用于挂机/刷资源 |

---

## 9. 降级：没有视觉模型时用 Windows OCR

只能拿到文字与坐标，读不了图形界面元素：

```powershell
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine,Windows.Media.Ocr,ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]

function Await($t, $rt) {
  $m = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
  $t2 = $m.MakeGenericMethod($rt).Invoke($null, @($t)); $t2.Wait(); $t2.Result
}

$file  = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path)) ([Windows.Storage.StorageFile])
$strm  = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$dec   = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($strm)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bmp   = Await ($dec.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$eng   = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$res   = Await ($eng.RecognizeAsync($bmp)) ([Windows.Media.Ocr.OcrResult])

foreach ($line in $res.Lines) {
  $w = @($line.Words | ForEach-Object { $_.Text }) -join ' '
  $r = $line.Words[0].BoundingRect
  "{0}`t@({1},{2})" -f $w, [int]$r.X, [int]$r.Y
}
```

---

## 10. 最小闭环示例

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
$ui = "scripts\ui.ps1"
& $ui -Activate '记事本'
& $ui -Shot -Out "$env:TEMP\sc\1.png"          # 然后 read_image 读 1.png
# ... 根据画面算出物理坐标 (x,y) ...
& $ui -Click -X $x -Y $y
Start-Sleep -Milliseconds 600
& $ui -Shot -Out "$env:TEMP\sc\2.png"          # 再 read_image 验证结果
```

---

## 11. 实战验证记录（2026-11 实测）

**环境**：Windows 11 x64，单屏 1920×1080，PowerShell 5.1，进程为管理员权限。

**已验证可用的操作**：截图、单击/右键/双击、拖动、滚轮、按住按键、组合键、Ctrl+点击、窗口枚举与激活、UTF-8 中文浮窗。

**已验证的场景**：
- 3D 动作游戏（原神）：走路/跳跃/技能/地图拖动/传送
- 2D 像素经营游戏（Probably Stolen）：菜单点击、Ctrl+点击转移物品、右键上下文菜单、拖拽批发、模态文档 ESC 关闭

**踩过并已写进上文的关键结论**：
1. 目测缩略图的坐标不可信，必须做 §3 的标定（实测偏差 30–60px，足以点空）
2. 游戏常忽略合成滚轮（Raw Input），但左键拖动、单击、Ctrl+点击通常有效
3. 前台锁会让 `SetForegroundWindow` 静默失败 → 每批动作前 `-Activate`
4. PS 5.1 按 ANSI 读脚本 → 脚本必须纯 ASCII，中文只进数据文件
5. 界面状态变化后（买完货、切换面板）**同一按钮的位置会变**，要重新标定

---

## 12. 辅助脚本速查

### zoom.ps1 —— 看不清就放大
```powershell
& "scripts\zoom.ps1" -X 1400 -Y 0 -W 520 -H 300 -Scale 2          # 现拍 + 裁剪 + 放大
& "scripts\zoom.ps1" -In "$env:TEMP\sc\shot.png" -X 660 -Y 450 -W 500 -H 280 -Scale 3
```
输出会打印 `screen_x = X + zoom_x/Scale`，据此把放大图里的坐标换算回屏幕。`-Smooth` 用高质量插值（适合看文字），默认最近邻（适合看像素图）。

### calibrate.ps1 —— 别再目测坐标
```powershell
# 边框扫描：找青色描边按钮的 bbox 与中心
& "scripts\calibrate.ps1" -Mode BorderScan -Region "650,880,650,160" -Color Cyan

# 悬停差分：光标在两个位置各停一次，差出来的就是按钮
& "scripts\calibrate.ps1" -Mode HoverDiff -X 1212 -Y 400 -Axis y -Delta 120 -Region "900,300,600,500"
```
颜色族：`Cyan Light White Green Yellow Red`。返回 `center=(x,y)` 直接拿去点击。

### waitchange.ps1 —— 等界面变
```powershell
& "scripts\waitchange.ps1" -Region "300,300,1300,700" -TimeoutSec 20
```
返回 `changed=True/False` 和耗时，并把变化后的画面存成 PNG。
⚠️ **把任务栏时钟排除在 Region 外**，否则分钟一跳就会被判成"变化"（实测 0.52% 变动即触发）；必要时调高 `-AreaThreshold`。

### think.ps1 —— 写思考流
```powershell
& "scripts\think.ps1" -Lines "看  ...","想  ...","动  ..."      # 追加日志
& "scripts\think.ps1" -State "● 已接管控制"                     # 改浮窗头部
```

### start-overlay.ps1 / stop-overlay.ps1 —— 浮窗开关
```powershell
& "scripts\start-overlay.ps1" -State "● 已接管控制" -X 330 -Y 6 -W 760 -H 196 -TailLines 6
& "scripts\stop-overlay.ps1"
```

### 一次完整循环的骨架
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
# $s = 本 skill 目录下的 scripts（加载技能时会打印 "Base directory for this skill: ..."）
$s = Join-Path "<skill base directory>" 'scripts'

& "$s\ui.ps1" -Activate 'SomeApp'                    # 1. 抢焦点（必做）
& "$s\ui.ps1" -Shot -Out "$env:TEMP\sc\1.png"        # 2. 截图 → read_image
# 3. 用 calibrate / zoom 定位目标，得到 (x,y)
& "$s\ui.ps1" -Click -X $x -Y $y                     # 4. 动手
& "$s\waitchange.ps1" -Region "..." -TimeoutSec 8    # 5. 等界面响应
& "$s\ui.ps1" -Shot -Out "$env:TEMP\sc\2.png"        # 6. 再截图验证
& "$s\think.ps1" -Lines "看  点击后界面…","想  …","动  …"
```
