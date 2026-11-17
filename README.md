# E2E

NAVSIM 기반 E2E 자율주행 모델 재현 작업 공간. 현재 단계는 **기준 모델 LTF와 DrivoR를 공식 checkpoint로 평가해 공개 점수를 재현하는 것**이다.
실행 사양은 `claude/07-navsim-baseline-run-spec.md`(S1~S5 단계와 게이트), 실행 결과는 `docs/run-report.md`에 있다.

## 현재 작업 상태

공식 checkpoint 평가(S1·S2·S4)는 전부 기대값을 재현했다. 자체 학습(S3·S5)은 스크립트만 준비했고 **아직 실행하지 않았다**.

| 모델 | split | 지표 | 기대값 | 실측 |
|---|---|---|---|---|
| Constant Velocity | navhard two-stage | EPDMS | 약 11.4 | 11.48 |
| LTF (seed 0) | navtest | PDMS | 83.8 | 84.14 |
| LTF (seed 0) | navhard two-stage | EPDMS | 25.1 | 25.12 |
| DrivoR (Train 85k, 25 ep) | navtest | PDMS | 93.1 | 93.13 |
| DrivoR (Trainval 103k, 25 ep) | navtest | PDMS | 93.7 | 93.69 |
| DrivoR (Nav2, 10 ep) | navhard two-stage | EPDMS | 48.3 | 48.31 |

- 모든 평가에서 전체 장면이 채점됐다(navtest 12146, navhard 5912, 실패 0).
- 환경: GPU 8장(RTX PRO 6000 Blackwell, sm_120), torch 2.7.1+cu128. 원 repo가 고정한 구버전에서 바꿨다(`docs/env-diff.md`).
- 미실행: S3(LTF 학습), S5(DrivoR 학습), LTF seed 1·2 평가.

### 알아둘 점
- **DrivoR navhard는 별도 환경(`envs/navsim_v2_dr`)에서 평가했다.** DrivoR repo는 NAVSIM v1 기반이라 v2 평가에 못 쓴다. 그래서 `navsim_v2`에 agent를 이식했고(`models/drivor/v2_port/`), timm을 원 저자 버전(1.0.15)으로 맞췄다.
- **v2 평가는 신경망을 CPU로 추론한다.** navhard 평가에 LTF 5.2시간, DrivoR 5.8시간이 걸렸다. 점수에는 영향이 없다.
- **학습 전에 `navsim_logs/trainval`의 폴더 중첩(`trainval/trainval/`)을 풀어야 한다.** `test`는 같은 문제를 symlink로 풀었다. 이 문제를 놓치면 오류 없이 캐시 대상이 0개가 된다.
- 그 밖의 함정과 해결은 `docs/run-report.md`의 "발견한 함정과 해결".

## 폴더 구조

```
E2E/
├── claude/            실행 사양서 (07-navsim-baseline-run-spec.md) 와 문서 안내
├── docs/              실행 보고서, 환경 차이, pip freeze, 각 repo commit 해시
├── models/            재현 대상 모델별 스크립트·checkpoint·로그  ← 평가는 여기서 실행
│   ├── ltf/           LTF 평가·학습 스크립트, ckpt/ (seed 0~2)
│   ├── drivor/        DrivoR 평가·학습 스크립트, ckpt/, v2_port/ (navsim_v2 이식 기록)
│   ├── common.sh      환경 활성화와 명령·소요시간 로그 헬퍼
│   ├── cache_*.sh     metric cache 생성 (navhard / navtest)
│   └── eval_cv_v2.sh  Constant Velocity 평가 (평가 경로 검증용)
├── util/              결과 시각화 코드 (Qualitative 생성기)
├── Qualitative/       정성 결과 (장면별 카메라 + BEV 궤적 이미지, index.html 갤러리)
├── scripts/           환경 설치, 데이터 다운로드, GPU 점검 스크립트
├── env_v1.sh  env_v2.sh  env_v2_dr.sh  env_drivor.sh    환경별 활성화 + 경로 변수
│
│  ── 아래는 git에 포함되지 않음 ──
├── navsim_v1/         NAVSIM v1.1 (upstream clone)
├── navsim_v2/         NAVSIM v2 main (upstream clone) + DrivoR agent 이식
├── drivor/            DrivoR (upstream clone, nuplan-devkit 포함)
├── envs/              가상환경 4개 (navsim_v1, navsim_v2, navsim_v2_dr, drivor)
├── dataset            → 대용량 스토리지의 데이터 (maps, navsim_logs, sensor_blobs, ...)
└── exp_v1  exp_v2  exp_drivor    → 대용량 스토리지의 metric cache·평가 결과 (symlink)
```

환경별 용도는 다음과 같다.

| 환경 | repo | 쓰는 곳 |
|---|---|---|
| `env_v1.sh` | `navsim_v1` | LTF navtest PDMS |
| `env_v2.sh` | `navsim_v2` | Constant Velocity, LTF navhard EPDMS, metric cache |
| `env_v2_dr.sh` | `navsim_v2` + timm 1.0.15 | DrivoR navhard EPDMS |
| `env_drivor.sh` | `drivor` | DrivoR navtest PDMS |

`metric cache`와 평가 결과는 환경마다 `NAVSIM_EXP_ROOT`(`exp_*`)를 다르게 둔다. evaluator 버전이 다른 cache를 섞지 않기 위해서다.

## 재현 순서

git에는 upstream repo, 환경, 데이터, checkpoint가 들어 있지 않으므로 먼저 준비한다.

1. **upstream repo**: `docs/commit_*.txt`의 commit을 checkout한다. `navsim_v1`은 v1.1 브랜치, `navsim_v2`는 main, `drivor`는 `valeoai/DrivoR`이다.
2. **환경**: `scripts/install_envs.sh <v1|v2|drivor>`로 만든다. `navsim_v2_dr`은 `docs/freeze_v2.txt`에서 timm만 1.0.15로 바꾼 복제본이다(`docs/env-diff.md`).
3. **데이터**: `scripts/download_base.sh`로 maps, warmup, navhard, test, navtrain을 받는다. 받은 뒤 위 중첩 문제를 점검한다.
4. **checkpoint**: LTF는 HuggingFace `autonomousvision/navsim_baselines`, DrivoR는 GitHub `valeoai/DrivoR` Releases(`model_weights`)에서 받아 `models/*/ckpt/`에 둔다. 무결성은 `SHA256SUMS`로 확인한다.
5. **DrivoR navhard 이식**: `models/drivor/v2_port/README.md`의 수정 3가지를 `navsim_v2`에 적용한다.
6. **평가**: 소규모 점검은 `SPLIT=warmup_two_stage`로 먼저 돌린다.

```bash
# metric cache
models/cache_navhard_v2.sh        # navhard (E-v2)
models/cache_navtest_v1.sh        # navtest (E-v1)
models/cache_navtest_drivor.sh    # navtest (E-drivor)

# 평가
models/eval_cv_v2.sh                       # CV, navhard
models/ltf/eval_navtest_v1.sh              # LTF navtest   (SEED=0|1|2)
models/ltf/eval_navhard_v2.sh              # LTF navhard   (SEED=0|1|2)
models/drivor/eval_navtest_drivor.sh       # DrivoR navtest (CKPT=... 로 ckpt 선택)
models/drivor/eval_navhard_v2.sh           # DrivoR navhard
```

학습 스크립트(`models/*/train*.sh`, `cache_train.sh`, `train_metric_cache.sh`)는 `CONFIRM_TRAIN=1` 없이는 실행되지 않는다.

## 정성 결과 확인

`util/make_qualitative.py`가 장면마다 전방 카메라와 BEV를 그리고 Human(GT), Constant Velocity, LTF 궤적을 겹친다. 평가 CSV를 주면 제목에 점수가 붙고 가장 못한 장면만 고를 수 있다.

```bash
source env_v1.sh
CUDA_VISIBLE_DEVICES="" python util/make_qualitative.py --name navtest_sample --agents cv ltf \
    --ltf-ckpt models/ltf/ckpt/ltf/ltf_seed_0.ckpt --num 8 --seed 0
```

결과는 `Qualitative/<name>/index.html`을 브라우저로 열어 본다. 한계는 navhard(synthetic scene)와 DrivoR를 아직 못 그린다는 점이다. 자세한 사용법은 `util/README.md`.

## 참고

- NAVSIM: https://github.com/autonomousvision/navsim
- DrivoR: https://github.com/valeoai/DrivoR
- LTF checkpoint: https://huggingface.co/autonomousvision/navsim_baselines
