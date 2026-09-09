function padded = mirrorPad(image, padSize)
% mirrorPad 对单通道或三通道图像进行指定大小的镜像填充
%
% 输入：
%   image   - 输入图像
%             单通道：H × W
%             三通道：H × W × 3
%
%   padSize - 镜像填充宽度，例如：
%             padSize = 2 表示上下左右各填充 2 个像素
%
% 输出：
%   padded  - 镜像填充后的图像
%
% 镜像方式：
%   不重复边界像素
%
% 例如：
%   原始序列：[a b c d e]
%   padSize = 2
%
%   填充结果：[c b | a b c d e | d c]

    height = size(image, 1);
    width  = size(image, 2);
    channels = size(image, 3);

    % 参数检查
    if padSize < 0 || padSize ~= floor(padSize)
        error('padSize 必须为非负整数');
    end

    if padSize >= height || padSize >= width
        error('padSize 必须小于图像的高度和宽度');
    end

    if channels ~= 1 && channels ~= 3
        error('输入图像必须为单通道或三通道图像');
    end

    % padSize = 0 时直接返回
    if padSize == 0
        padded = image;
        return;
    end

    % 构造行镜像索引
    rowIndex = [ ...
        padSize + 1 : -1 : 2, ...
        1 : height, ...
        height - 1 : -1 : height - padSize ...
    ];

    % 构造列镜像索引
    columnIndex = [ ...
        padSize + 1 : -1 : 2, ...
        1 : width, ...
        width - 1 : -1 : width - padSize ...
    ];

    % 镜像填充
    if channels == 1
        padded = image(rowIndex, columnIndex);
    else
        padded = image(rowIndex, columnIndex, :);
    end

end