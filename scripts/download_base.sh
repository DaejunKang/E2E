#!/usr/bin/env bash
# NAVSIM base dataset -> shared SSD. Idempotent: finished items leave .done_<item>.
# Based on navsim_v2/download/*.sh (07 spec §3). Usage: download_base.sh [item ...]
set -euo pipefail
umask 002

ROOT=${ROOT:-/ssd0/katech/datasets/E2E}
STAGE=$ROOT/_staging
LOG=$ROOT/DOWNLOAD_LOG.md
HF=https://huggingface.co/datasets/OpenDriveLab/OpenScene/resolve/main
mkdir -p "$ROOT"/{maps,navsim_logs,sensor_blobs} "$STAGE"
cd "$ROOT"

trap 'echo "[ERR] line $LINENO: $BASH_COMMAND $(date)"' ERR

# wget with an outer retry loop; -c resumes the partial file
W() {
  local n
  for n in {1..20}; do
    wget -c --tries=10 --retry-connrefused --waitretry=10 --progress=dot:giga "$@" && return 0
    echo "[retry $n/20] wget failed: $* ($(date))"
    sleep 60
  done
  return 1
}

# fetch_extract <url> : download into cwd, extract, delete the archive
fetch_extract() {
  local f; f=$(basename "$1")
  W "$1"
  tar -xf "$f"
  rm -f "$f"
}

item_maps() {
  W https://motional-nuplan.s3-ap-northeast-1.amazonaws.com/public/nuplan-v1.1/nuplan-maps-v1.1.zip
  unzip -q nuplan-maps-v1.1.zip
  rm nuplan-maps-v1.1.zip
  rsync -a nuplan-maps-v1.0/ "$ROOT/maps/"
}

item_warmup() {
  fetch_extract $HF/navsim-v2/navsim_v2.2_warmup_two_stage.tar.gz
  rsync -a --exclude 'nuplan-maps*' --exclude maps ./ "$ROOT/"
}

item_navhard() {
  for p in curr_sensors hist_sensors scene_pickles; do
    fetch_extract $HF/navsim-v2/navsim_v2.2_navhard_two_stage_${p}.tar.gz
  done
  rsync -a ./ "$ROOT/"
}

item_test() {
  fetch_extract $HF/openscene-v1.1/openscene_metadata_test.tgz
  for kind in camera lidar; do
    for i in {0..31}; do
      echo "test $kind $i"
      fetch_extract $HF/openscene-v1.1/openscene_sensor_test_${kind}/openscene_sensor_test_${kind}_${i}.tgz
    done
  done
  mkdir -p "$ROOT/navsim_logs/test" "$ROOT/sensor_blobs/test"
  rsync -a openscene-v1.1/meta_datas/ "$ROOT/navsim_logs/test/"
  if [ -d openscene-v1.1/sensor_blobs/test ]; then
    rsync -a openscene-v1.1/sensor_blobs/test/ "$ROOT/sensor_blobs/test/"
  else
    rsync -a openscene-v1.1/sensor_blobs/ "$ROOT/sensor_blobs/test/"
  fi
}

item_navtrain() {
  fetch_extract $HF/openscene-v1.1/openscene_metadata_trainval.tgz
  mkdir -p "$ROOT/navsim_logs/trainval" "$ROOT/sensor_blobs/trainval"
  rsync -a openscene-v1.1/meta_datas/ "$ROOT/navsim_logs/trainval/"
  rm -rf openscene-v1.1
  for kind in current history; do
    for i in {1..32}; do
      echo "navtrain $kind $i"
      fetch_extract $HF/navsim/navtrain_${kind}_${i}.tgz
      rsync -a navtrain_${kind}_${i}/ "$ROOT/sensor_blobs/trainval/"
      rm -rf navtrain_${kind}_${i}
    done
  done
}

ITEMS=("$@")
[ ${#ITEMS[@]} -eq 0 ] && ITEMS=(maps warmup navhard test navtrain)

[ -f "$LOG" ] || printf '# Download log\n\n| item | size | elapsed | finished |\n|---|---|---|---|\n' > "$LOG"

for it in "${ITEMS[@]}"; do
  if [ -f "$ROOT/.done_$it" ]; then echo "[skip] $it"; continue; fi
  echo "[start] $it $(date)"
  t0=$(date +%s)
  mkdir -p "$STAGE/$it"
  ( cd "$STAGE/$it" && "item_$it" )
  rm -rf "$STAGE/$it"
  touch "$ROOT/.done_$it"
  case $it in
    maps) p=maps;; warmup) p=warmup_two_stage;; navhard) p=navhard_two_stage;;
    test) p="navsim_logs/test sensor_blobs/test";; navtrain) p="navsim_logs/trainval sensor_blobs/trainval";;
  esac
  size=$(cd "$ROOT" && du -sch $p 2>/dev/null | tail -1 | cut -f1)
  echo "| $it | $size | $(( $(date +%s) - t0 ))s | $(date '+%F %T') |" >> "$LOG"
  echo "[done] $it $size"
done
rmdir "$STAGE" 2>/dev/null || true
echo "ALL DONE"
