function [softMask, hardMask] = softHighlightMaskSingle(img)
%SOFTHIGHLIGHTMASKSINGLE 沿用原 Fine 分支尺度的单 Highlight SoftMask。
%   img：非空 RGB uint8 图像。
%   softMask：二维 double，[0,1]；1 表示完全保护，0 表示不保护。
%   hardMask：highlightMask 产生的二维 logical 原始亮斑掩模。
%   3x3 膨胀一次，随后调用 gaussian5x5Fix 一次并保留膨胀核心为 1。

    narginchk(1, 1);
    if ~(isa(img, 'uint8') && ~isempty(img) && ...
            ndims(img) == 3 && size(img, 3) == 3)
        error('softHighlightMaskSingle:InvalidImage', ...
            'img 必须是非空 RGB uint8 图像。');
    end

    hardMask = logical(highlightMask(img));
    coreMask = dilate3x3(hardMask, 1);
    maskU8 = uint8(coreMask) .* uint8(255);
    blurMaskU8 = gaussian5x5Fix(maskU8);
    softMaskU8 = max(maskU8, blurMaskU8);
    softMask = double(softMaskU8) ./ 255.0;
end
