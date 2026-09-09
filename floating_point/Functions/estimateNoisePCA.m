function sigmaPCA = estimateNoisePCA(y, patchPos, patchSize, tailNum)
%ESTIMATENOISEPCA Estimate noise sigma from the smallest PCA eigenvalues.

    narginchk(4, 4);
    assert(isnumeric(y) && isreal(y) && ismatrix(y) && ...
        all(isfinite(y(:))), 'y 必须为有限实数二维矩阵');
    assert(isnumeric(patchPos) && isreal(patchPos) && ...
        size(patchPos, 2) == 2 && all(isfinite(patchPos(:))) && ...
        all(patchPos(:) == round(patchPos(:))), ...
        'patchPos 必须为 N×2 整数坐标');
    assert(isPositiveOddInteger(patchSize), ...
        'patchSize 必须为正奇数');
    assert(isPositiveInteger(tailNum) && tailNum <= patchSize^2, ...
        'tailNum 必须为不大于 Patch 维度的正整数');

    patchNum = size(patchPos, 1);
    if patchNum < 2
        sigmaPCA = NaN;
        return;
    end

    halfSize = floor(patchSize / 2);
    assert(all(patchPos(:, 1) > halfSize) && ...
        all(patchPos(:, 1) <= size(y, 1) - halfSize) && ...
        all(patchPos(:, 2) > halfSize) && ...
        all(patchPos(:, 2) <= size(y, 2) - halfSize), ...
        'patchPos 中存在越界 Patch 坐标');

    patchMatrix = zeros(patchSize^2, patchNum);
    for i = 1:patchNum
        row = patchPos(i, 1);
        column = patchPos(i, 2);
        patch = y(row-halfSize:row+halfSize, ...
                  column-halfSize:column+halfSize);
        patchMatrix(:, i) = patch(:);
    end

    patchMatrix = patchMatrix - mean(patchMatrix, 2);
    covarianceMatrix = (patchMatrix * patchMatrix') / (patchNum - 1);
    covarianceMatrix = (covarianceMatrix + covarianceMatrix') / 2;

    eigenvalues = sort(real(eig(covarianceMatrix)), 'ascend');
    eigenvalues = max(eigenvalues, 0);
    noiseVariance = median(eigenvalues(1:tailNum));
    sigmaPCA = sqrt(noiseVariance);
end


function tf = isPositiveInteger(value)
    tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
         isfinite(value) && value >= 1 && value == round(value);
end


function tf = isPositiveOddInteger(value)
    tf = isPositiveInteger(value) && mod(value, 2) == 1;
end
