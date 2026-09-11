function [softMaskMid, softMaskFine, hardMask] = softHighlightMaskDual(img)
%SOFTHIGHLIGHTMASKDUAL 基于现有亮斑检测的双 Soft Highlight Mask
%
% 输入：
%   img          : RGB 三通道 uint8 图像
%
% 输出：
%   softMaskMid  : 面向中尺度 detail_mid 的 Soft Mask，double，[0,1]
%   softMaskFine : 面向细尺度 detail_fine 的 Soft Mask，double，[0,1]
%   hardMask     : 现有 highlightMask() 得到的二值亮斑掩模，logical
%
% 设计目的：
%   当前双尺度增强中：
%       detail_fine -> 空间范围较小，对亮斑边缘/噪声更敏感
%       detail_mid  -> 空间范围更大，高光影响范围也更宽
%
%   因此不再共用一个 Soft Mask，而是设计：
%       1) Fine Mask : 保护范围较小，重点抑制亮斑本体及其近邻边缘
%       2) Mid Mask  : 保护范围较大，覆盖更宽的高光影响区域
%
% -------------------------------------------------------------------------
% 依赖函数：
%   1) highlightMask.m
%   2) gaussian5x5Fix.m
%
% 推荐接入方式：
%
%   [softMaskMid, softMaskFine, hardMask] = softHighlightMaskDual(img);
%
%   softMaskMid3  = repmat(softMaskMid,  [1 1 3]);
%   softMaskFine3 = repmat(softMaskFine, [1 1 3]);
%
%   gainMid  = 1 + (alphaMid  - 1) .* (1 - softMaskMid3);
%   gainFine = 1 + (alphaFine - 1) .* (1 - softMaskFine3);
%
%   detailMidEnh  = gainMid  .* double(detail_mid);
%   detailFineEnh = gainFine .* double(detail_fine);
%
%   imgEnh = double(base) + detailMidEnh + detailFineEnh;
%
% 若想对 Mid 保留部分增强，可改为：
%
%   betaMid  = 0.7;
%   betaFine = 1.0;
%
%   gainMid  = 1 + (alphaMid  - 1) .* (1 - betaMid  .* softMaskMid3);
%   gainFine = 1 + (alphaFine - 1) .* (1 - betaFine .* softMaskFine3);
%
% -------------------------------------------------------------------------
% 第一版双 Mask 生成策略
%
%   hardMask
%      │
%      ├── Fine 分支：
%      │      3x3 膨胀 1 次
%      │         ↓
%      │      5x5 Gaussian 1 次
%      │         ↓
%      │      softMaskFine
%      │
%      └── Mid 分支：
%             3x3 膨胀 2 次
%                ↓
%             5x5 Gaussian 2 次
%                ↓
%             softMaskMid
%
% 说明：
%   - Fine Mask 保护近邻高光边缘
%   - Mid Mask 保护更大范围，避免中尺度增强在高光外围形成 halo/假结构
% -------------------------------------------------------------------------

    %% 输入检查
    assert(isa(img, 'uint8'), '输入图像必须为 uint8 类型');
    assert(ndims(img) == 3 && size(img, 3) == 3, ...
        '输入图像必须为 RGB 三通道图像');

    %% Step 1: 基于现有规则生成 Hard Highlight Mask
    hardMask = logical(highlightMask(img));

    %% Step 2: 生成 Fine Soft Mask
    % 保护范围较小：1 次 3x3 膨胀 + 1 次 5x5 Gaussian
    fineCore = dilate3x3(hardMask, 1);
    softMaskFine = buildSoftMaskFromCore(fineCore, 1);

    %% Step 3: 生成 Mid Soft Mask
    % 保护范围较大：2 次 3x3 膨胀 + 2 次 5x5 Gaussian
    midCore = dilate3x3(hardMask, 2);
    softMaskMid = buildSoftMaskFromCore(midCore, 2);

end


%% ========================================================================
function softMask = buildSoftMaskFromCore(coreMask, numGaussian)
% 将膨胀后的核心保护区转成连续 Soft Mask
%
% 输入：
%   coreMask     : logical
%   numGaussian  : Gaussian 平滑次数，正整数
%
% 输出：
%   softMask     : double，[0,1]

    maskU8 = uint8(coreMask) .* uint8(255);

    blurMaskU8 = maskU8;
    for k = 1:numGaussian
        blurMaskU8 = gaussian5x5Fix(blurMaskU8);
    end

    % 保持核心保护区始终为 1，仅在外侧形成渐变过渡
    softMaskU8 = max(maskU8, blurMaskU8);

    softMask = double(softMaskU8) ./ 255.0;

end


%% ========================================================================
function outMask = dilate3x3(inMask, iter)
%DILATE3X3 采用 3x3 邻域的显式膨胀
%
% 输入：
%   inMask : logical 二值图
%   iter   : 膨胀次数，正整数
%
% 输出：
%   outMask : logical 二值图
%
% 说明：
%   这里使用显式循环实现，便于后续定点化 / FPGA 映射。

    assert(islogical(inMask), 'inMask 必须为 logical 类型');
    assert(iter >= 1, 'iter 必须 >= 1');

    outMask = inMask;

    for t = 1:iter
        outMask = dilate3x3Once(outMask);
    end

end


%% ========================================================================
function outMask = dilate3x3Once(inMask)
% 单次 3x3 膨胀，边界采用复制填充

    [height, width] = size(inMask);

    padMask = false(height + 2, width + 2);

    % 中心
    padMask(2:height+1, 2:width+1) = inMask;

    % 上下边
    padMask(1, 2:width+1)        = inMask(1, :);
    padMask(height+2, 2:width+1) = inMask(height, :);

    % 左右边
    padMask(2:height+1, 1)       = inMask(:, 1);
    padMask(2:height+1, width+2) = inMask(:, width);

    % 四角
    padMask(1, 1)                = inMask(1, 1);
    padMask(1, width+2)          = inMask(1, width);
    padMask(height+2, 1)         = inMask(height, 1);
    padMask(height+2, width+2)   = inMask(height, width);

    outMask = false(height, width);

    for i = 1:height
        for j = 1:width
            block = padMask(i:i+2, j:j+2);
            outMask(i, j) = any(block(:));
        end
    end

end
