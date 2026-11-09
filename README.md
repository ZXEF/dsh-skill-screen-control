# dsh-skill-screen-control

给 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（DSH）用的技能包：让 agent 用**截图 + 视觉识别 + 模拟鼠标键盘**真实操作 Windows 桌面程序，并带一个置顶、鼠标穿透的「思考流」浮窗。

装完之后，`screen-control` 会出现在 DSH 的技能目录里，**不需要手动拷任何文件**。

---

## 硬性前提（缺一不可）

| 前提 | 说明 |
|---|---|
| **Windows** | 依赖 `user32.dll` + WinForms + System.Drawing，仅 Windows 可用 |
| **DSH** | 需要 DSH 的技能注册表（`ctx.skills`），本包以 bundle 形式提供 skill |
| **支持图像输入的模型** | 没有视觉模型的 agent 会在 `read_image` 报 `does not declare image input`，本 skill 完全不可用 |
| **允许模拟输入** | 目标程序若以管理员运行，agent 也需同级权限，否则 Windows UIPI 会静默丢弃注入的键鼠 |

---

## 安装

### 方式 A：GitHub Release（推荐，已实测）

从本仓库 **Releases** 页面复制 tarball 的下载链接，然后在 DSH 里让 agent 执行：

```
install_bundle  target: https://github.com/<你的用户名>/<仓库名>/releases/download/v0.1.1/dsh-skill-screen-control-0.1.1.tgz
```

装完 skill **立刻**出现在会话目录里：不用重启，不用手动拷文件。

> 实测记录：卸载后用本地 HTTP 服务模拟 GitHub 下载，`install_bundle` 走 `downloaded 1` 成功挂载，`screen-control` 立即回到技能目录。

### 方式 B：直接装 GitHub 仓库（需要本机有 git）

```
install_bundle  target: github:<你的用户名>/<仓库名>
```

> 走 git clone 后打包，要求**仓库根目录就是本包的根目录**（`package.json` 在根上）。本机未验证，优先用方式 A。

### 方式 C：npm（如已发布到 npm）

```
install_bundle  target: dsh-skill-screen-control
```

### 方式 D：手动放文件（不推荐，但最直接）

把 `skills/screen-control/` 整个目录复制到：

- 用户级：`%USERPROFILE%\.dsh\skills\screen-control\`
- 或项目级：`<项目根>/.dsh/skills/screen-control/`

DSH 的技能目录会监听文件变化，放进去即可被识别（无需重启）。

---

## 装完怎么验证

在 DSH 会话里让 agent 加载技能：

```
skill  name: screen-control
```

正常返回会带上 `Base directory for this skill: ...` 和指令正文。然后跑一条自检：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& "<技能目录>\scripts\ui.ps1" -ScreenInfo
& "<技能目录>\scripts\ui.ps1" -Shot -Out "$env:TEMP\sc\test.png"
```

能看到显示器信息和一张 1920×1080（或你的分辨率）截图，就说明环境通了。

---

## 包里有什么

```
skills/screen-control/
├── SKILL.md              指令正文（13 节：前提、截图、坐标标定、输入、焦点、浮窗、可靠性纪律、已知坑…）
└── scripts/
    ├── ui.ps1            截图 + 点击/拖动/滚轮/按键/组合键/修饰键点击/打字/粘贴/窗口激活
    ├── calibrate.ps1     坐标标定（悬停差分 / 边框颜色扫描）
    ├── zoom.ps1          裁剪放大（读小字、认小图标）
    ├── waitchange.ps1    等待界面变化（加载完成 / 弹窗 / 顾客进店）
    ├── think.ps1         写思考流日志（自动时间戳）
    ├── start-overlay.ps1 启动浮窗（pid 管理）
    ├── stop-overlay.ps1  关闭浮窗
    └── overlay.ps1       浮窗本体（置顶 + 鼠标穿透）
```

所有脚本都是**纯 ASCII**，中文只出现在数据文件里——这是为了绕开 Windows PowerShell 5.1 按 ANSI 读脚本导致的中文截断问题。

---

## 已知限制

- **仅 Windows**：`user32.dll`、WinForms、System.Drawing 都是 Windows 专属
- **DPI 缩放**：脚本尚未做 DPI 感知。**125% / 150% 缩放的机器上坐标会整体偏移**；请把显示缩放临时设为 100%，或使用 `calibrate.ps1` 实测坐标
- **Raw Input**：部分程序/游戏忽略合成滚轮，滚轮缩放可能无效；左键点击、拖动、Ctrl+点击通常仍有效
- **全屏独占**：独占全屏可能截不到画面，请改用无边框窗口
- **反作弊**：本方案是 OS 级模拟输入（不注入进程、不改内存），但仍可能违反游戏用户协议；不要用于挂机刷资源

---

## 给维护者：发布到 GitHub

```bash
# 1) 仓库根目录 = 本包根目录（package.json 必须在根上）
git init && git add . && git commit -m "feat: dsh skill bundle for screen-control"

# 2) 打包（产物名固定为 <name>-<version>.tgz）
node <pnpm 路径> pack

# 3) 建 Release（tag 建议 v<version>），把 tgz 作为 asset 上传
#    GitHub 网页操作即可：Releases -> Draft a new release -> 附加 asset

# 4) 把 README 里的 <你的用户名>/<仓库名> 换成真实地址
```

安装方只需要 **Release 的 tarball 直链**，不需要 npm 账号，也不需要包名全局唯一。

## License

MIT
