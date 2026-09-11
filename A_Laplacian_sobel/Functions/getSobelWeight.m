function [sobelWeight, gx, gy, gradient, gradientSmooth] = getSobelWeight(Y)
%GETSOBELWEIGHT Sobel L1 梯度经 5x5 均值平滑及固定尺度归一化。
%   Y：非空二维 double 亮度；所有输出均为同尺寸二维 double。
%   sobelWeight = clip(gradientSmooth / (8 * 255), 0, 1)。
%   不使用梯度阈值或 SoftMask 映射；各滤波边界采用 replicate。

    narginchk(1, 1);
    if ~(isa(Y, 'double') && isreal(Y) && ismatrix(Y) && ...
            ~isempty(Y) && all(isfinite(Y(:))))
        error('getSobelWeight:InvalidImage', ...
            'Y 必须是非空有限实数二维 double 亮度图。');
    end

    sobelX = [-1 0 1; -2 0 2; -1 0 1];
    sobelY = [-1 -2 -1; 0 0 0; 1 2 1];
    gx = imfilter(Y, sobelX, 'replicate', 'same');
    gy = imfilter(Y, sobelY, 'replicate', 'same');
    gradient = abs(gx) + abs(gy);

    meanKernel = ones(5, 5) / 25;
    gradientSmooth = imfilter(gradient, meanKernel, 'replicate', 'same');
    sobelWeight = gradientSmooth / (8 * 255);
    sobelWeight = min(max(sobelWeight, 0), 1);
end
