#!/usr/bin/env bash
# E-v2: navhard_two_stage metric cache. SPLIT=warmup_two_stage 로 소규모 점검 가능.
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/logs
SPLIT=${SPLIT:-navhard_two_stage}
source /home/daejun/E2E/models/common.sh v2 cache_${SPLIT}_v2
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_metric_caching.py \
  train_test_split=$SPLIT \
  metric_cache_path=$NAVSIM_EXP_ROOT/${SPLIT}_metric_cache
du -sh $NAVSIM_EXP_ROOT/${SPLIT}_metric_cache
