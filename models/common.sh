# 공통 헬퍼. 사용: source common.sh <env: v1|v2|drivor> <logname>
# env 활성화 + 명령/소요시간 로그 (models/<model>/logs 는 호출 스크립트가 LOGDIR 로 지정)
WS=/home/daejun/E2E
case "$1" in v1) source $WS/env_v1.sh;; v2dr) source $WS/env_v2_dr.sh;; v2) source $WS/env_v2.sh;; drivor) source $WS/env_drivor.sh;; *) echo "env?"; return 1;; esac
LOGDIR=${LOGDIR:-$WS/models/logs}; mkdir -p "$LOGDIR"
LOG="$LOGDIR/$2_$(date +%Y%m%d_%H%M%S).log"
_t0=$(date +%s)
echo "[start] $(date) env=$1 commit=$(git -C $NAVSIM_DEVKIT_ROOT rev-parse --short HEAD 2>/dev/null)" | tee -a "$LOG"
trap '_rc=$?; echo "[end] elapsed=$(( $(date +%s)-_t0 ))s exit=$_rc" | tee -a "$LOG"' EXIT
exec > >(tee -a "$LOG") 2>&1
