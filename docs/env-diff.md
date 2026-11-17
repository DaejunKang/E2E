# env-diff — 원 repo 대비 변경 사항 (2026-10-14)

| # | 항목 | 원 사양 | 실제 | 사유 |
|---|---|---|---|---|
| 1 | GPU | B200 (sm_100) | RTX PRO 6000 Blackwell ×8 (sm_120), driver 580.126.16 | 서버 실제 구성 |
| 2 | torch / torchvision (E-v2, E-v1) | 2.0.1 / 0.15.2 (cu 미지정) | **2.7.1+cu128 / 0.22.1+cu128** | sm_120 지원에 CUDA 12.8+ 빌드 필요 (§1-1 기본안) |
| 3 | torch / torchvision / torchaudio (E-drivor) | 2.1.0 / 0.16.0 / 2.1.0 (cu121) | **2.7.1 / 0.22.1 / 2.7.1 (cu128)** | 동일 |
| 4 | Python 환경 도구 | conda (python=3.9) | uv venv (python 3.9.25) | 서버에 conda 없음. 사용자 결정 |
| 5 | `nb_conda_kernels` | environment.yml에 포함 | 설치 안 함 | conda 전용 노트북 커널 도구. 학습·평가와 무관 |
| 6 | E-drivor numpy | nuplan-devkit 1.23.4 → README 1.26.4 | 1.26.4 | README known issue 그대로 (§6 #3) |
| 7 | E-drivor 설치 | README의 `module load ...` | 생략 | 원 저자 클러스터 전용 |

`uv pip check`: E-v2/E-v1은 navsim의 `torch==2.0.1`, `torchvision==0.15.2` 고정과 충돌한다고 보고한다. #2의 의도한 변경이다. E-drivor는 충돌 없음.
재현 수치가 기대와 다르면 #2, #3을 1순위 원인 후보로 둔다 (§1-1).

## 설치된 주요 버전
| env | pytorch-lightning | hydra-core | numpy | timm | commit |
|---|---|---|---|---|---|
| E-v2 (main) | 2.2.1 | 1.2.0 | 1.23.4 | 1.0.30 | 0a380a9 |
| E-v1 (v1.1) | 2.2.1 | 1.2.0 | 1.23.4 | 1.0.30 | 0811876 |
| E-drivor | 2.4.0 | 1.3.2 | 1.26.4 | 1.0.15 | fc6e5aa |

전체 목록은 `freeze_<env>.txt`, 전체 commit은 `commit_<env>.txt`.

## 2026-11-16 — models/ 재현 셋업
- navsim_v2 env: `einops==0.8.2` 추가 (DrivoR agent 이식용). timm 1.0.30 은 유지 (drivor env 는 1.0.15, 차이 기록).
- navsim_v2 repo: `navsim/agents/drivoR/`, `config/common/agent/drivoR.yaml` 추가 (`models/drivor/v2_port/` 참고).
- dataset: `navsim_logs/test/` 에 `test/*.pkl` 상대 symlink 147개 추가 (원본이 `test/test/` 로 한 겹 깊게 풀려 있었음).
- 4번째 env `envs/navsim_v2_dr` (`env_v2_dr.sh`): `docs/freeze_v2.txt` 복제 + `timm==1.0.15`(DrivoR 원 저자 버전) + `einops==0.8.2`. navsim_v2 소스를 editable(`--no-deps`)로 공유. DrivoR navhard 평가 전용. navsim_v2 env 의 einops/timm 변경은 LTF 검증 이후에도 timm 은 1.0.30 유지.
- `models/common.sh`: trap exit code 기록 버그 수정.
