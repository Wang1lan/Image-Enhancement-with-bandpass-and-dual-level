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
