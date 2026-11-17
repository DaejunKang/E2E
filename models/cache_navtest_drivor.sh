#!/usr/bin/env bash
# E-drivor: navtest metric cache. DrivoR fork 의 evaluator 와 pickle 클래스가 달라 v1 cache 와 분리한다 (사양서 §2-1).
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/logs
source /home/daejun/E2E/models/common.sh drivor cache_navtest_drivor
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_metric_caching.py \
  train_test_split=navtest cache.cache_path=$NAVSIM_EXP_ROOT/metric_cache
du -sh $NAVSIM_EXP_ROOT/metric_cache
