#!/bin/bash
# ============================================================
# init-cache.sh - 初始化上游追踪缓存
# ============================================================
set -e

echo "初始化上游追踪缓存..."
mkdir -p .upstream-cache

# SDM845 mainline 内核
SDM845_COMMIT=$(curl -sfL \
  "https://gitlab.com/api/v4/projects/sdm845-mainline%2Flinux/repository/branches/main" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['commit']['id'])" 2>/dev/null || echo "")
if [ -n "${SDM845_COMMIT}" ]; then
  echo "SDM845 mainline: ${SDM845_COMMIT:0:12}"
  echo "${SDM845_COMMIT}" > .upstream-cache/sdm845_commit
else
  echo "⚠ 无法获取 SDM845 mainline 状态"
  echo "" > .upstream-cache/sdm845_commit
fi

# New-Wheat 补丁仓库
NEWWHEAT_COMMIT=$(curl -sfL -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/New-Wheat/Linux-for-HUAWEI-MateBook-E-2019/commits/main" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])" 2>/dev/null || echo "")
if [ -n "${NEWWHEAT_COMMIT}" ]; then
  echo "New-Wheat: ${NEWWHEAT_COMMIT:0:12}"
  echo "${NEWWHEAT_COMMIT}" > .upstream-cache/newwheat_commit
else
  echo "⚠ 无法获取 New-Wheat 状态"
  echo "" > .upstream-cache/newwheat_commit
fi

# 占位：首次构建使用的 ref
echo "v6.16-rc2-sdm845" > .upstream-cache/last_successful_sdm845_ref

echo ""
echo "缓存初始化完成！请提交到仓库："
echo "  git add .upstream-cache/"
echo "  git commit -m 'chore: initialize upstream cache'"
