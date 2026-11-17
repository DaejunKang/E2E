#!/usr/bin/env bash
# 07 사양서 §2-4 설치 (uv venv, py3.9). 사용: scripts/install_envs.sh <v2|v1|drivor>
set -euo pipefail
WS=/home/daejun/E2E
CU=https://download.pytorch.org/whl/cu128
UVARGS="--extra-index-url $CU --index-strategy unsafe-best-match"
which=$1
case $which in
  v2|v1)
    d=navsim_$which
    uv venv -p 3.9 --seed $WS/envs/$d
    source $WS/envs/$d/bin/activate
    uv pip install $UVARGS -r $WS/$d/requirements.txt --override $WS/scripts/torch-override.txt
    uv pip install -e $WS/$d --no-deps
    ;;
  drivor)
    uv venv -p 3.9 --seed $WS/envs/drivor
    source $WS/envs/drivor/bin/activate
    uv pip install $UVARGS torch==2.7.1 torchvision==0.22.1 torchaudio==2.7.1
    uv pip install $UVARGS -e $WS/drivor/nuplan-devkit --override $WS/scripts/torch-override.txt
    uv pip install $UVARGS -e $WS/drivor --override $WS/scripts/torch-override.txt
    uv pip install numpy==1.26.4
    ;;
esac
mkdir -p $WS/docs
uv pip freeze > $WS/docs/freeze_$which.txt
