# models/ — 재현 대상 E2E 모델 (LTF, DrivoR)

코드와 환경은 상위의 `navsim_v1/`, `navsim_v2/`, `drivor/`, `envs/` 를 재사용한다. 이 폴더에는 checkpoint, 실행 스크립트, 로그만 둔다.
상세 결과·비용·함정은 `../docs/run-report.md`.

## 상태 (2026-11-17, 공식 ckpt 평가까지)
| 모델 | split | 지표 | 기대값 | 실측 | 게이트 | 스크립트 |
|---|---|---|---|---|---|---|
| Constant Velocity | navhard | EPDMS | ~11.4 | 11.48 | 통과 | `eval_cv_v2.sh` |
| LTF seed0 | navtest | PDMS | 83.8 | 84.14 | 통과 | `ltf/eval_navtest_v1.sh` |
| LTF seed0 | navhard | EPDMS | 25.1 | 25.12 | 통과 | `ltf/eval_navhard_v2.sh` |
| DrivoR Train 85k | navtest | PDMS | 93.1 | 93.13 | 통과 | `drivor/eval_navtest_drivor.sh` |
| DrivoR Trainval 103k | navtest | PDMS | 93.7 | 93.69 | 통과 | 위와 같음 (`CKPT=` 지정) |
| DrivoR Nav2 10ep | navhard | EPDMS | 48.3 | 48.31 | 통과 | `drivor/eval_navhard_v2.sh` |

자체 학습(S3 LTF, S5 DrivoR)은 **미실행**. 스크립트만 있고 `CONFIRM_TRAIN=1` 없이는 실행되지 않는다.
LTF seed 1·2 도 미평가(ckpt 는 `ltf/ckpt/ltf/` 에 있음).

## 실행 순서와 환경
| 환경 | 용도 |
|---|---|
| `env_v2.sh` | CV·LTF navhard, 캐시 |
| `env_v1.sh` | LTF navtest |
| `env_drivor.sh` | DrivoR navtest |
| `env_v2_dr.sh` | DrivoR navhard (timm 1.0.15, 이식 agent) |

캐시: `cache_navhard_v2.sh`, `cache_navtest_v1.sh`, `cache_navtest_drivor.sh`. 모든 스크립트는 `models/**/logs/` 에 명령·소요시간 로그를 남긴다.
소규모 경로 점검: `SPLIT=warmup_two_stage` (cache_navhard_v2.sh, eval_cv_v2.sh, drivor/eval_navhard_v2.sh).

## 주의
- 학습(S3/S5) 전에 `dataset/navsim_logs/trainval` 의 중첩(`trainval/trainval/`) 해결 필요 (run-report 참고).
- v2 평가는 CPU 추론이라 신경망 agent 는 5시간대가 걸린다.
- 정성 확인: `../Qualitative/`, 코드는 `../util/`.
