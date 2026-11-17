"""Qualitative 시각화 라이브러리 (E-v1 환경, navtest 같은 실제 장면 대상).

장면마다 [전방 카메라 | BEV] 한 장을 그린다. BEV 위에 사람(GT) 궤적과 agent 궤적들을 겹친다.
NAVSIM 의 navsim.visualization 을 재사용한다. 이 모듈은 평가 점수를 새로 계산하지 않고,
이미 나온 평가 CSV(`token`, `score` 컬럼)를 읽어 그림 제목에 붙이기만 한다.

※ navhard_two_stage 는 synthetic scene 이라 이 경로로 그릴 수 없다 (SceneLoader 가 다름).
"""
from __future__ import annotations

import copy
import csv
import html
import json
import os
import random
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402

AGENT_COLORS = {"human": "#9467bd", "cv": "#7f7f7f", "ltf": "#d62728"}
AGENT_LABELS = {"human": "Human (GT)", "cv": "Constant Velocity", "ltf": "LTF"}


# ---------------------------------------------------------------- data
def build_scene_loader(split: str, sensor_config):
    """navsim_v1 의 train_test_split/<split>.yaml 로 SceneLoader 를 만든다."""
    from hydra.utils import instantiate
    from omegaconf import OmegaConf

    from navsim.common.dataloader import SceneLoader

    root = Path(os.environ["NAVSIM_DEVKIT_ROOT"]) / "navsim/planning/script/config/common/train_test_split"
    data_split = OmegaConf.load(root / f"{split}.yaml").get("data_split", "test")
    scene_filter = instantiate(OmegaConf.load(root / "scene_filter" / f"{split}.yaml"))
    data = Path(os.environ["OPENSCENE_DATA_ROOT"])
    return SceneLoader(
        data_path=data / "navsim_logs" / data_split,
        sensor_blobs_path=data / "sensor_blobs" / data_split,
        scene_filter=scene_filter,
        sensor_config=sensor_config,
    )


def build_agents(names: List[str], ltf_ckpt: Optional[str] = None) -> Dict[str, object]:
    """사용할 agent 객체들 (human 은 scene 에서 직접 꺼내므로 여기엔 없다). LTF 는 CPU 추론."""
    agents = {}
    for n in names:
        if n == "cv":
            from navsim.agents.constant_velocity_agent import ConstantVelocityAgent

            agents[n] = ConstantVelocityAgent()
        elif n == "ltf":
            from navsim.agents.transfuser.transfuser_agent import TransfuserAgent
            from navsim.agents.transfuser.transfuser_config import TransfuserConfig

            if not ltf_ckpt:
                raise ValueError("--ltf-ckpt 가 필요하다")
            agents[n] = TransfuserAgent(TransfuserConfig(latent=True), lr=1e-4, checkpoint_path=ltf_ckpt)
        else:
            raise ValueError(f"unknown agent '{n}' (지원: cv, ltf)")
        agents[n].initialize()
    return agents


def merged_sensor_config(agents: Dict[str, object]):
    """agent 들이 요구하는 센서 + 전방 카메라(현재 프레임)를 합친 SensorConfig."""
    from dataclasses import asdict

    from navsim.common.dataclasses import SensorConfig

    merged = asdict(SensorConfig.build_no_sensors())
    merged["cam_f0"] = [3]  # 표시용 전방 카메라, 현재 프레임(history 4 -> index 3)
    for a in agents.values():
        for k, v in asdict(a.get_sensor_config()).items():
            cur = merged[k]
            if v is True or cur is True:
                merged[k] = True
            elif isinstance(v, list):
                merged[k] = sorted(set(cur if isinstance(cur, list) else []) | set(v))
    return SensorConfig(**merged)


def read_scores(path: str) -> Dict[str, float]:
    """평가 CSV 의 token -> score. 마지막 'average' 같은 비-token 행은 제외."""
    out = {}
    with open(path) as f:
        for r in csv.DictReader(f):
            tok, sc = r.get("token", ""), r.get("score", "")
            if tok and sc not in ("", None):
                try:
                    out[tok] = float(sc)
                except ValueError:
                    pass
    return out


def pick_tokens(all_tokens: List[str], n: int, mode: str, seed: int, scores: Optional[Dict[str, float]]) -> List[str]:
    """random | worst | best. worst/best 는 점수 CSV 가 있어야 한다."""
    if mode == "random":
        return random.Random(seed).sample(all_tokens, min(n, len(all_tokens)))
    if not scores:
        raise ValueError(f"--pick {mode} 는 --scores 가 필요하다")
    ranked = sorted((t for t in all_tokens if t in scores), key=lambda t: scores[t], reverse=(mode == "best"))
    return ranked[:n]


# ---------------------------------------------------------------- rendering
def render_scene(scene, trajectories: Dict[str, object], scores: Dict[str, Dict[str, float]], out_png: Path) -> None:
    """[전방 카메라 | BEV + 궤적] 한 장을 저장한다.

    trajectories: {'human': Trajectory, 'cv': Trajectory, ...},  scores: {agent: {token: score}}
    """
    from navsim.visualization.bev import add_configured_bev_on_ax, add_trajectory_to_bev_ax
    from navsim.visualization.camera import add_camera_ax
    from navsim.visualization.config import TRAJECTORY_CONFIG
    from navsim.visualization.plots import configure_ax, configure_bev_ax

    frame_idx = scene.scene_metadata.num_history_frames - 1
    frame = scene.frames[frame_idx]
    token = scene.scene_metadata.initial_token

    fig, (ax_cam, ax_bev) = plt.subplots(1, 2, figsize=(14, 5.2), gridspec_kw={"width_ratios": [1.6, 1]})
    add_camera_ax(ax_cam, frame.cameras.cam_f0)
    configure_ax(ax_cam)

    add_configured_bev_on_ax(ax_bev, scene.map_api, frame)
    handles = []
    for name, traj in trajectories.items():  # human 이 먼저 그려져 아래에 깔린다
        cfg = copy.deepcopy(TRAJECTORY_CONFIG["human" if name == "human" else "agent"])
        for k in ("fill_color", "line_color"):
            cfg[k] = AGENT_COLORS.get(name, "#1f77b4")
        add_trajectory_to_bev_ax(ax_bev, traj, cfg)
        label = AGENT_LABELS.get(name, name)
        s = scores.get(name, {}).get(token)
        if s is not None:
            label += f"  PDMS {s:.2f}"
        handles.append(plt.Line2D([0], [0], color=cfg["line_color"], marker="o", lw=2, label=label))
    configure_bev_ax(ax_bev)
    configure_ax(ax_bev)
    ax_bev.legend(handles=handles, loc="lower center", bbox_to_anchor=(0.5, -0.17), fontsize=9, frameon=False)

    speed = float(np.linalg.norm(frame.ego_status.ego_velocity))
    fig.suptitle(f"{scene.scene_metadata.log_name}  |  token {token}  |  ego speed {speed:.1f} m/s", fontsize=10)
    fig.tight_layout()
    out_png.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_png, dpi=110, bbox_inches="tight")
    plt.close(fig)


def write_gallery(out_dir: Path, rows: List[dict], meta: dict) -> None:
    """index.html (이미지 그리드) 와 manifest.json 을 쓴다. 이미지는 상대 경로."""
    (out_dir / "manifest.json").write_text(json.dumps({"meta": meta, "scenes": rows}, indent=2, ensure_ascii=False))
    cards = "\n".join(
        f'<figure><a href="{html.escape(r["image"])}"><img loading="lazy" src="{html.escape(r["image"])}"></a>'
        f'<figcaption>{html.escape(r["token"])}{html.escape(r.get("note", ""))}</figcaption></figure>'
        for r in rows
    )
    head = " · ".join(f"{k}={html.escape(str(v))}" for k, v in meta.items())
    (out_dir / "index.html").write_text(
        "<!doctype html><meta charset=utf-8><title>Qualitative</title>"
        "<style>body{font:14px sans-serif;margin:16px;background:#fafafa}"
        "main{display:grid;grid-template-columns:repeat(auto-fill,minmax(560px,1fr));gap:12px}"
        "img{width:100%}figure{margin:0;background:#fff;border:1px solid #ddd;padding:6px}"
        "figcaption{font:12px monospace;color:#555}</style>"
        f"<h3>Qualitative samples</h3><p>{head}</p><main>{cards}</main>"
    )
