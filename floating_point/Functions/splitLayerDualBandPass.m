function [detailFine, detailMid] = splitLayerDualBandPass(img, params)
%SPLITLAYERDUALBANDPASS 直接由原图独立提取两个尺度的 DoG 带通细节。
%   [detailFine, detailMid] = splitLayerDualBandPass(img)
%   [detailFine, detailMid] = splitLayerDualBandPass(img, params)
%
%   img：非空 RGB uint8 图像。
%   params：可选标量结构体，仅支持以下字段（缺省使用默认值）：
%       sigmaFine1 = 0.7, sigmaFine2 = 1.2（固定 5x5 核）
%       sigmaMid1  = 1.5, sigmaMid2  = 3.0（固定 13x13 核）
%   detailFine/detailMid：与输入同尺寸的有符号 double 细节。
%   边界采用 replicate；两尺度不串联，不生成可重建的 base 层。

    narginchk(1, 2);
    if ~(isa(img, 'uint8') && ~isempty(img) && ...
            ndims(img) == 3 && size(img, 3) == 3)
        error('splitLayerDualBandPass:InvalidImage', ...
            'img 必须是非空 RGB uint8 图像。');
    end
    if nargin < 2
        params = struct();
    end
    if ~isstruct(params) || ~isscalar(params)
        error('splitLayerDualBandPass:InvalidParameter', ...
            'params 必须是标量结构体。');
    end

    defaults = struct('sigmaFine1', 0.7, 'sigmaFine2', 1.2, ...
        'sigmaMid1', 1.1, 'sigmaMid2', 1.8);
    names = fieldnames(defaults);
    if ~isempty(setdiff(fieldnames(params), names))
        error('splitLayerDualBandPass:InvalidParameter', ...
            'params 仅支持 sigmaFine1、sigmaFine2、sigmaMid1、sigmaMid2。');
    end
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(params, name)
            params.(name) = defaults.(name);
        end
    end

    kernelFine = createDoGKernel(5, params.sigmaFine1, params.sigmaFine2);
    kernelMid = createDoGKernel(9, params.sigmaMid1, params.sigmaMid2);
    imgInput = double(img);
    detailFine = imfilter(imgInput, kernelFine, 'replicate', 'conv');
    detailMid = imfilter(imgInput, kernelMid, 'replicate', 'conv');
end
