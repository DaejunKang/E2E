# navsim_v2 + timm==1.0.15 (DrivoR 원 저자 버전). DrivoR navhard 평가 전용. 사양서 §2 의 3-env 에 추가된 4번째 env (docs/env-diff.md)
export WORKSPACE=/home/daejun/E2E
export NUPLAN_MAP_VERSION="nuplan-maps-v1.0"
export NUPLAN_MAPS_ROOT="/ssd0/katech/datasets/E2E/maps"
export OPENSCENE_DATA_ROOT="/ssd0/katech/datasets/E2E"
export NAVSIM_DEVKIT_ROOT="$WORKSPACE/navsim_v2"
export NAVSIM_EXP_ROOT="$WORKSPACE/exp_v2"
export HYDRA_FULL_ERROR=1
source "$WORKSPACE/envs/navsim_v2_dr/bin/activate"
