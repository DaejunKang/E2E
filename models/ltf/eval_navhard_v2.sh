#!/usr/bin/env bash
# S2: LTF 공식 ckpt, navhard two-stage EPDMS (E-v2). 기대 25.1(스냅샷)/23.1(LEAD), 게이트 21~27. SEED=0|1|2
set -euo pipefail
SEED=${SEED:-0}
LOGDIR=/home/daejun/E2E/models/ltf/logs
source /home/daejun/E2E/models/common.sh v2 eval_navhard_v2_seed$SEED
D=$OPENSCENE_DATA_ROOT/navhard_two_stage
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_pdm_score.py \
  train_test_split=navhard_two_stage \
  agent=transfuser_agent agent.config.latent=True \
  worker=single_machine_thread_pool \
  agent.checkpoint_path=/home/daejun/E2E/models/ltf/ckpt/ltf/ltf_seed_$SEED.ckpt \
  experiment_name=ltf_seed${SEED}_navhard \
  metric_cache_path=$NAVSIM_EXP_ROOT/navhard_two_stage_metric_cache \
  synthetic_sensor_path=$D/sensor_blobs synthetic_scenes_path=$D/synthetic_scene_pickles
