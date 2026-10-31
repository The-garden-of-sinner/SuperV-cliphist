# SuperV-cliphist

> Windows 的 Win+V，搬到 Linux 桌面上 —— 单文件、零第三方依赖的剪贴板历史面板。
>
> 命令叫 `cliphist`，仓库名带 SuperV 前缀是为了和已有的同名项目区分开。

![Python](https://img.shields.io/badge/python-3.8%2B-blue)
![GTK](https://img.shields.io/badge/GTK-3.24-4a86cf)
![Platform](https://img.shields.io/badge/platform-X11-lightgrey)
![License](https://img.shields.io/badge/license-MIT-green)

![screenshot](screenshot.png)

## 特性

- **Win+V 全局热键** —— 在任何应用里按下弹出，选中即粘贴回原窗口，不用切窗口
- **三种内容都能记** —— 纯文本、富文本（保留 HTML 原文）、图片，自动识别
- **即时搜索** —— 输入关键词过滤，↑↓ 选择，回车粘贴
- **外观自己调** —— 字号 8–20pt、背景透明度、历史条目上限，面板内直接改，即时生效
- **记住位置** —— 拖到哪下次就在哪；首次弹出贴着鼠标，而不是死板居中
- **零依赖** —— 只用系统自带的 GTK3 和 libX11，不装任何第三方包

## 为什么写这个

银河麒麟这类信创桌面里，`apt` 往往被锁死（或者源里根本没有），
而 UKUI 3.25 又没暴露自定义命令快捷键的入口，想绑一个 `Super+V` 基本无路可走。

所以这套东西的设计前提是：**不依赖任何需要安装的组件**。
`python3-gi` + GTK3 + libX11 是桌面环境本身就带的，剪下来就能跑。

## 依赖

| 组件 | 说明 |
|---|---|
| Python 3.8+ | 系统自带 |
| PyGObject + GTK 3.24 | `python3-gi` / `gir1.2-gtk-3.0`，通常已装 |
| libX11 | 系统自带，全局热键靠它 |
| `xdotool` | 粘贴时激活原窗口并发送 Ctrl+V |
| pycairo | 可选，只有开圆角渲染时才需要 |

```bash
# Debian / Ubuntu / 麒麟
sudo apt install python3-gi gir1.2-gtk-3.0 xdotool
```

## 安装

```bash
install -Dm755 cliphist ~/.local/bin/cliphist
install -Dm644 cliphist.desktop ~/.config/autostart/cliphist.desktop
```

然后注销重登（或者直接 `cliphist daemon &`），`Win+V` 即可用。

## 使用

面板内操作：

| 按键 | 作用 |
|---|---|
| `Win+V` | 呼出 / 收起 |
| `↑` `↓` | 选择条目 |
| `Enter` | 粘贴到刚才的窗口 |
| `Del` | 删除当前条目 |
| `Esc` | 关闭 |
| 直接输入 | 按内容搜索 |
| 按住标题栏拖动 | 移动面板位置（自动记忆） |

命令行：

```bash
cliphist            # 呼出面板
cliphist settings   # 打开设置
cliphist status     # 查看状态与条目数
cliphist font 12    # 快速改字号
cliphist clear      # 清空历史（含图片文件）
cliphist stop       # 停止守护进程
```

## 配置

配置文件 `~/.config/clip-hist/config.json`，也可在设置面板里改：

| 键 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `font_size` | float | `11.0` | 字号，8–20 pt |
| `opacity` | float | `1.0` | 背景透明度，0.5–1.0 |
| `max_items` | int | `500` | 历史条目上限，50–5000 |
| `show_thumbs` | bool | `false` | 列表内显示图片缩略图 |
| `argb` | bool | `false` | 圆角 + 半透明（需 ARGB 视觉，见下） |
| `pos_x` / `pos_y` | int | — | 窗口位置，拖动后自动写入 |

数据目录 `~/.local/share/clip-hist/`：

```
history.json     # 条目（文本 / HTML / 图片元信息）
images/          # 图片原图与缩略图，按 md5 命名
```

## 已知限制

诚实列出来，免得你踩坑：

1. **富文本粘贴会丢格式**。捕获时 HTML 原文完整存进 `history.json`，
   但写回剪贴板只能给纯文本 —— PyGObject 没有绑定 `gtk_clipboard_set_with_data`，
   而那正是唯一能同时提供 `text/html` + `text/plain` 的接口。
   内容不会丢，样式会丢。
2. **图片缩略图默认关闭**。某些环境的 X 位图上传通道（MIT-SHM）不可用，
   绘制位图会导致进程崩溃。`show_thumbs: true` 可开启，桌面正常的话没问题。
3. **圆角与半透明默认关闭**。原因同上：ARGB 窗口每次重绘都要经 MIT-SHM
   上传 32 位位图。`argb: true` 可开启。
4. **仅支持 X11**。依赖 `XGrabKey`，Wayland 会话下不工作。
5. 去重按内容完全匹配，不做相似度合并。

## 实现要点

几个不太显然的地方，写下来省得以后自己忘：

- **全局热键**：`ctypes` 直接调 libX11 的 `XGrabKey`，跑在独立线程 + 独立 Display 连接上
  （避免和 GTK 抢同一个连接）。必须同时抓 CapsLock / NumLock 的四种组合，
  否则锁定键一开热键就失灵。
- **失败要喊出来**：`XSetErrorHandler` 统计 grab 失败次数，热键被别的实例占用时明确告警。
  默认行为是静默不响应，排查起来极其费劲。
- **单实例**：Unix socket 探测存活，`XKillClient` 清理跨 PID namespace 的残留。
  注意 `XKillClient` **不能**放在启动流程里 —— 残留窗口的 resource id 会被新连接复用，
  强杀会把刚启动的自己一起断掉（`Fatal IO error`）。
- **图片存储**：按内容 md5 命名，天然去重；另存一份 56px 缩略图，
  避免几百张原图把内存吃光。
- **面板绘制**：默认只走 CSS（纯矢量），因为本机 GDK 的位图上传是坏的；
  圆角和缩略图作为可选项保留。

## 兼容性

开发和测试环境：银河麒麟桌面 V10 SP1 / UKUI 3.25 / X11 / 1920×1200。

理论上其他 GTK3 桌面（XFCE、MATE、Cinnamon）也能跑，但未逐一验证。
Wayland 下不可用。

## License

MIT
