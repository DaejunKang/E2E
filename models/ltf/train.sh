#!/usr/bin/env bash
# S3 준비용 (기본 실행 금지). 사양서 §4 S3: Adam lr 1e-4, effective batch 64, 100 epoch. batch/lr 변경 금지.
[ "${CONFIRM_TRAIN:-}" = 1 ] || { echo "S3 학습 준비 스크립트: CONFIRM_TRAIN=1 일 때만 실행"; exit 1; }
set -euo pipefail
SEED=${SEED:-0}
LOGDIR=/home/daejun/E2E/models/ltf/logs
source /home/daejun/E2E/models/common.sh v2 ltf_train_seed$SEED
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
  agent=transfuser_agent agent.config.latent=True \
  experiment_name=training_ltf_seed$SEED train_test_split=navtrain \
  cache_path=$NAVSIM_EXP_ROOT/training_cache \
  use_cache_without_dataset=true force_cache_computation=false seed=$SEED
