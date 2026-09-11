function detail = getLaplacianDetail(Y)
%GETLAPLACIANDETAIL 用中心为正的 3x3 Laplacian 核提取亮度细节。
%   Y：非空二维 double 亮度，detail：同尺寸的有符号 double。
%   边界采用 replicate；重建时将该细节加回原始亮度。

    narginchk(1, 1);
    if ~(isa(Y, 'double') && isreal(Y) && ismatrix(Y) && ...
            ~isempty(Y) && all(isfinite(Y(:))))
        error('getLaplacianDetail:InvalidImage', ...
            'Y 必须是非空有限实数二维 double 亮度图。');
    end

    kernelL = [0 -1 0; -1 4 -1; 0 -1 0];
    detail = imfilter(Y, kernelL, 'replicate', 'same');
end
