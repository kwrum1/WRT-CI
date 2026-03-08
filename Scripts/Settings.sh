#!/bin/bash

########################################
# 内核 & eBPF 配置（必须放在 Settings.sh）
########################################

# 增加 eBPF 内核配置
function cat_kernel_config() {
  if [ -f "$1" ]; then
    cat >> "$1" <<EOF

# BPF
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_CGROUPS=y
CONFIG_KPROBES=y
CONFIG_NET_INGRESS=y
CONFIG_NET_EGRESS=y
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS_BPF=m
CONFIG_NET_CLS_ACT=y
CONFIG_BPF_STREAM_PARSER=y

# Debug (如不需要可关闭以减少体积)
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_BTF=y

# Events
CONFIG_KPROBE_EVENTS=y
CONFIG_BPF_EVENTS=y

# Scheduler / THP
CONFIG_SCHED_CLASS_EXT=y
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y
EOF
  fi
}

# eBPF 相关（内核层）
function cat_ebpf_config() {
  if [ -f "$1" ]; then
    cat >> "$1" <<EOF

# eBPF Advanced
CONFIG_DEVEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_BPF_TOOLCHAIN_HOST=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y
EOF
  fi
}

# 开启 skb 回收
function enable_skb_recycler() {
  if [ -f "$1" ]; then
    cat >> "$1" <<EOF

CONFIG_KERNEL_SKB_RECYCLER=y
CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=y
EOF
  fi
}

# 修改 ipq60xx 内核大小
function set_kernel_size() {
  image_file="./target/linux/qualcommax/image/ipq60xx.mk"

  sed -i "/^define Device\/jdcloud_re-ss-01/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"
  sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"
  sed -i "/^define Device\/jdcloud_re-cs-07/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"
}

########################################
# 生成最终 .config
########################################

function generate_config() {

  config_file=".config"

  # 合并基础配置
  cat "$GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt" \
      "$GITHUB_WORKSPACE/Config/GENERAL.txt" > "$config_file"

  local target=$(echo "$WRT_ARCH" | cut -d'_' -f2)

  # 如需要删除 WIFI
  if [[ "$WRT_CONFIG" == *"NOWIFI"* ]]; then
    remove_wifi "$target"
  fi

  # 添加 eBPF / 内核增强
  cat_ebpf_config "$config_file"
  enable_skb_recycler "$config_file"

  # 修改内核大小（仅对 ipq60xx 生效）
  set_kernel_size

  # 增加内核选项到对应平台目录
  cat_kernel_config "target/linux/qualcommax/${target}/config-default"
}
