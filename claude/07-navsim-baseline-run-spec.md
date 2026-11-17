# 07 — NAVSIM baseline 학습·평가 실행 사양서 (LTF → DrivoR)

**역할**: 실행 사양 · **최종 갱신** 2026-10-14 · **실행 주체** 서버(B200 클러스터)의 Claude Code
선행 문서: `05-benchmark-sota-survey.md` (지표 체계), `06-architecture-recipe-analysis.md` (모델 구조)
표기: ✅ 1차 출처(공식 repo·README·논문)에서 확인 / △ 추정·확인 필요

> **Claude Code에게** — 이 문서는 지시서다. 각 단계의 **게이트를 통과하지 못하면 다음 단계로 넘어가지 말고** 즉시 보고한다. 명령어는 2026-10-14 기준 공식 문서에서 확인했지만, 실행 전에 **반드시 각 repo의 현재 README와 `docs/`를 다시 읽고**, 차이가 있으면 repo를 따르고 그 차이를 보고서에 기록한다.

---

## 0. 목적과 판정

**목적** — 성능 경쟁이 아니라 **전체 loop를 한 번 끝까지 돌려보는 것**이다.
데이터 → 캐시 → 학습 → 평가(navtest, navhard two-stage) → 결과 해석까지의 경로를 확보하고, 각 단계의 **소요 시간·디스크·함정**을 실측해 남긴다.

**왜 이 순서인가**

| 단계 | 모델 | 이유 |
|---|---|---|
| 1 | Constant Velocity (학습 없음) | 평가 경로만 단독 검증. 평가 문제와 학습 문제를 분리 |
| 2 | LTF 공식 checkpoint | 평가 경로 + 신경망 agent 로딩 검증. 기대값이 공식적으로 알려져 있음 |
| 3 | LTF 자체 학습 | 학습 경로 검증. 2단계 값과 비교해 학습 재현성 판정 |
| 4 | DrivoR 공식 checkpoint | 외부 repo 통합 검증 |
| 5 | DrivoR 자체 학습 | scorer 계열 학습 경로(train metric cache 포함) 검증 |

**최종 판정**

| 결과 | 조건 |
|---|---|
| **완료** | 단계 1~5 모두 게이트 통과 |
| **부분 완료** | 1~3 통과, 4~5 중 미통과 → 원인 기록 후 종료 |
| **중단** | 1 또는 2 미통과 → 평가 환경 문제. 원인 규명 전 학습 금지 |

---

## 1. 사전 점검 (G0)

### 1-1. ⚠ B200 호환성 — 가장 먼저 확인

B200은 Blackwell(sm_100)이다. **CUDA 12.8 이상으로 빌드된 PyTorch(대략 2.7 이상)가 필요하다** △.
그런데 두 repo는 모두 그보다 오래된 버전을 고정한다.

- DrivoR README: `torch==2.1.0` + `cu121` ✅
- NAVSIM `environment.yml`: 고정된 torch 버전을 확인할 것 (구버전 고정 가능성 높음) △

```bash
nvidia-smi
python -c "import torch; print(torch.__version__, torch.version.cuda, torch.cuda.get_arch_list()); \
torch.zeros(1).cuda(); print('OK')"
```

**판정**: `get_arch_list()`에 `sm_100`이 있고 CUDA 텐서 연산이 성공하면 통과.

**실패 시 처리** (순서대로 시도)

1. 기본안: torch만 cu128 빌드로 올린다. 그 뒤 pytorch-lightning, timm, numpy 호환을 하나씩 맞춘다. 변경한 버전은 전부 `docs/env-diff.md`에 기록한다.
2. 대안: 클러스터에 구세대 GPU(A100/H100) 노드가 있으면 원 버전 그대로 재현용으로 쓴다.
3. 재현 수치가 기대와 다를 때는 이 버전 변경을 1순위 원인 후보로 둔다.

### 1-2. 자원 점검

| 항목 | 확인 | 필요량 (추정) |
|---|---|---|
| 디스크 | `df -h $WORKSPACE` | 데이터 약 0.75TB + 캐시(실측 대상) → **1.5TB 이상 권장** |
| CPU 코어·RAM | `nproc`, `free -g` | metric caching이 CPU 병렬(ray/thread pool) 작업이라 코어 수가 시간을 좌우한다 |
| 네트워크 | HuggingFace, AWS S3 접근 | 데이터 다운로드 |

데이터 용량 근거 ✅ (01 §10-3): navtrain 445GB(history 제외 시 약 300GB), openscene test 약 223GB(navtest 모집단), navhard_two_stage 약 31~38GB, warmup_two_stage 약 1.2GB, nuPlan maps(용량은 다운로드 시 실측).

---

## 2. 작업공간과 환경 구성

### 2-1. 환경을 3개로 나누는 이유 ✅

| 환경 | repo / 브랜치 | 용도 |
|---|---|---|
| **E-v2** | `autonomousvision/navsim` `main` (NAVSIM v2) | navhard two-stage 평가(EPDMS). CV/LTF 평가. DrivoR v2 평가(agent 파일을 복사해 넣어서) |
| **E-v1** | `autonomousvision/navsim` `v1.1` 브랜치 | navtest **PDMS** 공식 재현(v1 leaderboard 기준) |
| **E-drivor** | `valeoai/DrivoR` (자체 Nav1 fork + nuplan-devkit 포함) | DrivoR 학습, navtest 평가 |

- DrivoR README 원문: 이 repo는 Nav1 기반이라 **Nav2 평가에는 쓸 수 없다**(issue #13). navhard 평가는 공식 navsim v2 repo에 DrivoR agent 파일과 config를 복사해서 한다 ✅.
- 데이터는 세 환경이 공유한다. 같은 `OPENSCENE_DATA_ROOT`와 `NUPLAN_MAPS_ROOT`를 가리킨다.
- **metric cache와 실험 결과는 환경별로 분리한다.** `NAVSIM_EXP_ROOT`를 환경마다 다르게 둔다. evaluator 버전이 다른 cache를 섞으면 안 된다.

### 2-2. 디렉터리

```
$WORKSPACE/
├── navsim_v2/            # E-v2 (main)
├── navsim_v1/            # E-v1 (v1.1)
├── drivor/               # E-drivor
├── dataset/              # 공유
│   ├── maps/
│   ├── navsim_logs/{trainval,test,...}
│   ├── sensor_blobs/{trainval,test,...}
│   ├── navhard_two_stage/
│   └── warmup_two_stage/
├── exp_v2/  exp_v1/  exp_drivor/   # 환경별 NAVSIM_EXP_ROOT
└── docs/                 # 보고서·기록
```

### 2-3. 환경 변수 (환경별로 2개만 바꾼다) ✅

```bash
export NUPLAN_MAP_VERSION="nuplan-maps-v1.0"
export NUPLAN_MAPS_ROOT="$WORKSPACE/dataset/maps"
export OPENSCENE_DATA_ROOT="$WORKSPACE/dataset"
export NAVSIM_DEVKIT_ROOT="$WORKSPACE/<navsim_v2|navsim_v1|drivor>"   # 환경별
export NAVSIM_EXP_ROOT="$WORKSPACE/<exp_v2|exp_v1|exp_drivor>"        # 환경별
export HYDRA_FULL_ERROR=1
```

권장: 환경마다 `env_<name>.sh` 파일로 만들어 `source`해서 쓴다.

### 2-4. 설치

**E-v2 / E-v1** — `docs/install.md`를 따른다 ✅. 요지는 clone → (v1은 `git checkout v1.1`) → conda env 생성(repo의 environment 파일) → `pip install -e .` 이다.

**E-drivor** ✅ (README 원문)

```bash
conda create -n drivoR python=3.9 && conda activate drivoR
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu121   # ⚠ B200이면 §1-1 처리
pip install -e ./nuplan-devkit
pip install -e .
pip install numpy==1.26.4   # README known issue (Os metric)
```

- README에 있는 `module load ...` 줄은 원 저자 클러스터 전용이다. 여기서는 무시하고 우리 환경에 맞춘다.
- DINOv2 backbone 가중치를 받아 `./weights/vit_small_patch14_reg4_dinov2.lvd142m/`에 둔다. 출처: `huggingface.co/timm/vit_small_patch14_reg4_dinov2.lvd142m` ✅.

**기록**: 환경마다 `pip freeze > docs/freeze_<env>.txt`, `git rev-parse HEAD > docs/commit_<env>.txt`.

---

## 3. 데이터 다운로드

다운로드 스크립트는 navsim repo의 `download/` 폴더에 있다 ✅.

| 데이터 | 스크립트 | 용도 |
|---|---|---|
| nuPlan maps | maps 다운로드 스크립트 | 모든 평가·캐싱 (필수) |
| navtrain | `download_navtrain_hf.sh` 또는 `_aws.sh` ✅ | 학습. ⚠ **trainval logs(14GB)도 필요** ✅ |
| openscene test (navtest 모집단) | test split 스크립트 | navtest 평가 |
| navhard_two_stage | `download_navhard_two_stage.sh` ✅ | v2 평가. synthetic frame 포함 |
| warmup_two_stage | `download_warmup_two_stage.sh` ✅ | 소규모 sanity check |

**규칙** ✅ — `test`, `navtest`, `navhard_two_stage`, `warmup_two_stage`, `private_test_*`는 **학습 사용 금지**다. 학습 경로에서 물리적으로 분리한다(02 §5-2).

**기록**: 데이터별로 `du -sh`, 다운로드 소요 시간, 실패 및 재시도 여부.

---

## 4. 단계별 실행과 게이트

모든 단계에서 다음을 기록한다.
- 실행한 정확한 명령
- wall-clock 시간, GPU 수 × 시간
- 생성된 cache·결과 파일 크기
- 점수 CSV 경로
- 기대값과의 차이

### S1. Constant Velocity로 평가 경로 검증 (E-v2)

**절차**

1. navhard_two_stage용 metric cache를 생성한다.
   - `scripts/evaluation/run_metric_caching.sh`를 참고한다.
   - `train_test_split=navhard_two_stage`와 `metric_cache_path`를 지정한다.
2. constant velocity agent로 two-stage 평가를 실행한다.
   - `run_cv_pdm_score_evaluation.sh` 계열 스크립트를 쓴다 ✅.
   - `synthetic_sensor_path=$OPENSCENE_DATA_ROOT/navhard_two_stage/sensor_blobs`
   - `synthetic_scenes_path=$OPENSCENE_DATA_ROOT/navhard_two_stage/synthetic_scene_pickles`

**기대값**: navhard EPDMS **약 11.4** (NAVSIM v2 논문의 leaderboard 스냅샷, 2026-03) ✅

**게이트**

| 판정 | 조건 | 비고 |
|---|---|---|
| 통과 | ±2 이내 | |
| 조건부 통과 | ±5 이내 | evaluator 버전 차이 가능 → §6 #1 확인 |
| 실패 | 그 밖 | 실패 시 보고 |

추가 확인: 결과 CSV에 Stage 1과 Stage 2 sub-score(NC, DAC, DDC, TLC, EP, TTC, LK, HC, EC)가 모두 나오는지 확인한다.

### S2. LTF 공식 checkpoint 평가

**절차**

1. checkpoint를 받는다: `huggingface.co/autonomousvision/navsim_baselines` ✅.
2. LTF 설정은 `agent=transfuser_agent agent.config.latent=True` ✅.
3. 평가를 두 번 실행한다.

| 평가 | 환경 | split | 기대값 | 출처 |
|---|---|---|---|---|
| navtest PDMS | E-v1 | `navtest` (먼저 navtest metric cache 생성) | **83.8** | NAVSIM v1 Table 1 ✅ |
| navhard EPDMS | E-v2 | `navhard_two_stage` | **25.1** (스냅샷) 또는 **23.1** (LEAD 논문) | 출처 간 불일치 ✅ |

**게이트**

| 판정 | 조건 |
|---|---|
| 통과 | navtest PDMS ±1.0 이내, navhard EPDMS 21~27 범위 |
| 실패 | 그 밖 → 평가 환경 문제로 판단하고 **중단** |

참고: 공식 TransFuser(LiDAR)의 navtest 기대값은 PDMS 84.0이다 ✅. 시간 여유가 있으면 함께 확인한다.

### S3. LTF 자체 학습 (E-v2, 필요하면 E-v1에서도)

**절차** ✅

```bash
# 1) feature/target cache
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_dataset_caching.py \
  agent=transfuser_agent agent.config.latent=True \
  train_test_split=navtrain cache_path=$NAVSIM_EXP_ROOT/training_cache

# 2) 학습
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
  agent=transfuser_agent agent.config.latent=True \
  experiment_name=training_ltf_seed0 train_test_split=navtrain \
  cache_path=$NAVSIM_EXP_ROOT/training_cache \
  use_cache_without_dataset=true force_cache_computation=false
```

- 기본 레시피 ✅: Adam, lr 1e-4, batch 64, 100 epoch, 16-mixed, ddp. 원 논문 조건은 "1 GPU, 1 day"이다.
- **재현이 목적이므로 effective batch(64)와 lr을 바꾸지 않는다.**
  - 1 GPU로 돌리는 것이 가장 깔끔하다.
  - 멀티 GPU를 쓰면 per-GPU batch를 64/N으로 맞춘다. 이때 config의 batch 값이 per-GPU 기준인지 먼저 확인한다 △.

**평가**: S2와 같은 방법으로 navtest PDMS와 navhard EPDMS를 잰다.

**게이트**

| 판정 | 조건 |
|---|---|
| 통과 | S2 공식 checkpoint 대비 navtest PDMS **±1.7 이내** (공식 3-seed 표준편차 0.56의 3σ ✅) |
| 실패 | 그 밖 → 학습 설정 차이를 조사한다. 우선순위는 torch 버전 변경, batch/lr, epoch 순 |

**선택**: 시간이 되면 seed를 3개 돌려 분산까지 실측한다. 우리 환경의 seed 분산은 이후 모든 ablation 판정의 기준선이 된다.

### S4. DrivoR 공식 checkpoint 평가

**절차**

1. checkpoint를 받는다. 위치는 DrivoR repo의 GitHub Releases다 ✅. 파일명(`Nav1_25epochs.pth`, `Nav2_10epochs.pth` 등)과 학습 데이터 구성을 releases 페이지에서 확인해 기록한다.
2. navtest 평가 (E-drivor) — README 명령을 그대로 쓴다 ✅.
   - 실행 파일: `run_pdm_score_multi_gpu.py`
   - 인자: `agent=drivoR`, `agent.config.proposal_num=64`
   - scorer 가중치: `noc=1 dac=1 ddc=0.0 ttc=5 ep=5 comfort=2`
   - 그 밖의 `agent.config.*` 값은 README 원문을 복사한다.
3. navhard 평가 (E-v2)
   - DrivoR의 agent 파일과 config를 navsim_v2에 복사한다. 복사한 파일 목록을 기록한다.
   - `run_pdm_score_gpu_v2.py`로 실행한다 ✅.
   - scorer 가중치: `noc=10 dac=13 ddc=6 ttc=14 ep=15 comfort=2` ✅.

**기대값** (DrivoR README 표) ✅

| 평가 | 학습 데이터 | 기대값 |
|---|---|---|
| navtest PDMS | Train 85k, 25 ep | 93.1 |
| navtest PDMS | Trainval 103k | 93.7 |
| navhard EPDMS | Train 85k, 10 ep | **48.3** |
| navhard EPDMS | + SimScale 134k | 54.6 |

> 📌 이 표가 05 문서의 "DrivoR 54.5 vs 48.3 불일치"를 설명한다. leaderboard의 54.5는 **SimScale 합성 데이터 134k를 추가한 모델**이고, 48.3은 **navtrain만 쓴 기본 모델**이다. 우리가 재현할 대상은 **48.3**이다.

**게이트**

| 판정 | 조건 |
|---|---|
| 통과 | 각각 ±1.5 이내 |
| 실패 | navhard만 크게 벗어나면 §6 #1(evaluator 버전)과 #3(numpy)을 먼저 의심한다 |

### S5. DrivoR 자체 학습 (E-drivor)

**절차** ✅

```bash
# 1) 학습용 metric cache — scorer 학습 라벨(PDM sub-score)을 만든다. LTF에는 없던 단계.
python navsim/planning/script/run_train_metric_caching.py

# 2) NAVSIM v2용 학습 (10 epoch) — README 명령을 사용. ⚠ §6 #4 참고
python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
  agent=drivoR experiment_name=training_drivoR_Nav2_10epochs \
  train_test_split=navtrain cache_path=null use_cache_without_dataset=false \
  trainer.params.max_epochs=10 dataloader.params.prefetch_factor=1 \
  dataloader.params.batch_size=16 agent.lr_args.name=AdamW agent.lr_args.base_lr=0.0002 \
  agent.num_gpus=4 agent.progress_bar=false \
  <README의 나머지 agent.config.* 인자 전부> \
  agent.loss.prev_weight=0.0 \
  seed=2
```

- 원 조건 ✅: 4×A100, per-GPU batch 16(global 64), AdamW, lr 2e-4 cosine.
- B200을 쓸 때 재현이 목적이면 **4 GPU × 16을 유지한다.** 8 GPU를 쓰려면 per-GPU 8로 global 64를 맞춘다.
- v1(navtest PDMS)용 25 epoch 학습은 선택이다. `run_training_full.py`를 쓰고 `long_trajectory_additional_poses=2`를 준다 ✅.

**평가**: S4와 같은 방법.

**게이트**

| 판정 | 조건 |
|---|---|
| 통과 | S4 공식 checkpoint 대비 navhard EPDMS ±2.0 이내 |

DrivoR 논문은 epoch를 늘리면 EPDMS가 떨어진다고 보고했다 ✅. 따라서 epoch는 10을 고정한다.

**추가 기록**: train metric cache 생성 시간과 크기를 따로 남긴다. 이 비용은 scorer 계열을 다른 데이터셋으로 확장할 때의 핵심 비용이다(02 문서 및 06 §6 연계).

---

## 5. 산출물

`docs/run-report.md`에 누적한다.

```markdown
# NAVSIM baseline loop 실행 보고
## 판정: 완료 / 부분 완료 / 중단
## 환경: GPU, 드라이버, CUDA, torch(원 버전 대비 변경 여부), 3개 env의 commit hash
## 결과 요약표
| 단계 | 모델 | split | 지표 | 기대값 | 실측 | 차이 | 게이트 |
## 비용 실측표 (pipeline 경험의 핵심 산출물)
| 단계 | wall-clock | GPU·h | CPU 코어 | 디스크 증가 |
  (다운로드 / metric cache(test·navhard) / dataset cache / train metric cache / LTF 학습 / DrivoR 학습 / 각 평가)
## 발견한 함정과 해결
## env-diff (원 repo 대비 바꾼 버전·코드)
## 미해결
```

**부수 산출물**

- `scripts/` — 단계별 실행 스크립트. 환경 변수 포함, 재실행 가능해야 한다.
- `env_*.sh`, `freeze_*.txt`, `commit_*.txt`
- 결과 CSV 원본 (scene 단위 sub-score 포함). 이후 failure 분석(Stage 2 LK 급락 등)에 쓴다.

---

## 6. ⚠ 알려진 함정

| # | 함정 | 대응 |
|---|---|---|
| 1 | **evaluator 버전에 따라 점수가 달라진다.** navsim 2025-09-29 bugfix가 metric filtering을 수정했다 ✅. 05 문서의 EPDMS*(수정 전)와 EPDMS(수정 후)가 갈린 원인으로 추정된다 △ | 사용한 navsim commit을 반드시 기록한다. 기대값의 출처 시점과 비교해 해석한다 |
| 2 | **B200과 torch 버전 불일치** | §1-1 |
| 3 | DrivoR Os metric 문제 | `numpy==1.26.4`로 고정한 뒤 navhard caching을 다시 한다 (README, issue #47) ✅ |
| 4 | **DrivoR README의 v2 학습 명령**에서 `agent.loss.prev_weight=0.0` 뒤에 `\`가 빠져 있다 ✅ | 그대로 붙여 넣으면 `seed=2`가 별도 명령으로 실행되고 seed가 적용되지 않는다. 줄바꿈을 수정한다 |
| 5 | DrivoR repo(Nav1 fork)로는 v2 평가가 안 된다 ✅ | §2-1 |
| 6 | DrivoR scorer의 comfort 가중치가 평가에서는 2, submission 스크립트에서는 2.1이다 ✅ | 평가 시 2를 쓴다. 차이를 기록한다 |
| 7 | LTF는 별도 agent가 없다 ✅ | `transfuser_agent` + `agent.config.latent=True`. 빠뜨리면 LiDAR를 쓰는 TransFuser가 학습된다 |
| 8 | navtrain만 받으면 학습이 안 될 수 있다 ✅ | trainval **logs**도 필요하다 |
| 9 | LTFv6 checkpoint 출력은 CARLA left-handed 좌표다 ✅ | 이번 범위 밖이지만, 쓸 경우 ISO 8855로 변환한다 |
| 10 | 평가 split 오염 | 학습 config의 `train_test_split`이 `navtrain`인지 매번 확인한다. 캐시 디렉터리도 split별로 분리한다 |

---

## 7. 범위 밖 (하지 말 것)

- SimScale 합성 데이터 학습 (54.6 재현). 다음 단계 후보로만 기록한다.
- 하이퍼파라미터 튜닝, 모델 수정
- 공식 leaderboard 제출
- py123d 통합 (04 PoC와 별개로 진행)

---

## 8. 참고

- NAVSIM: https://github.com/autonomousvision/navsim (`docs/install.md`, `docs/splits.md`, `docs/agents.md`, `docs/metrics.md`, `docs/submission.md`)
- NAVSIM baseline checkpoints: https://huggingface.co/autonomousvision/navsim_baselines
- DrivoR: https://github.com/valeoai/DrivoR · arXiv 2601.05083 (CVPR 2026)
- DINOv2 ViT-S reg4: https://huggingface.co/timm/vit_small_patch14_reg4_dinov2.lvd142m
- NAVSIM v1 논문(LTF 83.8): arXiv 2406.15349 · NAVSIM v2 논문(navhard 스냅샷): arXiv 2506.04218
- LTFv6 (다음 단계 후보): https://github.com/kesai-labs/lead `cvpr2026` 브랜치 · https://huggingface.co/ln2697/ltfv6-navsim