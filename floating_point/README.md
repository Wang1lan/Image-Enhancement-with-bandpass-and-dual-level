# 浮点版本运行说明

本目录保存当前 `demo.m` 及其 10 个依赖函数。源码、算法参数、接口和输出保持原样；部分辅助函数内部使用整数运算，整体仍归类为浮点版本，供后续定点化对照。

## 环境与目录

- MATLAB R2022a。
- Image Processing Toolbox，用于滤波、边界填充、距离变换及图像/ROI 显示。
- 完整 demo 需要 MATLAB 图形界面，以便运行时框选 ROI。

```text
floating_point/
├── README.md
├── demo.m
└── Functions/
    ├── createDoGKernel.m
    ├── splitLayerDualBandPass.m
    ├── highlightMask.m
    ├── softHighlightMaskDual.m
    ├── gaussian5x5Fix.m
    ├── evaluateTextureHighlight.m
    ├── evaluateNoisePCA.m
    ├── generateROIPatches.m
    ├── estimateNoisePCA.m
    └── showImageComparison.m
```

## 配置图像并运行

1. 准备一张 RGB 三通道 `uint8` 图像。图像不随仓库提供。
2. 在 MATLAB 中将当前文件夹切换到本目录 `floating_point/`。脚本通过 `addpath('./Functions')` 加载依赖，因此运行目录必须正确。
3. 打开 `demo.m`，配置图像路径。源码保留原有 `imgPath`、`imgName_1` 至 `imgName_4`、`imgName` 配置；实际读取的是 `imgPath(1)` 下的 `imgName{1}(3)`。可修改对应配置，或将“读取图像”部分的这一行：

   ```matlab
   img = imread(fullfile(imgPath(1), imgName{1}(3)));
   ```

   替换为自己的图像文件路径，例如：

   ```matlab
   img = imread('D:/Images/example.bmp');
   ```

   相对路径以 `floating_point/` 为基准。请确保读取结果是 RGB `uint8`，灰度或高位深图像不能直接传给本处理链。
4. 在命令窗口运行：

   ```matlab
   demo
   ```

5. 在原图窗口中框选相对平坦的 ROI，双击确认。同一个 ROI 同时用于 PCA 噪声评价和对比图局部放大。取消或关闭选择窗口会报错终止；不会自动选择默认 ROI。ROI 应位于图像内且足够大，建议先选择约 100×100 像素区域；有效 Patch 数不足时评价函数会报错。

## 处理流程与默认参数

1. `highlightMask` 检测亮斑，`softHighlightMaskDual` 生成细尺度和中尺度软保护掩码。
2. `splitLayerDualBandPass` 通过 `createDoGKernel` 直接从原图独立提取两种尺度的带通细节：Fine 为 5×5 核、sigma 为 0.7/1.2；Mid 为 13×13 核、sigma 为 1.5/3.0。两尺度不串联，带通滤波边界采用复制填充。
3. `demo.m` 中的局部函数按以下公式重建，随后限幅到 [0,255]、四舍五入并转为 `uint8`：

   ```matlab
   imgRaw = double(img) ...
       + alphaFine .* (1 - softMaskFine) .* double(detailFine) ...
       + alphaMid  .* (1 - softMaskMid)  .* double(detailMid);
   ```

   默认 `alphaFine = 4.5`、`alphaMid = 10`；二维掩码在 RGB 通道上隐式扩展。
4. `evaluateTextureHighlight` 评价增强结果，demo 打印 `TEGGlobal`、`HAER`、`HCE`。
5. `evaluateNoisePCA` 对原图和增强图使用相同 ROI、相同重叠 Patch，默认 `patchSize = 5`、`stride = 3`、`tailNum = 5`，打印 PCA Noise、Noise Gain 和 `noiseGainDB`。缺少有效基准分母等情形可能按函数约定返回 `NaN`。
6. `showImageComparison` 显示原图、增强图及同一 ROI 的直接裁剪放大。

完整 demo 的结果通过命令窗口和图形窗口展示，不自动保存结果图。后续定点实现计划放在仓库根目录下的同级 `fixed_point/`，当前目录作为浮点实现保留。
