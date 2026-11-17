#!/usr/bin/env bash
# S4: DrivoR 공식 ckpt, navtest PDMS (E-drivor). README 그대로. 기대 93.1 (Train 85k) / 93.7 (Trainval 103k), 게이트 ±1.5.
# CKPT 기본값은 Train 85k 모델. Trainval 모델은 CKPT=.../drivor_Nav1_25epochs.pth
set -euo pipefail
CKPT=${CKPT:-/home/daejun/E2E/models/drivor/ckpt/drivor_Nav1_train_only_85k_25epochs.ckpt}
LOGDIR=/home/daejun/E2E/models/drivor/logs
source /home/daejun/E2E/models/common.sh drivor eval_navtest_drivor
cd $NAVSIM_DEVKIT_ROOT   # image_backbone.model_weights 가 상대 경로(weights/...)
export SUBSCORE_PATH=$NAVSIM_EXP_ROOT
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_pdm_score_multi_gpu.py \
  train_test_split=navtest agent=drivoR agent.checkpoint_path=$CKPT \
  experiment_name=drivoR_nav1_$(basename $CKPT | sed 's/\..*//') \
  agent.config.proposal_num=64 agent.config.refiner_ls_values=0.0 \
  agent.config.image_backbone.focus_front_cam=false agent.config.one_token_per_traj=true \
  agent.config.refiner_num_heads=1 agent.config.tf_d_model=256 agent.config.tf_d_ffn=1024 \
  agent.config.area_pred=false agent.config.agent_pred=false agent.config.ref_num=4 \
  agent.config.noc=1 agent.config.dac=1 agent.config.ddc=0.0 \
  agent.config.ttc=5 agent.config.ep=5 agent.config.comfort=2
