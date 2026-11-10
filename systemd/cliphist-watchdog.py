#!/usr/bin/python3
# -*- coding: utf-8 -*-
"""SuperV-cliphist 看门狗：每 30 秒探活一次，服务无响应就调 cliphist ensure。

只依赖标准库，不加载 GTK、不连 X。由 systemd --user 托管，崩了会被重启。
不要用 oneshot + timer 做这件事：oneshot 服务结束时 systemd 会把刚拉起的
daemon 当成 cgroup 残留进程一起杀掉。
"""
import os
import time
import socket
import subprocess

HOME = os.path.expanduser('~')
DATA_DIR = os.path.join(HOME, '.local', 'share', 'clip-hist')
RUNTIME_DIR = os.environ.get('XDG_RUNTIME_DIR') or os.path.join(HOME, '.cache')
SOCK_FILE = os.path.join(RUNTIME_DIR, 'clip-hist.sock')
STOP_FLAG = os.path.join(DATA_DIR, 'stopped')
CLIPHIST = os.path.join(HOME, '.local', 'bin', 'cliphist')
INTERVAL = 30


def alive():
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(SOCK_FILE)
        s.sendall(b'ping')
        s.close()
        return True
    except Exception:
        return False


def main():
    time.sleep(10)          # 给桌面会话与开机自启留出准备时间
    while True:
        # cliphist stop 会留下停用标记，此时不要擅自把服务拉回来
        if not os.path.exists(STOP_FLAG) and not alive():
            try:
                subprocess.run([CLIPHIST, 'ensure'], timeout=60,
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
            except Exception:
                pass
        time.sleep(INTERVAL)


if __name__ == '__main__':
    main()
