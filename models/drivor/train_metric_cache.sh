#!/usr/bin/env bash
# S5 준비용 (기본 실행 금지). 학습용 metric cache: scorer 학습 라벨(PDM sub-score). 생성 시간·크기를 run-report 에 기록.
[ "${CONFIRM_TRAIN:-}" = 1 ] || { echo "S5 학습 준비 스크립트: CONFIRM_TRAIN=1 일 때만 실행"; exit 1; }
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/drivor/logs
source /home/daejun/E2E/models/common.sh drivor drivor_train_metric_cache
cd $NAVSIM_DEVKIT_ROOT
python navsim/planning/script/run_train_metric_caching.py
