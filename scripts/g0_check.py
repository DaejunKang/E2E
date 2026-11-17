import sys, importlib, torch
print("torch", torch.__version__, "cuda", torch.version.cuda, "arch", torch.cuda.get_arch_list())
print("devices", torch.cuda.device_count(), torch.cuda.get_device_name(0))
assert "sm_120" in torch.cuda.get_arch_list()
x = torch.randn(512, 512, device="cuda")
for dt in (torch.float16, torch.bfloat16):
    assert torch.isfinite((x.to(dt) @ x.to(dt)).float()).all()
c = torch.nn.Conv2d(3, 8, 3).cuda()
c(torch.randn(2, 3, 32, 32, device="cuda")).sum().item()
for m in sys.argv[1:]:
    mod = importlib.import_module(m); print(m, getattr(mod, "__version__", "ok"))
print("G0 OK")
