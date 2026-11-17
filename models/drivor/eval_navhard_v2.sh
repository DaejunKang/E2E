#!/usr/bin/env bash
# S4: DrivoR 공식 ckpt, navhard two-stage EPDMS (E-v2 + 이식 agent, v2_port/ 참고). 기대 48.3, 게이트 ±1.5.
set -euo pipefail
SPLIT=${SPLIT:-navhard_two_stage}   # warmup_two_stage 로 소규모 점검 가능
WORKER=${WORKER:-single_machine_thread_pool}
CKPT=${CKPT:-/home/daejun/E2E/models/drivor/ckpt/drivor_Nav2_10epochs.pth}
LOGDIR=/home/daejun/E2E/models/drivor/logs
source /home/daejun/E2E/models/common.sh v2dr eval_${SPLIT}_v2_drivor
export SUBSCORE_PATH=$NAVSIM_EXP_ROOT
D=$OPENSCENE_DATA_ROOT/$SPLIT
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_pdm_score.py \
  train_test_split=$SPLIT experiment_name=drivoR_nav2_$SPLIT worker=$WORKER \
  metric_cache_path=$NAVSIM_EXP_ROOT/${SPLIT}_metric_cache \
  synthetic_sensor_path=$D/sensor_blobs synthetic_scenes_path=$D/synthetic_scene_pickles \
  agent=drivoR agent.checkpoint_path=$CKPT \
  agent.config.image_backbone.model_weights=/home/daejun/E2E/drivor/weights/vit_small_patch14_reg4_dinov2.lvd142m/model.safetensors \
  agent.config.proposal_num=64 agent.config.refiner_ls_values=0.0 \
  agent.config.image_backbone.focus_front_cam=false agent.config.one_token_per_traj=true \
  agent.config.refiner_num_heads=1 agent.config.tf_d_model=256 agent.config.tf_d_ffn=1024 \
  agent.config.area_pred=false agent.config.agent_pred=false agent.config.ref_num=4 \
  agent.config.noc=10 agent.config.dac=13 agent.config.ddc=6 \
  agent.config.ttc=14 agent.config.ep=15 agent.config.comfort=2
