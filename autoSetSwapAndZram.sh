#!/bin/bash

# 自动获取物理内存大小
physical_memory=((`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`))

swapSizeWarning() {
    echo ""
}

zramSizeWarning() {
    echo ""
}

# 当输入的参数大于3
if set [ $# -gt 3 ];
then
    echo "Usage: ./autoSetSwapAndZram.sh [swap_size] [zram_size] [zram_algorithm]"
    echo ""
    echo "swap_size:"
    echo "  The default size is 4GiB"
    echo "  The recommended size of swap is twice that of physical memory"
    echo "  but the recommended size for swap is 4GiB if the speed is required"
    echo "  If you plan to use twice the size of physical memory instead of 4G, enter auto"
    echo ""
    echo "zram_size:"
    echo "  The recommended size of zram is 10%-25% of the total memory"
    echo "  but, after some tests, on a machine with 8GiB of physical memory,"
    echo "  using 4GiB of zram still has good performance"
    echo "  However, by default, the size of zram will still be automatically set using 25% of the total physical memory"
    echo ""
    echo "zram_algorithm:"
    echo "  The default algorithm is lz4hc"
    echo "  Under different zram algorithms, the performance of zram is also different."
    echo "  In most cases, the algorithm with the highest throughput, the lowest latency and the second highest compression rate is lz4hc."
    echo "  The algorithm with the highest compression rate is zstd"
    echo ""
    exit 1
fi

# 定义函数判断swap_size是否合法，或不设置
isSwapSize() {
    if set [ $1 -ge 0 && $1 -lt 64M ]
        # 不设置
        swapSizeWarning
    elif set [ $1 = "auto" ]
        # 设为两倍
    elif set [ $1 = "default" ]
    else
        # 交由下游判断是否合法，传递参数
        swap_size=$1
    fi
}

# 定义函数判断zram_size是否合法，或不设置
isZramSize() {
    if set [ $1 -ge 0 && $1 -lt 64M ]
        zramSizeWarning
    fi
}

if set [ $# -qt 1 ]
    # isSwapSize
    swap_size=$1
    zram_size=`expr $physical_memory / 4 / 1024 / 1024`"G"
    zram_algorithm="lz4hc"
elif set [ $# -qt 2 ]
    # isSwapSize
    swap_size=$1
    # isZramSize
    zram_size=$2
    zram_algorithm="lz4hc"
elif set [ $# -qt 3 ]
    # isSwapSize
    swap_size=$1
    # isZramSize
    zram_size=$2
    zram_algorithm=$3
else 
    swap_size=4194304
    zram_size=`expr $physical_memory / 4 / 1024 / 1024`"G"
    zram_algorithm="lz4hc"
fi

# 要求提供root权限
sudo su

# 配置swap
# 删除之前配置的swap
swapoff /swapfile
rm /swapfile
dd if=/dev/zero of=/swapfile bs=1024 count=$swap_size conv=notrunc
chown root:root /swapfile
chmod 0600 /swapfile
mkswap /swapfile
swapon /swapfile

# fstab
cat << EOF >> /etc/fstab
/swapfile none swap sw,pri=1 0 0
EOF

# 无需重启挂载fstab
mount -a

# 配置zram
# 启用内核模块
touch /etc/modules-load.d/zram.conf
cat << EOF > /etc/modules-load.d/zram.conf
zram
EOF

touch /etc/modprobe.d/zram.conf
cat << EOF > /etc/modprobe.d/zram.conf
options zram num_devices=1
EOF

# 设置zram参数
touch /etc/udev/rules.d/99-zram.rules
cat << EOF > /etc/udev/rules.d/99-zram.rules
KERNEL=="zram0",ATTR{comp_algorithm}="lz4hc",ATTR{disksize}="4G",TAG+="systemd"
EOF

# 自动开启
touch /etc/systemd/system/zram.service
cat << EOF > /etc/systemd/system/zram.service
[Unit]
Description=ZRAM
BindsTo=dev-zram0.device
After=dev-zram0.device

[Service]
Type=oneshot
RemainAfterExit=true
ExecStartPre=/sbin/mkswap /dev/zram0
ExecStart=/sbin/swapon -p 2 /dev/zram0
ExecStop=/sbin/swapoff /dev/zram0

[Install]
WantedBy=multi-user.target
EOF

# 立刻启用zram
systemctl daemon-reload
systemctl enable zram --now
