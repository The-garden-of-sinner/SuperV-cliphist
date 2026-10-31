/* 让 GDK 放弃 MIT-SHM，改用普通的 XPutImage。
 *
 * 背景：部分麒麟 / 统信设备的 X 服务端与客户端不在同一个 /dev/shm，
 * 但 XShmQueryExtension 仍返回成功。GDK 因此继续走 ShmPutImage，
 * 每次重绘都收到 BadValue (request_code 130, minor_code 3) 并终止进程。
 *
 * 用法：编译成 .so 后放在 ~/.local/lib/cliphist/noshm.so，
 *       cliphist daemon 会自动带 LD_PRELOAD 重新执行自己。
 *
 *   gcc -shared -fPIC -Wl,--version-script=tools/noshm.map \
 *       -o ~/.local/lib/cliphist/noshm.so tools/noshm.c
 *
 * 注意：必须带版本脚本导出为 libXext.so.6，否则 libXext 的版本化符号
 * 不会被这里的定义覆盖。
 */
#include <unistd.h>

int XShmQueryExtension(void *dpy) { (void)dpy; return 0; }

__attribute__((constructor))
static void announce(void) {
    static const char msg[] = "[cliphist] noshm: MIT-SHM 已禁用，改用 XPutImage\n";
    if (write(2, msg, sizeof(msg) - 1) < 0) { /* 忽略写入失败 */ }
}
