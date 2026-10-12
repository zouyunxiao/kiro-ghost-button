# Kiro Ghost Button

给 Kiro 加一个幽灵图标按钮，一键把被 Codex 之类的侧边栏挤掉的 Kiro 聊天面板召唤回来。

装完之后你会得到三个入口：

- **编辑器标题栏右侧**（Codex 图标旁边）一个幽灵图标
- **右下角状态栏**一个 `Kiro` 按钮
- 快捷键 **`Ctrl+Alt+K`**（macOS 为 `Cmd+Alt+K`）

图标颜色跟随当前主题，换深色/浅色主题都清晰可见。

---

## 快速开始

在新电脑上使用，只需要三步：

1. 把整个 `kiro-ghost-button` 文件夹拷到那台电脑上（U 盘、网盘、git 都行，放哪个目录都无所谓）
2. **双击 `install.bat`**
3. 回到 Kiro，按 `Ctrl+Shift+P`，输入 `Reload Window` 回车

完事。装好后会在窗口里看到幽灵图标。

> 不需要管理员权限，不需要装 Node.js、npm 或任何其它东西。只要那台电脑上装了 Kiro 就行。

### 卸载

双击 `uninstall.bat`，然后同样 `Reload Window` 一次。

---

## 它到底做了什么

`install.bat` 会：

1. **找到 Kiro**。依次查常见安装目录、Windows 卸载注册表（能处理装在自定义盘的情况）、以及 `PATH`
2. **探测图标方案**。见下面"图标的两种模式"
3. **打包扩展**。把 `src/` 按 VSIX 规范压成一个 `.vsix`，全程用 PowerShell 完成，不依赖 `npm` / `vsce`
4. **调用 Kiro 自己的命令行装进去**：`kiro --install-extension ... --force`
5. **验证**。用 `kiro --list-extensions` 确认装上了，没装上就报错退出

扩展装到 `%USERPROFILE%\.kiro\extensions\local.kiro-ghost-button-<版本>\`，属于用户级安装，不碰 Kiro 的安装目录，也不改 Kiro 本体任何文件。

---

## 图标的两种模式

点击按钮这件事没什么玄学，难点其实在图标怎么显示才能跟随主题。安装器会自动选：

### `font` 模式（优先，效果最好）

用 `"icon": "$(kiro)"`。`kiro` 是 Kiro 自带图标字体（`out/media/kiricon.ttf`）里的幽灵 glyph，已注册在 Kiro 核心图标表中。作为字体渲染，它会继承 `--vscode-icon-foreground`，也就是**当前主题的真实前景色**，换主题立刻跟着变，和 Kiro 原生按钮完全一致。

### `svg` 模式（兜底）

如果目标机器的 Kiro 版本里找不到 `kiro` 这个 glyph，就退回 `"icon": { "light": ..., "dark": ... }`，用 `src/resources/` 下两张固定颜色的 SVG（深色主题用 `#CCCCCC`，浅色主题用 `#424242`）。只有两档颜色，不如字体精确，但保证任何版本都清晰可见、不会变成一团黑。

> 这是 Codex 插件自己用的方案（它有 `blossom-black.svg` 和 `blossom-white.svg` 两张图）。

### 为什么不能直接用一张 `currentColor` 的 SVG

踩过这个坑，记录一下：VS Code / Kiro 把 `contributes.commands.icon` 指向的 SVG 当作 CSS `background-image` 渲染。外部引用的 SVG 里写 `fill="currentColor"` 是**无效**的，因为它解析不到宿主元素的 `color`，会退化成初始值黑色。结果就是不管什么主题，图标永远是黑的，在深色主题下基本看不见。

### 手动指定模式

正常不用管，想强制的话：

```bat
install.bat -IconMode svg
install.bat -IconMode font
```

---

## 目录结构

```
kiro-ghost-button/
├─ install.bat              双击安装
├─ uninstall.bat            双击卸载
├─ README.md
├─ scripts/
│  ├─ install.ps1           安装主流程（定位 Kiro、探测、打包、安装、验证）
│  ├─ uninstall.ps1         卸载
│  ├─ build-vsix.ps1        把 src/ 打包成 .vsix，支持两种图标模式
│  └─ KiroCommon.ps1        公共函数：找 Kiro、探测图标字体
└─ src/                     扩展本体
   ├─ package.json          清单（命令、菜单位置、快捷键）
   ├─ extension.js          逻辑
   ├─ resources/            svg 模式用的两张图标
   └─ vsix/                 VSIX 打包所需的元数据
```

---

## 排错

**双击 `install.bat` 闪一下就没了 / 报错看不清**

窗口末尾有 `pause`，正常不会自动关。如果真的闪退，在该目录打开 PowerShell 手动跑，能看到完整错误：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

**提示 `Could not locate Kiro`**

说明 Kiro 装在了不常见的位置。手动指定启动器路径：

```bat
install.bat -KiroCli "D:\你的路径\Kiro\bin\kiro.cmd"
```

**提示执行策略 / 脚本无法加载**

`install.bat` 里已经带了 `-ExecutionPolicy Bypass`，一般不会遇到。如果公司策略锁得很死（组策略强制 `AllSigned`），需要让 IT 放开，或者手动安装（见下）。

**装完了但图标没出现**

1. 确认重载过窗口：`Ctrl+Shift+P` → `Reload Window`
2. 标题栏图标**只在有打开的文件时才显示**，这是 `editor/title` 菜单位置的固有行为。先看右下角状态栏那个 `Kiro` 按钮在不在
3. 状态栏按钮也没有的话，去扩展面板搜 `Kiro Ghost Button`，看是不是被禁用了

**图标位置是空白或方块**

说明走了 `font` 模式但那个 glyph 没取到。用 `install.bat -IconMode svg` 重装一次。

**手动安装（不想用脚本）**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-vsix.ps1 -IconMode font
# 然后把生成的 dist\*.vsix 拖进 Kiro 的扩展面板，或者：
kiro --install-extension .\dist\kiro-ghost-button-1.2.0.vsix --force
```

---

## 二次修改

改完 `src/package.json` 或 `src/extension.js` 后，直接重跑 `install.bat` 即可，它每次都会重新打包。

改版本号要**同时**改两个地方，`src/package.json` 的 `version` 和 `src/vsix/extension.vsixmanifest` 的 `Version=`。打包脚本会校验这两处是否一致，不一致直接报错，不会悄悄产出坏包。

### 想换个图标？

把 `src/package.json` 里 `"icon": "$(kiro)"` 换成 Kiro 支持的任意图标 id，比如 `$(comment-discussion)`、`$(sparkle)`、`$(robot)`。注意 `build-vsix.ps1` 的 `svg` 模式依赖 `"icon": "$(kiro)"` 这个字面量做替换，改了之后 `svg` 模式会报错提示你——这是故意设计成报错而不是静默失败的。

### 想改快捷键或图标位置？

都在 `src/package.json` 里：

- `contributes.keybindings[0].key` — 快捷键
- `contributes.menus."editor/title"[0].order` — 数字越大越靠右，当前是 `100`，排在 Codex 图标后面

---

## 关于编码的一个注意事项

所有 `.ps1` 和 `.bat` 都刻意保持**纯 ASCII**，脚本输出也全是英文。原因：

- PowerShell 5.1 读取不带 BOM 的 `.ps1` 时，用的是系统 ANSI 代码页（中文系统上是 GBK）。中文注释里一个 `。"` 就会把字符串的结束引号吃掉，导致脚本解析失败
- `.bat` 由 cmd.exe 按 OEM 代码页读取，不同语言的 Windows 不一样

而面向用户的界面文字（按钮标题、tooltip、报错提示）写在 `src/package.json` 和 `src/extension.js` 里是中文，因为这两个文件由 Kiro 按 UTF-8 读取，与系统语言无关。这样做的结果是：**这个包在任何语言版本的 Windows 上行为都一致**。

---

## 为什么是 `.bat` 而不是 `.exe`

`.bat` 双击即用，和 `.exe` 的体验没区别，但有三个实际好处：

- 纯文本，你可以直接打开看它到底干了什么，不用担心跑了个不透明的二进制
- 不会被杀毒软件误报（来源不明的小 exe 经常被拦）
- 改起来方便，不需要编译工具链

如果确实需要一个 `.exe`，可以用 `ps2exe` 之类的工具把 `install.ps1` 包一层，但没必要。

---

## 已知限制

- **仅 Windows**。脚本是 PowerShell + bat。扩展本身跨平台（`src/` 里没有平台相关代码），macOS / Linux 上手动 `kiro --install-extension` 装同一个 `.vsix` 也能用
- 标题栏图标在没有打开文件时不显示，这是 VS Code `editor/title` 菜单的既有行为，没法绕过——状态栏按钮就是为了补这个场景
- 依赖 Kiro 的内部命令 `kiroAgent.focusChatInput`。`extension.js` 里准备了 `workbench.view.extension.chat` 和 `kiroAgent.chatView.focus` 两级兜底，所以 Kiro 改一个命令名不会直接失效，但万一三个全改了就需要更新
- `$(kiro)` 图标 id 是 Kiro 特有的，在原版 VS Code 里不存在（那种情况下用 `-IconMode svg`）
