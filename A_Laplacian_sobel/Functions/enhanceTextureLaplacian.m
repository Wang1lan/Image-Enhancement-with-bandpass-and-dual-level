function [outImg, debug] = enhanceTextureLaplacian(img, alpha)
%ENHANCETEXTURELAPLACIAN Laplacian + Sobel 权重 + 单 Highlight SoftMask。
%   img：非空 RGB uint8 图像。
%   alpha：有限非负实数标量，缺省为 3；0 表示不增加细节。
%   outImg：与输入同尺寸的 RGB uint8 图像。
%   debug：设计文档规定的十二个二维中间结果。

    narginchk(1, 2);
    if ~(isa(img, 'uint8') && ~isempty(img) && ...
            ndims(img) == 3 && size(img, 3) == 3)
        error('enhanceTextureLaplacian:InvalidImage', ...
            'img 必须是非空 RGB uint8 图像。');
    end
    if nargin < 2
        alpha = 3;
    end
    if ~(isnumeric(alpha) && isreal(alpha) && isscalar(alpha) && ...
            isfinite(alpha) && alpha >= 0)
        error('enhanceTextureLaplacian:InvalidParameter', ...
            'alpha 必须是有限非负实数标量。');
    end
    alpha = double(alpha);

    imgD = double(img);
    R = imgD(:, :, 1);
    G = imgD(:, :, 2);
    B = imgD(:, :, 3);
    Y = 0.299 * R + 0.587 * G + 0.114 * B;

    detail = getLaplacianDetail(Y);
    [sobelWeight, gx, gy, gradient, gradientSmooth] = getSobelWeight(Y);
    [highlightSoftMask, highlightHardMask] = softHighlightMaskSingle(img);
    highlightWeight = 1 - highlightSoftMask;

    weightedDetail = detail .* sobelWeight .* highlightWeight;
    Yout = Y + alpha * weightedDetail;
    Yout = min(max(Yout, 0), 255);

    deltaY = Yout - Y;
    Rout = min(max(R + deltaY, 0), 255);
    Gout = min(max(G + deltaY, 0), 255);
    Bout = min(max(B + deltaY, 0), 255);
    outImg = uint8(round(cat(3, Rout, Gout, Bout)));

    debug.Y = Y;
    debug.detail = detail;
    debug.gx = gx;
    debug.gy = gy;
    debug.gradient = gradient;
    debug.gradientSmooth = gradientSmooth;
    debug.sobelWeight = sobelWeight;
    debug.highlightHardMask = highlightHardMask;
    debug.highlightSoftMask = highlightSoftMask;
    debug.highlightWeight = highlightWeight;
    debug.weightedDetail = weightedDetail;
    debug.Yout = Yout;
end
