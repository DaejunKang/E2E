#!/usr/bin/env bash
# E-v1: navtest metric cache (PDMS v1 evaluator 용). 사양서 §4 S2.
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/logs
source /home/daejun/E2E/models/common.sh v1 cache_navtest_v1
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_metric_caching.py \
  train_test_split=navtest cache.cache_path=$NAVSIM_EXP_ROOT/metric_cache
du -sh $NAVSIM_EXP_ROOT/metric_cache
