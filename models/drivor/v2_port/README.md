# DrivoR → navsim_v2 이식 기록 (S4 navhard 평가용)

DrivoR repo는 Nav1 fork라 v2 평가에 못 쓴다 (DrivoR issue #13). README의 `run_pdm_score_gpu_v2.py`는
어느 repo에도 없다 — 공식 navsim_v2 의 `run_pdm_score.py` 를 쓴다 (issue #13 답변).

## 복사한 파일
- `drivor/navsim/agents/drivoR/`  →  `navsim_v2/navsim/agents/drivoR/`  (전체 복사, 수정은 drivor_agent.py 한 곳)
- `drivor/.../config/common/agent/drivoR.yaml`  →  `navsim_v2/.../config/common/agent/drivoR.yaml`

## 수정 (drivoR_to_navsim_v2.patch)
1. `DrivoRAgent.__init__` 에 `trajectory_sampling` 인자 추가, `super().__init__(trajectory_sampling)` 로 전달.
2. yaml 에 `trajectory_sampling: TrajectorySampling(4s, 0.5s)` 주입. issue #13 팁은 `= None` 이지만,
   v2 `Trajectory.__post_init__` 이 `trajectory_sampling.num_poses` 를 읽으므로 None 이면 평가 중 실패한다.
   (v2 transfuser_agent.yaml 과 같은 방식)

3. yaml 의 학습 전용 interpolation 2개를 리터럴로 치환: `scheduler_args.num_epochs`(`${trainer.params.max_epochs}` → 10),
   `batch_size`(`${dataloader.params.batch_size}` → 16). v2 평가 config 에는 `trainer`/`dataloader` 섹션이 없어
   `InterpolationKeyError` 가 난다. 둘 다 학습(스케줄러·배치)에서만 쓰이므로 평가 결과에는 영향이 없다.

## 환경 변경
- navsim_v2 env 에 `einops==0.8.2` 설치 (drivor env 와 같은 버전).
- ⚠ timm 은 navsim_v2 1.0.30 / drivor env 1.0.15 로 다르다. 점수가 기대와 어긋나면 1순위 의심 대상.

## 실행 시 주의
- yaml 의 `image_backbone.model_weights` 가 상대 경로(`weights/...`)다. v2 에서는 절대 경로로 override 한다
  (`eval_navhard_v2.sh` 참고).
