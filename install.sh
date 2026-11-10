#!/usr/bin/env bash
# SuperV-cliphist 安装脚本
# 用法：./install.sh
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
AUTOSTART_DIR="${HOME}/.config/autostart"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { printf '%s\n' "$*"; }

say "SuperV-cliphist 安装"
say ""

# ---- 1. 依赖检查 ----
missing=()
python3 -c "import gi; gi.require_version('Gtk', '3.0')" 2>/dev/null \
    || missing+=("gtk")
command -v xdotool >/dev/null 2>&1 \
    || missing+=("xdotool")

if [ "${#missing[@]}" -ne 0 ]; then
    say "缺少以下依赖，安装已中止："
    for m in "${missing[@]}"; do
        case "$m" in
            gtk)     say "  python3-gi + GTK3   →  sudo apt install python3-gi gir1.2-gtk-3.0" ;;
            xdotool) say "  xdotool            →  sudo apt install xdotool" ;;
        esac
    done
    say ""
    say "xdotool 用于激活原窗口并发送 Ctrl+V；缺少它时面板仍可呼出，"
    say "但选中条目后需手动按 Ctrl+V 粘贴。"
    exit 1
fi
say "[1/5] 依赖检查通过"

# ---- 2. 安装主程序 ----
install -Dm755 "${SRC_DIR}/cliphist" "${BIN_DIR}/cliphist"
say "[2/5] 已安装 ${BIN_DIR}/cliphist"

# ---- 3. 配置开机自启与开始菜单项 ----
install -Dm644 "${SRC_DIR}/cliphist.desktop" "${AUTOSTART_DIR}/cliphist.desktop"
APPLICATIONS_DIR="${HOME}/.local/share/applications"
install -Dm644 "${SRC_DIR}/cliphist-app.desktop" "${APPLICATIONS_DIR}/cliphist.desktop"
sed -i "s|@BIN@|${BIN_DIR}|g" "${APPLICATIONS_DIR}/cliphist.desktop"
say "[3/5] 已配置开机自启（登录时执行 cliphist ensure）与开始菜单项（剪贴板历史）"

# ---- 4. 安装看门狗 ----
# 用常驻 service 而不是 oneshot + timer：oneshot 结束时会把刚拉起的
# daemon 当成 cgroup 残留进程一起杀掉。
if command -v systemctl >/dev/null 2>&1 \
   && systemctl --user is-system-running >/dev/null 2>&1; then
    install -Dm755 "${SRC_DIR}/systemd/cliphist-watchdog.py" \
        "${BIN_DIR}/cliphist-watchdog"
    install -Dm644 "${SRC_DIR}/systemd/cliphist-watchdog.service" \
        "${HOME}/.config/systemd/user/cliphist-watchdog.service"
    systemctl --user daemon-reload
    if systemctl --user enable --now cliphist-watchdog.service >/dev/null 2>&1; then
        say "[4/5] 已启用看门狗（每 30 秒巡检，掉线自动恢复）"
    else
        say "[4/5] 看门狗启用失败，稍后可手动执行："
        say "      systemctl --user enable --now cliphist-watchdog.service"
    fi
else
    say "[4/5] 未检测到 systemd --user，跳过看门狗（开机自启仍有效）"
fi

# ---- 5. 启动守护进程 ----
if "${BIN_DIR}/cliphist" status 2>/dev/null | grep -q "运行中"; then
    say "[5/5] 守护进程已在运行，跳过启动"
else
    if "${BIN_DIR}/cliphist" ensure >/dev/null 2>&1; then
        say "[5/5] 守护进程已启动"
    else
        say "[5/5] 守护进程启动失败，请检查当前是否为图形会话（DISPLAY 是否可用）"
        exit 1
    fi
fi

say ""
say "安装完成。按 Super+V 呼出面板。"
say "热键由程序自行抓取，无需在系统设置中绑定。"
