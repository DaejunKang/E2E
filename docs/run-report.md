# NAVSIM baseline loop 실행 보고
## 판정: 범위 내 완료 — S1·S2·S4 전부 게이트 통과, S3·S5(자체 학습)는 범위 제외로 미실행
(사양서 §0 의 '완료'는 S1~S5 전부 통과가 조건이므로, 전체 loop 판정은 아직 아니다.)
범위(2026-11-16~17): 공식 checkpoint 평가까지(S1, S2, S4). 자체 학습(S3, S5)은 `models/` 에 스크립트만 준비.

## 환경
- GPU: NVIDIA RTX PRO 6000 Blackwell Server Edition ×8 (97.9GB each), driver 580.126.16, CUDA 13.0 (사양서의 B200과 다름)
- CPU 256 코어, RAM 1TB
- torch: 원 버전 대비 **변경함** (2.7.1+cu128). 상세는 `env-diff.md`
- 도구: uv 0.11.27, venv python 3.9.25 (`envs/`)
- commit: navsim_v2 `0a380a9`, navsim_v1 (v1.1) `0811876`, drivor `fc6e5aa`

## G0 결과
| 환경 | sm_120 포함 | CUDA 연산(fp16/bf16/conv) | 8 GPU 인식 | 모델 smoke test | 판정 |
|---|---|---|---|---|---|
| E-v2 | ✅ | ✅ | ✅ | TransfuserModel(latent) forward ✅ | 통과 |
| E-v1 | ✅ | ✅ | ✅ | TransfuserModel(latent) forward ✅ | 통과 |
| E-drivor | ✅ | ✅ | ✅ | DINOv2 ViT-S 로컬 가중치 로드·forward ✅, drivoR 모듈 import ✅ | 통과 |

로그: `g0_<env>.txt`, 스크립트: `scripts/g0_check.py`, `smoke_ltf.py`, `smoke_dino.py`.
주의: smoke test는 임의 입력 forward이며 학습·평가 정확성은 아직 검증하지 않았다.

## 결과 요약표
| 단계 | 모델 | split | 지표 | 기대값 | 실측 | 차이 | 게이트 |
|---|---|---|---|---|---|---|---|
| S1 | Constant Velocity (E-v2) | navhard_two_stage | EPDMS | 약 11.4 | **11.48** | +0.08 | 통과 (±2) |
| S2 | LTF seed0 공식 ckpt (E-v1) | navtest | PDMS | 83.8 | **84.14** | +0.34 | 통과 (±1.0) |
| S2 | LTF seed0 공식 ckpt (E-v2) | navhard_two_stage | EPDMS | 25.1(스냅샷)/23.1(LEAD) | **25.12** | +0.02 | 통과 (21~27) |
| S4 | DrivoR Train 85k 25ep (E-drivor) | navtest | PDMS | 93.1 | **93.13** | +0.03 | 통과 (±1.5) |
| S4 | DrivoR Trainval 103k 25ep (E-drivor) | navtest | PDMS | 93.7 | **93.69** | -0.01 | 통과 (±1.5) |
| S4 | DrivoR Nav2 10ep (E-v2 이식, timm 1.0.15 env) | navhard_two_stage | EPDMS | 48.3 | **48.31** | +0.01 | 통과 (±1.5) |

- 성공 장면 수: S1·S2 navhard 5912/5912, navtest 12146/12146, 실패 0.
- 점수 CSV: `exp_v2/cv_agent_navhard_two_stage/`, `exp_v2/ltf_seed0_navhard/`, `exp_v1/ltf_seed0_navtest/` (→ `/ssd0/katech/datasets/E2E_exp/`).
- DrivoR navhard 점수 CSV: `exp_v2/drivoR_nav2_navhard_two_stage/`. navtest: `exp_drivor/ke/`.
- LTF 는 seed 0 만 평가했다. seed 1·2 는 미실행(ckpt 는 받아 둠).

## 비용 실측표
| 단계 | 소요 | 비고 |
|---|---|---|
| navhard metric cache (E-v2) | 393s | 76 로그, 5912 장면, 1.3GB |
| navtest metric cache (E-v1) | 662s | 12146 장면 |
| S1 CV navhard 평가 | 397s | ray worker (기본) |
| S2 LTF navhard 평가 | **18807s (5.2h)** | `worker=single_machine_thread_pool` (공식 템플릿 그대로). CV 대비 약 47배 |
| S2 LTF navtest 평가 | 4544s (76min) | thread pool |
| S4 DrivoR navhard 평가 | **20993s (5.8h)** | v2 `run_pdm_score.py`, CPU 추론(코어 1개). 5912/5912 성공 |
| S4 DrivoR navtest 평가 | 984s | GPU 7장 `run_pdm_score_multi_gpu.py`, 12146/12146 성공 |
| DrivoR navtest metric cache | 5364s | 다른 평가와 CPU 공유 중이라 과대. 3.1GB |
| warmup 소규모 점검 (캐시+CV) | 125s + 87s | 경로 오류 선별용 |
| E-v2 설치 | 1m45s | uv, 캐시 없는 첫 설치 |
| E-v1, E-drivor 설치 | 병렬 실행, 각 수 분 | 개별 시간 미측정 |
| 디스크 | envs 약 9.8GB(drivor 8.9GB: CUDA 라이브러리 포함), DINOv2 가중치 169MB | uv가 캐시를 hardlink로 공유해 v1/v2 수치는 실제보다 작게 보임 |

## 발견한 함정과 해결
- **navsim_logs 가 한 겹 깊게 풀려 있음**: `navsim_logs/test/test/*.pkl`(147), `trainval/trainval/*.pkl`(1310). 로더가 0 로그를 읽어 `metric caching of 0 files` 로 **오류 없이** 끝났다. 원본은 두고 `navsim_logs/test/` 에 상대 symlink 147개를 추가해 해결. **trainval 은 학습(S3/S5) 전에 같은 처리 필요**(미처리). `scripts/download_base.sh` 의 압축 해제 단계를 점검할 것.
- **백그라운드 실행 알림 오해**: `run_in_background` 안에서 `nohup ... &` 를 또 쓰면 바깥 셸 종료 시점에 '완료' 알림이 온다(실제 작업은 진행 중). 직접 백그라운드로 실행하거나 PID 를 기다릴 것.
- **`common.sh` trap 이 항상 exit=0 을 기록**: `$?` 를 산술식 뒤에 읽던 버그. 수정함(`_rc=$?`). 수정 전 로그의 `exit=0` 은 신뢰하지 말고 결과 CSV·점수 줄로 판단.
- **DrivoR v2 이식**: README 의 `run_pdm_score_gpu_v2.py` 는 어디에도 없다(공식 `run_pdm_score.py` 사용). 이슈 #13 의 `trajectory_sampling=None` 은 부족해서 yaml 에 실제 TrajectorySampling 주입. yaml 의 학습 전용 interpolation(`${trainer...}`, `${dataloader...}`)도 평가 config 에 없어 실패 → 리터럴 치환. `models/drivor/v2_port/` 참고.
- **timm 버전**: navsim_v2 requirements 는 timm 무고정(1.0.30 설치됨). 1.0.30 은 DrivoR 의 `timm/vit_small_...` 모델명을 거부한다. DrivoR 는 1.0.15 고정. v2 env(LTF 검증 완료)를 건드리지 않으려고 freeze 복제 + timm 1.0.15 인 별도 env `envs/navsim_v2_dr` 추가(`env_v2_dr.sh`).
- **v2 평가는 신경망 agent 를 CPU 로 추론한다**: `navsim_v2/.../run_pdm_score.py` 에 GPU 이동 코드가 없다. `worker=single_machine_thread_pool` 에서 프로세스가 CPU 100%(코어 1개)로 돌고 GPU 는 비어 있다. LTF navhard 5.2h, DrivoR navhard 도 같은 경로다. 점수에는 영향 없으나 신경망 agent 평가 비용이 크다. 단축하려면 GPU 추론 후 점수 계산 분리(DrivoR 의 `run_pdm_score_multi_gpu.py` 방식을 v2 로 이식)나 `worker=ray_distributed` 를 검토(미검증, 모델이 worker 마다 복제됨).
- 같은 DrivoR navtest metric cache 가 v1 은 662s, drivor repo 는 5364s: 후자는 navhard 평가와 CPU 를 나눠 쓴 상태에서 실행했다. 단독 비용으로 읽지 말 것.
- DrivoR 공식 ckpt 파일명이 사양서와 다르다: `Nav1_25epochs.pth`(Trainval 103k → 93.7), Train 85k(93.1) 는 `drivor_Nav1_train_only_85k_25epochs.ckpt`.
- 서버 GPU가 사양서의 B200(sm_100)이 아니라 sm_120이다. 사양서 §1-1 판정 기준을 sm_120으로 읽어 적용했다.
- DINOv2 (timm) 입력은 518×518이어야 한다. 224로 넣으면 patch embed assertion이 난다.
- DrivoR 설치 중 nuplan-devkit 단계에서 numpy 2.0.2가 들어왔고, 마지막 `numpy==1.26.4` 고정으로 내려갔다. 이 순서를 유지해야 한다.

## env-diff
`env-diff.md` 참조.

## 미해결
- **디스크 부족**: `/` 여유 149GB로 사양서 요구(1.5TB 이상, 데이터 약 0.75TB)에 못 미친다. 대용량 스토리지 연결 후 `dataset/`, `exp_*`를 해당 경로로 옮기거나 symlink로 교체해야 한다.
- 이후 단계(데이터, maps, 공식 checkpoint, metric cache, S1~S5) 미착수.
- DrivoR README의 Nav1 평가용 인자 등은 데이터 준비 시점에 repo 최신 README로 다시 확인한다.
