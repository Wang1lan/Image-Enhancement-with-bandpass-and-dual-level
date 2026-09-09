function noiseResult = evaluateNoisePCA(imgOrig, imgEnhList, roiPos, params)
%EVALUATENOISEPCA Evaluate luminance noise for images using one manual ROI.
%
%   noiseResult = evaluateNoisePCA(imgOrig, imgEnhList, roiPos)
%   noiseResult = evaluateNoisePCA(imgOrig, imgEnhList, roiPos, params)
%
% 输入：
%   imgOrig    : 原始 RGB uint8 图像
%   imgEnhList : 待评价增强图像的非空元胞数组
%   roiPos     : 原图上的 [x, y, width, height] 正整数 ROI
%   params     : 可选标量结构体，字段为 patchSize、stride、tailNum
%
% 输出：
%   sigmaOrig、sigmaEnh、noiseGain、noiseGainDB、roiPos、patchPos、
%   validPatchNum。所有图像严格复用同一组 patchPos。

    narginchk(3, 4);
    if nargin < 4
        params = struct();
    end

    validateImage(imgOrig, 'imgOrig');
    imgEnhList = validateEnhancedImages(imgEnhList, size(imgOrig));
    params = resolveParams(params);
    roiPos = validateROI(roiPos, size(imgOrig), params.patchSize);

    patchPos = generateROIPatches(roiPos, params.patchSize, ...
        params.stride);
    validPatchNum = size(patchPos, 1);
    minPatchNum = params.patchSize^2 + 1;
    if validPatchNum < minPatchNum
        error('evaluateNoisePCA:InsufficientPatches', ...
            ['ROI 仅生成 %d 个 Patch，少于 PCA 估计要求的 %d 个；' ...
             '请重新选择更大的 ROI。'], validPatchNum, minPatchNum);
    end

    yOrig = rgbToLuma(imgOrig);
    sigmaOrig = estimateNoisePCA(yOrig, patchPos, ...
        params.patchSize, params.tailNum);

    imageCount = numel(imgEnhList);
    sigmaEnh = zeros(1, imageCount);
    for i = 1:imageCount
        yEnh = rgbToLuma(imgEnhList{i});
        sigmaEnh(i) = estimateNoisePCA(yEnh, patchPos, ...
            params.patchSize, params.tailNum);
    end
    [noiseGain, noiseGainDB] = calculateGain(sigmaOrig, sigmaEnh);

    noiseResult.sigmaOrig = sigmaOrig;
    noiseResult.sigmaEnh = sigmaEnh;
    noiseResult.noiseGain = noiseGain;
    noiseResult.noiseGainDB = noiseGainDB;
    noiseResult.roiPos = roiPos;
    noiseResult.patchPos = patchPos;
    noiseResult.validPatchNum = validPatchNum;
end


function params = resolveParams(params)
    if ~isstruct(params) || ~isscalar(params)
        error('evaluateNoisePCA:InvalidParameter', ...
            'params 必须为标量结构体。');
    end

    allowedFields = {'patchSize', 'stride', 'tailNum'};
    if ~isempty(setdiff(fieldnames(params), allowedFields))
        error('evaluateNoisePCA:InvalidParameter', ...
            'params 仅支持 patchSize、stride 和 tailNum。');
    end

    params = setDefault(params, 'patchSize', 5);
    params = setDefault(params, 'stride', 3);
    params = setDefault(params, 'tailNum', 5);

    if ~isPositiveOddIntegerAtLeastThree(params.patchSize)
        invalidParameter('patchSize');
    end
    if ~isPositiveInteger(params.stride) || ...
            params.stride >= params.patchSize
        invalidParameter('stride');
    end
    if ~isPositiveInteger(params.tailNum) || ...
            params.tailNum > params.patchSize^2
        invalidParameter('tailNum');
    end
end


function params = setDefault(params, fieldName, defaultValue)
    if ~isfield(params, fieldName)
        params.(fieldName) = defaultValue;
    end
end


function invalidParameter(fieldName)
    error('evaluateNoisePCA:InvalidParameter', ...
        '无效的 PCA 噪声参数：%s', fieldName);
end


function tf = isPositiveInteger(value)
    tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
         isfinite(value) && value >= 1 && value == round(value);
end


function tf = isPositiveOddIntegerAtLeastThree(value)
    tf = isPositiveInteger(value) && value >= 3 && mod(value, 2) == 1;
end


function validateImage(img, argumentName)
    if ~(isa(img, 'uint8') && ndims(img) == 3 && size(img, 3) == 3)
        error('evaluateNoisePCA:InvalidImage', ...
            '%s 必须为 RGB uint8 图像。', argumentName);
    end
end


function imgEnhList = validateEnhancedImages(imgEnhList, originalSize)
    if ~iscell(imgEnhList) || isempty(imgEnhList)
        error('evaluateNoisePCA:InvalidImage', ...
            'imgEnhList 必须是非空增强图像元胞数组。');
    end
    imgEnhList = reshape(imgEnhList, 1, []);

    for i = 1:numel(imgEnhList)
        validateImage(imgEnhList{i}, sprintf('imgEnhList{%d}', i));
        if ~isequal(size(imgEnhList{i}), originalSize)
            error('evaluateNoisePCA:SizeMismatch', ...
                '所有增强图像的尺寸必须与 imgOrig 一致。');
        end
    end
end


function roiPos = validateROI(roiPos, imageSize, patchSize)
    if ~(isnumeric(roiPos) && isreal(roiPos) && numel(roiPos) == 4 && ...
            all(isfinite(roiPos(:))) && ...
            all(roiPos(:) == round(roiPos(:))) && all(roiPos(:) > 0))
        error('evaluateNoisePCA:InvalidROI', ...
            'roiPos 必须是 [x, y, width, height] 正整数向量。');
    end
    roiPos = double(reshape(roiPos, 1, []));

    if roiPos(3) < patchSize || roiPos(4) < patchSize || ...
            roiPos(1) + roiPos(3) - 1 > imageSize(2) || ...
            roiPos(2) + roiPos(4) - 1 > imageSize(1)
        error('evaluateNoisePCA:InvalidROI', ...
            'roiPos 必须位于图像内并能容纳完整 Patch。');
    end
end


function y = rgbToLuma(img)
    imgDouble = double(img);
    y = (77 * imgDouble(:, :, 1) + ...
         150 * imgDouble(:, :, 2) + ...
          29 * imgDouble(:, :, 3)) / 256;
end


function [noiseGain, noiseGainDB] = calculateGain(sigmaOrig, sigmaEnh)
    if isnan(sigmaOrig) || sigmaOrig <= eps('double')
        noiseGain = NaN(size(sigmaEnh));
        noiseGainDB = NaN(size(sigmaEnh));
        return;
    end

    noiseGain = sigmaEnh / sigmaOrig;
    noiseGainDB = 20 * log10(noiseGain);
end
