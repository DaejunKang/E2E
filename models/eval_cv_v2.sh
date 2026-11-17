#!/usr/bin/env bash
# S1: Constant Velocity, E-v2. 기대 navhard EPDMS ~11.4 (±2 통과)
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/logs
SPLIT=${SPLIT:-navhard_two_stage}
source /home/daejun/E2E/models/common.sh v2 eval_cv_${SPLIT}
D=$OPENSCENE_DATA_ROOT/$SPLIT
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_pdm_score.py \
  train_test_split=$SPLIT experiment_name=cv_agent_$SPLIT \
  metric_cache_path=$NAVSIM_EXP_ROOT/${SPLIT}_metric_cache \
  synthetic_sensor_path=$D/sensor_blobs synthetic_scenes_path=$D/synthetic_scene_pickles
