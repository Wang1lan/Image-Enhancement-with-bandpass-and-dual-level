function [metrics, debug] = evaluateTextureHighlight(imgRef, imgEnh, imgRaw)
%EVALUATETEXTUREHIGHLIGHT 评价纹理增强与高光保护效果
%
%   [metrics, debug] = evaluateTextureHighlight(imgRef, imgEnh)
%   [metrics, debug] = evaluateTextureHighlight(imgRef, imgEnh, imgRaw)
%
% 输入：
%   imgRef : 原始 RGB uint8 图像
%   imgEnh : 增强后 RGB uint8 图像，尺寸与 imgRef 相同
%   imgRaw : 可选，clip 前的 RGB 数值图像。仅用于计算 clipRatio
%
% 输出 metrics：
%   TEGGlobal            : 距高光大于 7 pixel 区域的纹理增强增益
%   TEGNear              : 距高光 0~7 pixel 有效纹理区域的增强增益
%   HERLocal             : 高光邻域内增强后高光面积与原高光面积之比
%   HAER                 : 高光邻域内新增高光面积与原高光面积之比
%   RemoteHighlightRatio : 远离原高光的增强后高光像素比例
%   HCE                  : 高光核心亮度绝对误差
%   HREFine              : 距高光 0~2 pixel 的亮度绝对误差
%   HREMid               : 距高光 2~7 pixel 的亮度绝对误差
%   HREFinePositive      : Fine Ring 中的正向亮度误差
%   HREMidPositive       : Mid Ring 中的正向亮度误差
%   NARMAD               : 平滑组织区域的鲁棒高频残差比
%   deltaMeanY           : 全图平均亮度变化
%   clipRatio            : imgRaw 中超出 [0,255] 的 RGB 样本比例
%
% 输出 debug：
%   highlightMask  : 由原图得到的高光核心
%   distanceMap    : 到原图高光核心的欧氏距离
%   ringFine       : 高光近 Ring，0 < distance <= 2
%   ringMid        : 高光中 Ring，2 < distance <= 7
%   textureROI     : distance > 7 的正常组织纹理区域
%   textureNearROI : Near ROI 中原图梯度 30%~95% 分位范围
%   smoothROI      : textureROI 内原图 Sobel 梯度最低 10% 的区域
%
% 说明：
%   1. 所有评价 ROI 均由 imgRef 生成，避免增强结果改变评价区域。
%   2. RGB 转亮度采用 Y=(77R+150G+29B)/256。
%   3. 若某项缺少有效原图 ROI 或有效基准分母，该项返回 NaN。

    narginchk(2, 3);

    validateImage(imgRef, 'imgRef');
    validateImage(imgEnh, 'imgEnh');
    assert(isequal(size(imgRef), size(imgEnh)), ...
        'imgRef 与 imgEnh 的尺寸必须一致');

    if nargin == 3
        assert(isnumeric(imgRaw) && isreal(imgRaw), ...
            'imgRaw 必须为实数数值图像');
        assert(isequal(size(imgRef), size(imgRaw)), ...
            'imgRaw 与 imgRef 的尺寸必须一致');
        assert(all(isfinite(imgRaw(:))), ...
            'imgRaw 不能包含 NaN 或 Inf');
    end

    yRef = rgbToLuma(imgRef);
    yEnh = rgbToLuma(imgEnh);

    hardRef = logical(highlightMask(imgRef));
    hardEnh = logical(highlightMask(imgEnh));
    distanceMap = bwdist(hardRef);

    ringFine = distanceMap > 0 & distanceMap <= 2;
    ringMid = distanceMap > 2 & distanceMap <= 7;
    nearROI = distanceMap > 0 & distanceMap <= 7;
    highlightNeighborhood = distanceMap <= 7;

    [gradRef, gradEnh] = sobelMagnitudePair(yRef, yEnh);

    validROI = true(size(hardRef));
    validROI([1:2, end-1:end], :) = false;
    validROI(:, [1:2, end-1:end]) = false;

    textureROI = validROI & distanceMap > 7;
    textureNearCandidates = validROI & nearROI;
    textureNearROI = selectGradientRange( ...
        gradRef, textureNearCandidates, 0.30, 0.95);

    textureGradient = gradRef(textureROI);
    if isempty(textureGradient)
        smoothROI = false(size(textureROI));
    else
        lowGradientThreshold = percentileLinear(textureGradient, 0.10);
        smoothROI = textureROI & (gradRef <= lowGradientThreshold);
    end

    referenceHighlightCount = nnz(hardRef);
    localEnhancedHighlight = hardEnh & highlightNeighborhood;
    newLocalHighlight = hardEnh & ~hardRef & highlightNeighborhood;
    remoteEnhancedHighlight = hardEnh & distanceMap > 7;

    metrics.TEGGlobal = meanRatio(gradEnh, gradRef, textureROI);
    metrics.TEGNear = meanRatio(gradEnh, gradRef, textureNearROI);
    metrics.HERLocal = ratioToReferenceCount( ...
        localEnhancedHighlight, referenceHighlightCount);
    metrics.HAER = ratioToReferenceCount( ...
        newLocalHighlight, referenceHighlightCount);
    metrics.RemoteHighlightRatio = ...
        nnz(remoteEnhancedHighlight) / numel(hardRef);
    metrics.HCE = maskedMeanAbsDifference(yEnh, yRef, hardRef);
    metrics.HREFine = maskedMeanAbsDifference(yEnh, yRef, ringFine);
    metrics.HREMid = maskedMeanAbsDifference(yEnh, yRef, ringMid);
    metrics.HREFinePositive = ...
        maskedMeanPositiveDifference(yEnh, yRef, ringFine);
    metrics.HREMidPositive = ...
        maskedMeanPositiveDifference(yEnh, yRef, ringMid);

    gaussianKernel = ([1, 4, 6, 4, 1]' * [1, 4, 6, 4, 1]) / 256;
    highFreqRef = yRef - symmetricFilter(yRef, gaussianKernel);
    highFreqEnh = yEnh - symmetricFilter(yEnh, gaussianKernel);
    metrics.NARMAD = robustNoiseRatio(highFreqEnh, highFreqRef, smoothROI);

    metrics.deltaMeanY = mean(yEnh(:)) - mean(yRef(:));

    if nargin == 3
        metrics.clipRatio = nnz(imgRaw < 0 | imgRaw > 255) / numel(imgRaw);
    else
        metrics.clipRatio = NaN;
    end

    debug.highlightMask = hardRef;
    debug.distanceMap = distanceMap;
    debug.ringFine = ringFine;
    debug.ringMid = ringMid;
    debug.textureROI = textureROI;
    debug.textureNearROI = textureNearROI;
    debug.smoothROI = smoothROI;
end


function validateImage(img, argumentName)
    assert(isa(img, 'uint8'), '%s 必须为 uint8 类型', argumentName);
    assert(ndims(img) == 3 && size(img, 3) == 3, ...
        '%s 必须为 RGB 三通道图像', argumentName);
    assert(size(img, 1) >= 5 && size(img, 2) >= 5, ...
        '%s 的高度和宽度必须至少为 5 pixel', argumentName);
end


function y = rgbToLuma(img)
    imgDouble = double(img);
    y = (77 * imgDouble(:, :, 1) + ...
         150 * imgDouble(:, :, 2) + ...
          29 * imgDouble(:, :, 3)) / 256;
end


function [gradA, gradB] = sobelMagnitudePair(imageA, imageB)
    sobelX = [-1, 0, 1; -2, 0, 2; -1, 0, 1];
    sobelY = sobelX';

    gradAx = symmetricFilter(imageA, sobelX);
    gradAy = symmetricFilter(imageA, sobelY);
    gradBx = symmetricFilter(imageB, sobelX);
    gradBy = symmetricFilter(imageB, sobelY);

    gradA = hypot(gradAx, gradAy);
    gradB = hypot(gradBx, gradBy);
end


function filtered = symmetricFilter(image, kernel)
    padRows = floor(size(kernel, 1) / 2);
    padCols = floor(size(kernel, 2) / 2);
    padded = padarray(image, [padRows, padCols], 'symmetric', 'both');
    filtered = conv2(padded, kernel, 'valid');
end


function mask = selectGradientRange(gradient, candidates, lowFraction, highFraction)
    samples = gradient(candidates);
    if isempty(samples)
        mask = false(size(candidates));
        return;
    end

    lowThreshold = percentileLinear(samples, lowFraction);
    highThreshold = percentileLinear(samples, highFraction);
    mask = candidates & gradient >= lowThreshold & gradient <= highThreshold;
end


function ratio = meanRatio(numeratorImage, denominatorImage, mask)
    if ~any(mask(:))
        ratio = NaN;
        return;
    end

    denominator = mean(denominatorImage(mask));
    if denominator <= eps('double')
        ratio = NaN;
    else
        ratio = mean(numeratorImage(mask)) / denominator;
    end
end


function ratio = ratioToReferenceCount(numeratorMask, referenceCount)
    if referenceCount == 0
        ratio = NaN;
    else
        ratio = nnz(numeratorMask) / referenceCount;
    end
end


function value = maskedMeanAbsDifference(imageA, imageB, mask)
    if ~any(mask(:))
        value = NaN;
    else
        difference = abs(imageA - imageB);
        value = mean(difference(mask));
    end
end


function value = maskedMeanPositiveDifference(imageEnh, imageRef, mask)
    if ~any(mask(:))
        value = NaN;
    else
        difference = max(imageEnh - imageRef, 0);
        value = mean(difference(mask));
    end
end


function ratio = robustNoiseRatio(highFreqEnh, highFreqRef, mask)
    refSamples = highFreqRef(mask);
    enhSamples = highFreqEnh(mask);

    if numel(refSamples) < 10
        ratio = NaN;
        return;
    end

    medianRef = median(refSamples);
    medianEnh = median(enhSamples);
    sigmaRef = 1.4826 * median(abs(refSamples - medianRef));
    sigmaEnh = 1.4826 * median(abs(enhSamples - medianEnh));

    if sigmaRef < 1e-6
        ratio = NaN;
    else
        ratio = sigmaEnh / sigmaRef;
    end
end


function value = percentileLinear(samples, fraction)
    samples = sort(samples(:));
    position = 1 + (numel(samples) - 1) * fraction;
    lowerIndex = floor(position);
    upperIndex = ceil(position);

    if lowerIndex == upperIndex
        value = samples(lowerIndex);
    else
        weight = position - lowerIndex;
        value = samples(lowerIndex) * (1 - weight) + ...
                samples(upperIndex) * weight;
    end
end
