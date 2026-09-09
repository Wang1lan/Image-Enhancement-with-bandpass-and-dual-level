function patchPos = generateROIPatches(roiPos, patchSize, stride)
%GENERATEROIPATCHES Generate deterministic overlapping patch centers in an ROI.
%   patchPos = generateROIPatches(roiPos, patchSize, stride) returns
%   N-by-2 [row, column] center coordinates. roiPos is
%   [x, y, width, height] in one-based image coordinates.

    narginchk(3, 3);

    if ~(isnumeric(roiPos) && isreal(roiPos) && numel(roiPos) == 4 && ...
            all(isfinite(roiPos(:))) && ...
            all(roiPos(:) == round(roiPos(:))) && all(roiPos(:) > 0))
        error('generateROIPatches:InvalidROI', ...
            'roiPos 必须是 [x, y, width, height] 正整数向量。');
    end
    roiPos = double(reshape(roiPos, 1, []));

    if ~isPositiveOddIntegerAtLeastThree(patchSize)
        invalidParameter('patchSize');
    end
    if ~isPositiveInteger(stride) || stride >= patchSize
        invalidParameter('stride');
    end

    x = roiPos(1);
    y = roiPos(2);
    roiWidth = roiPos(3);
    roiHeight = roiPos(4);
    if roiWidth < patchSize || roiHeight < patchSize
        error('generateROIPatches:InvalidROI', ...
            'ROI 的宽度和高度必须不小于 patchSize。');
    end

    halfSize = floor(patchSize / 2);
    rowCenters = (y + halfSize):stride: ...
        (y + roiHeight - 1 - halfSize);
    columnCenters = (x + halfSize):stride: ...
        (x + roiWidth - 1 - halfSize);

    [columnGrid, rowGrid] = meshgrid(columnCenters, rowCenters);
    patchPos = [rowGrid(:), columnGrid(:)];
end


function tf = isPositiveInteger(value)
    tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
         isfinite(value) && value >= 1 && value == round(value);
end


function tf = isPositiveOddIntegerAtLeastThree(value)
    tf = isPositiveInteger(value) && value >= 3 && mod(value, 2) == 1;
end


function invalidParameter(fieldName)
    error('generateROIPatches:InvalidParameter', ...
        '无效的 ROI Patch 参数：%s', fieldName);
end
