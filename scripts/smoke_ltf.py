import inspect, torch
from navsim.agents.transfuser.transfuser_config import TransfuserConfig
from navsim.agents.transfuser.transfuser_model import TransfuserModel
cfg = TransfuserConfig(); cfg.latent = True
if "trajectory_sampling" in inspect.signature(TransfuserModel.__init__).parameters:  # navsim v2
    from nuplan.planning.simulation.trajectory.trajectory_sampling import TrajectorySampling
    m = TransfuserModel(TrajectorySampling(time_horizon=4, interval_length=0.5), cfg)
else:  # navsim v1.1
    m = TransfuserModel(cfg)
m = m.cuda().eval()
feat = {"camera_feature": torch.randn(1, 3, 256, 1024).cuda(),
        "lidar_feature": torch.randn(1, 1, 256, 256).cuda(),
        "status_feature": torch.randn(1, 8).cuda()}
with torch.no_grad(): out = m(feat)
print({k: tuple(v.shape) for k, v in out.items() if hasattr(v, "shape")})
print("LTF forward OK")
