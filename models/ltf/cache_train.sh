#!/usr/bin/env bash
# S3 준비용 (기본 실행 금지). 사용: CONFIRM_TRAIN=1 ltf/cache_train.sh
[ "${CONFIRM_TRAIN:-}" = 1 ] || { echo "S3 학습 준비 스크립트: CONFIRM_TRAIN=1 일 때만 실행"; exit 1; }
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/ltf/logs
source /home/daejun/E2E/models/common.sh v2 ltf_cache_train
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_dataset_caching.py \
  agent=transfuser_agent agent.config.latent=True \
  train_test_split=navtrain cache_path=$NAVSIM_EXP_ROOT/training_cache
