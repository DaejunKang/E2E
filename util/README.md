# util/ — 결과 시각화 코드 모음

| 파일 | 역할 |
|---|---|
| `qualitative.py` | 라이브러리: SceneLoader/agent 구성, 장면 선택(random/worst/best), 그림 렌더링, 갤러리 HTML 생성 |
| `make_qualitative.py` | CLI. 결과는 `Qualitative/<name>/` 에 저장 |

## 사용 (E-v1 환경, 실제 장면 navtest 대상)
```bash
source env_v1.sh
# 무작위 8장면: Human(GT) + Constant Velocity + LTF
CUDA_VISIBLE_DEVICES="" python util/make_qualitative.py --name navtest_sample --agents cv ltf \
    --ltf-ckpt models/ltf/ckpt/ltf/ltf_seed_0.ckpt --num 8 --seed 0

# LTF navtest 평가가 끝난 뒤: 점수 CSV 를 주면 제목에 PDMS 가 붙고, 가장 못한 장면만 고를 수 있다
CUDA_VISIBLE_DEVICES="" python util/make_qualitative.py --name navtest_ltf_worst --agents ltf \
    --ltf-ckpt models/ltf/ckpt/ltf/ltf_seed_0.ckpt \
    --scores ltf=exp_v1/ltf_seed0_navtest/<날짜>/<날짜>.csv --pick worst --pick-by ltf --num 12
```
`--tokens t1 t2 ...` 로 장면을 직접 지정할 수도 있다.

## 한계
- navhard_two_stage(synthetic scene)는 SceneLoader 가 달라 아직 못 그린다.
- DrivoR 는 아직 미지원 (E-drivor / v2 이식 agent 필요). `build_agents()` 에 항목을 추가하면 된다.
- LTF 는 CPU 로 추론한다 (평가 작업과 GPU 를 다투지 않도록). 장면당 약 1초.
