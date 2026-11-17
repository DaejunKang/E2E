#!/usr/bin/env python
"""Qualitative 결과 생성 CLI (E-v1 환경에서 실행).

예)  source env_v1.sh
     python util/make_qualitative.py --name navtest_sample --split navtest --agents cv ltf \
         --ltf-ckpt models/ltf/ckpt/ltf/ltf_seed_0.ckpt --num 8 --seed 0
     # 평가가 끝난 뒤, LTF 가 가장 못한 장면만:
     python util/make_qualitative.py --name navtest_ltf_worst --agents ltf --ltf-ckpt ... \
         --scores ltf=exp_v1/ltf_seed0_navtest/<날짜>/<날짜>.csv --pick worst --pick-by ltf --num 12

결과: Qualitative/<name>/{index.html, manifest.json, <token>.png}
"""
import argparse
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from util import qualitative as Q  # noqa: E402


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True, help="Qualitative/<name> 으로 저장")
    p.add_argument("--split", default="navtest")
    p.add_argument("--agents", nargs="+", default=["cv"], choices=["cv", "ltf"])
    p.add_argument("--ltf-ckpt")
    p.add_argument("--num", type=int, default=8)
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--pick", default="random", choices=["random", "worst", "best"])
    p.add_argument("--pick-by", help="worst/best 기준 agent 이름 (--scores 의 키)")
    p.add_argument("--scores", nargs="*", default=[], help="agent=평가CSV 경로 (제목에 PDMS 표시)")
    p.add_argument("--tokens", nargs="*", help="직접 지정 (지정하면 --pick 무시)")
    p.add_argument("--out-root", default=str(Path(__file__).resolve().parents[1] / "Qualitative"))
    a = p.parse_args()

    scores = {kv.split("=", 1)[0]: Q.read_scores(kv.split("=", 1)[1]) for kv in a.scores}
    agents = Q.build_agents(a.agents, a.ltf_ckpt)
    loader = Q.build_scene_loader(a.split, Q.merged_sensor_config(agents))

    if a.tokens:
        tokens = a.tokens
    else:
        basis = scores.get(a.pick_by) if a.pick != "random" else None
        tokens = Q.pick_tokens(loader.tokens, a.num, a.pick, a.seed, basis)

    out = Path(a.out_root) / a.name
    rows, t0 = [], time.time()
    for i, tok in enumerate(tokens, 1):
        scene = loader.get_scene_from_token(tok)
        inp = scene.get_agent_input()
        trajs = {"human": scene.get_future_trajectory()}
        for n, ag in agents.items():
            trajs[n] = ag.compute_trajectory(inp)
        png = out / f"{tok}.png"
        Q.render_scene(scene, trajs, scores, png)
        note = "".join(f"  {k}:{v[tok]:.2f}" for k, v in scores.items() if tok in v)
        rows.append({"token": tok, "image": png.name, "note": note})
        print(f"[{i}/{len(tokens)}] {tok} ({time.time()-t0:.0f}s)", flush=True)

    Q.write_gallery(out, rows, {"split": a.split, "agents": ",".join(["human"] + a.agents),
                                "pick": a.pick, "seed": a.seed, "ltf_ckpt": a.ltf_ckpt or "-"})
    print("saved:", out / "index.html")


if __name__ == "__main__":
    main()
