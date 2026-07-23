#!/bin/bash
# ============================================================
# 卸载脚本（通用版）
# 安全卸载所有 ntfs-3g 挂载的外接硬盘
# 双击 .command 文件即可运行
# ============================================================

clear

echo "========================================="
echo "   安全卸载外接硬盘"
echo "========================================="
echo ""

# 查找所有 macFUSE 挂载的盘
MOUNTS=$(mount | grep macfuse | awk '{print $3}')

if [ -z "$MOUNTS" ]; then
    echo "没有找到 ntfs-3g 挂载的硬盘"
    echo ""
    read -p "按回车键退出..."
    echo "窗口将在 3 秒后自动关闭..."
    sleep 3
    osascript -e 'tell app "Terminal" to close front window' 2>/dev/null &
    exit 0
fi

UNMOUNTED=0
while IFS= read -r mp; do
    echo "正在卸载 $mp ..."
    sudo umount "$mp"
    if [ $? -eq 0 ]; then
        echo "  卸载成功"
        UNMOUNTED=$((UNMOUNTED + 1))
    else
        echo "  卸载失败，请确认没有程序正在使用"
    fi
    echo ""
done <<< "$MOUNTS"

if [ $UNMOUNTED -gt 0 ]; then
    echo "共卸载 ${UNMOUNTED} 个硬盘，可以安全拔出"
fi

echo ""
read -p "按回车键退出..."
echo "窗口将在 3 秒后自动关闭..."
sleep 3
osascript -e 'tell app "Terminal" to close front window' 2>/dev/null &
