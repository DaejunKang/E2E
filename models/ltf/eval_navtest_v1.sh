#!/usr/bin/env bash
# S2: LTF 공식 ckpt, navtest PDMS (E-v1). 기대 83.8, 게이트 ±1.0. SEED=0|1|2
set -euo pipefail
SEED=${SEED:-0}
LOGDIR=/home/daejun/E2E/models/ltf/logs
source /home/daejun/E2E/models/common.sh v1 eval_navtest_v1_seed$SEED
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_pdm_score.py \
  train_test_split=navtest \
  agent=transfuser_agent agent.config.latent=True \
  worker=single_machine_thread_pool \
  agent.checkpoint_path=/home/daejun/E2E/models/ltf/ckpt/ltf/ltf_seed_$SEED.ckpt \
  experiment_name=ltf_seed${SEED}_navtest
