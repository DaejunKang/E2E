import timm, torch
m = timm.create_model("vit_small_patch14_reg4_dinov2.lvd142m", pretrained=True, pretrained_cfg_overlay=dict(file="/home/daejun/E2E/drivor/weights/vit_small_patch14_reg4_dinov2.lvd142m/model.safetensors"), num_classes=0).cuda().eval()
with torch.no_grad(): print(m(torch.randn(1, 3, 518, 518).cuda()).shape)
import navsim.agents.drivoR as d; print("drivoR import OK", d.__file__)
