clc;
clear; 
close all;

% 纹理增强同时抑制亮斑
%{
dual mask（softMaskMid + softMaskFine）
%}

addpath('./Functions');


imgPath = ["./ComenImg/消化道临床", "./ComenImg/BDI", "./ComenImg/分辨率板", "./OlympusImg"];

imgName_1 = ["20260710_161040694_SEI_1_.bmp", ...
            "20251204144145698.bmp", ...
            "20251204144725453.bmp", ...
            "20251204144729985.bmp", ...
            "20251204150152332.bmp", ...
            "20251204150644321.bmp"];

imgName_2 = ["19700101045511934.bmp", "19700101045515646.bmp"];

imgName_3 = ["20250516分辨率1.bmp", "20250516分辨率2.bmp"];

imgName_4 = ["CV-1500_07351590_20260819092655_PE_0001.jpg",...
            "CV-1500_07351590_20260819092658_PE_0002.jpg",...
            "CV-1500_07351590_20260819092702_PE_0003.jpg",...
            "CV-1500_07351590_20260819092704_PE_0004.jpg"];

imgName = {imgName_1, imgName_2, imgName_3, imgName_4};

%% 增益系数
alphaMid = 10;
alphaFine = 4.5;
bandPassParams = struct('sigmaFine1', 0.7, 'sigmaFine2', 1.2, ...
    'sigmaMid1', 1.5, 'sigmaMid2', 3.0);
noiseParams = struct('patchSize', 5, 'stride', 3, 'tailNum', 5);

%% 读取图像
img = imread(fullfile(imgPath(1), imgName{1}(3)));
[height, width, c] = size(img);


%% 生成亮斑掩码
[softMaskMid, softMaskFine, ~] = softHighlightMaskDual(img);


%% 分离基础/细节层
[detailFine, detailMid] = splitLayerDualBandPass(img, bandPassParams);


%% 图像重建
[imgEnhBandPass, imgRawBandPass] = reconstructImage(img, ...
    detailFine, detailMid, softMaskFine, softMaskMid, alphaFine, alphaMid);


%% evaluate texture highlight
metricsBandPass = evaluateTextureHighlight(img, imgEnhBandPass, imgRawBandPass);

fprintf('alphaFine=%.6g, alphaMid=%.6g\n', alphaFine, alphaMid);
fprintf('Fine: 5x5, sigma1=%.6g, sigma2=%.6g\n', ...
    bandPassParams.sigmaFine1, bandPassParams.sigmaFine2);
fprintf('Mid : 13x13, sigma1=%.6g, sigma2=%.6g\n', ...
    bandPassParams.sigmaMid1, bandPassParams.sigmaMid2);
fprintf('%-24s %12s %12s %12s\n', 'Image', 'TEGGlobal', 'HAER', 'HCE');
fprintf('%s\n', repmat('-', 1, 64));
fprintf('%-24s %12.4f %12.4f %12.4f\n', 'BandPass', ...
    metricsBandPass.TEGGlobal, metricsBandPass.HAER, metricsBandPass.HCE);

%% 运行时框选统一 ROI
originalFigure = figure();
originalAxes = axes('Parent', originalFigure);
imshow(img, 'Parent', originalAxes);
title(originalAxes, '原图：请框选相对平坦的 ROI，双击确认');
roiHandle = drawrectangle(originalAxes, 'Color', [1, 0, 0], 'LineWidth', 1.5);
if isempty(roiHandle) || ~isgraphics(originalAxes, 'axes') || ~isvalid(roiHandle)
    error('demo_bandpass:ROISelectionCancelled', ...
        'ROI 框选已取消，无法生成对比及 PCA 评价结果。');
end
try
    wait(roiHandle);
catch selectionError
    if ~isgraphics(originalAxes, 'axes') || ~isvalid(roiHandle)
        error('demo_bandpass:ROISelectionCancelled', ...
            'ROI 框选已取消，无法生成对比及 PCA 评价结果。');
    end
    rethrow(selectionError);
end
if ~isgraphics(originalAxes, 'axes') || ~isvalid(roiHandle)
    error('demo_bandpass:ROISelectionCancelled', ...
        'ROI 框选已取消，无法生成对比及 PCA 评价结果。');
end
roiPosition = roiHandle.Position;
if numel(roiPosition) ~= 4 || any(~isfinite(roiPosition)) || ...
        any(roiPosition(3:4) <= 0)
    error('demo_bandpass:ROISelectionCancelled', ...
        '未完成有效 ROI 框选，无法生成对比及 PCA 评价结果。');
end

% 取框选矩形与图像的实际像素交集，不将图外 ROI 平移到图内。
selectedROI = round(roiPosition);
x1 = max(selectedROI(1), 1);
y1 = max(selectedROI(2), 1);
x2 = min(selectedROI(1) + selectedROI(3) - 1, width);
y2 = min(selectedROI(2) + selectedROI(4) - 1, height);
if x2 < x1 || y2 < y1
    error('demo_bandpass:InvalidROI', '框选 ROI 与图像没有有效像素交集。');
end
roi = [x1, y1, x2 - x1 + 1, y2 - y1 + 1];
delete(roiHandle);
title(originalAxes, '原图');

%% 同一个 ROI 和同一组重叠 Patch 进行 PCA 噪声评价
imgEnhList = {imgEnhBandPass};
noiseResult = evaluateNoisePCA(img, imgEnhList, roi, noiseParams);
fprintf('\nPCA Noise Evaluation - Manual ROI\n');
fprintf('ROI              : [%d, %d, %d, %d]\n', noiseResult.roiPos);
fprintf('Patch Size       : %d x %d\n', noiseParams.patchSize, noiseParams.patchSize);
fprintf('Patch Stride     : %d\n', noiseParams.stride);
fprintf('Tail Eigenvalues : %d\n', noiseParams.tailNum);
fprintf('Patch Number     : %d\n', noiseResult.validPatchNum);
fprintf('%-24s %12s %12s %14s\n', ...
    'Image', 'PCA Noise', 'Noise Gain', 'noiseGainDB');
fprintf('%s\n', repmat('-', 1, 66));
originalNoiseGain = NaN;
originalNoiseGainDB = NaN;
if isfinite(noiseResult.sigmaOrig) && noiseResult.sigmaOrig > eps('double')
    originalNoiseGain = 1;
    originalNoiseGainDB = 0;
end
fprintf('%-24s %12.4f %12.4f %14.4f\n', 'Original', ...
    noiseResult.sigmaOrig, originalNoiseGain, originalNoiseGainDB);
methodNames = {'BandPass'};
for i = 1:numel(imgEnhList)
    fprintf('%-24s %12.4f %12.4f %14.4f\n', methodNames{i}, ...
        noiseResult.sigmaEnh(i), noiseResult.noiseGain(i), noiseResult.noiseGainDB(i));
end

%% 二图及相同 ROI 的直接裁剪放大
imgList = {img, imgEnhBandPass};
titles = ["原图", "BandPass"];
showImageComparison(imgList, titles, roi);
comparisonFigure = gcf;


%% function
function [imgEnh, imgRaw] = reconstructImage(img, detailFine, detailMid, ...
        softMaskFine, softMaskMid, alphaFine, alphaMid)
% 两方案使用相同重组公式；HxW Mask 在 RGB 通道上隐式扩展。
    imgRaw = double(img) ...
        + alphaFine .* (1 - softMaskFine) .* double(detailFine) ...
        + alphaMid .* (1 - softMaskMid) .* double(detailMid);
    imgEnh = uint8(round(min(max(imgRaw, 0), 255)));
end
