#!/usr/bin/env bash
# S5 준비용 (기본 실행 금지). README 의 NAVSIM-v2 10 epoch 학습. 4 GPU x per-GPU batch 16 = global 64 유지, epoch 10 고정.
# ⚠ README 원문은 'agent.loss.prev_weight=0.0' 뒤에 '\' 가 없어 seed=2 가 적용되지 않는다 (사양서 함정 #4) — 여기서는 수정함.
[ "${CONFIRM_TRAIN:-}" = 1 ] || { echo "S5 학습 준비 스크립트: CONFIRM_TRAIN=1 일 때만 실행"; exit 1; }
set -euo pipefail
LOGDIR=/home/daejun/E2E/models/drivor/logs
source /home/daejun/E2E/models/common.sh drivor drivor_train_nav2
cd $NAVSIM_DEVKIT_ROOT
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
  agent=drivoR experiment_name=training_drivoR_Nav2_10epochs \
  train_test_split=navtrain cache_path=null use_cache_without_dataset=false \
  trainer.params.max_epochs=10 dataloader.params.prefetch_factor=1 dataloader.params.batch_size=16 \
  agent.lr_args.name=AdamW agent.lr_args.base_lr=0.0002 agent.num_gpus=4 agent.progress_bar=false \
  agent.config.refiner_ls_values=0.0 agent.config.image_backbone.focus_front_cam=false \
  agent.config.one_token_per_traj=true agent.config.refiner_num_heads=1 \
  agent.config.tf_d_model=256 agent.config.tf_d_ffn=1024 agent.config.area_pred=false \
  agent.config.agent_pred=false agent.config.ref_num=4 agent.loss.prev_weight=0.0 \
  seed=2
