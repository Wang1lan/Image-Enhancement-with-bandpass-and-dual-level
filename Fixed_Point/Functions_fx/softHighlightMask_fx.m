function [softMask] = softHighlightMask_fx(img)

% 生成单尺度soft亮斑掩模

[height, width, ~] = size(img);


%% 阈值参数设置
Te = uint16(3808);                                  % u12   fix((2^Bit - 1) * 0.93)
Th = uint16(3480);                                  % u12   fix((2^Bit - 1) * 0.85)
Tl = uint16(409);                                   % u12   fix((2^Bit - 1) * 0.1)

%% 利用最大最小值获取 HardMask
% Lmax 用于暗区增强和亮斑亮度判断
% Lmin 用于判断 RGB 三通道是否接近

Lmax = zeros(height, width, "uint16");
Lmin = zeros(height, width, "uint16");
lightMask = zeros(height, width, "logical");
mirroMask = zeros(height, width, "logical");

for i = 1:height
    for j = 1:width

        % RGB 最大值
        maxTemp = max(img(i,j,1), img(i,j,2));       % u12
        Lmax(i,j) = max(maxTemp, img(i,j,3));        % u12

        % RGB 最小值
        minTemp = min(img(i,j,1), img(i,j,2));       % u12
        Lmin(i,j) = min(minTemp, img(i,j,3));        % u12

        % 颜色差
        chromaDiff = Lmax(i,j) - Lmin(i,j);          % u12

        if Lmax(i,j) >= Te
            lightMask(i,j) = 1;
        elseif (Lmax(i,j) >= Th) && (chromaDiff <= Tl)
            mirroMask(i,j) = 1;
        end
    end
end

hardMask = lightMask | mirroMask;                    % logical

% figure(1), 
% subplot(1, 2, 1);
% imshow(uint8(img / 16));
% title('原始图像');
% subplot(1, 2, 2);
% imshow(hardMask);
% title('亮斑掩码');

%% 生成 SoftMask
% 5x5 膨胀 1 次，边界采用复制填充
softMask_temp = dilate5x5Once(hardMask);                   % logical

% 将二值 Mask 转成 uint12 0~4095
softMask_tempU12 = uint16(softMask_temp) .* uint16(4095);  % u12

% 5x5 Gaussian 1 次
softMask_blur = gaussian5x5Fix(softMask_tempU12);          % u12

% 保留亮斑核心为完全保护区域
 % Gaussian 会把边缘处原本的 255 拉低。
% 对膨胀后的亮斑核心，我们仍希望保持 255；
% 只让保护权重在亮斑外部逐渐衰减。
softMask = max(softMask_tempU12, softMask_blur);            % u12


% figure(2), 
% subplot(1, 2, 1);
% imshow(uint8(img / 16));
% title('原始图像');
% subplot(1, 2, 2);
% imshow(double(softMask) / 4095);
% title('软亮斑掩码');

end


%% functions

function outMask = dilate5x5Once(inMask)
% 单次 5x5 膨胀，边界采用复制填充

    [height, width] = size(inMask);

    padMask = false(height + 4, width + 4);

    % 中心
    padMask(3:height+2, 3:width+2) = inMask;

    % 上下边
    padMask(1:2, 3:width+2)        = repmat(inMask(1, :), 2, 1);
    padMask(height+3:height+4, 3:width+2) = repmat(inMask(height, :), 2, 1);

    % 左右边
    padMask(3:height+2, 1:2) = repmat(inMask(:, 1), 1, 2);
    padMask(3:height+2, width+3:width+4) = repmat(inMask(:, width), 1, 2);

    % 四角
    padMask(1:2, 1:2)           = inMask(1, 1);          % 左上角
    padMask(1:2, width+3:width+4) = inMask(1, width);    % 右上角
    padMask(height+3:height+4, 1:2) = inMask(height, 1); % 左下角
    padMask(height+3:height+4, width+3:width+4) = inMask(height, width); % 右下角

    outMask = false(height, width);

    for i = 1:height
        for j = 1:width
            block = padMask(i:i+4, j:j+4);
            outMask(i, j) = any(block(:));
        end
    end

end


function dst = gaussian5x5Fix(img)
% 5x5整数高斯滤波 (uint16版本) 

% 高斯核采用可分离整数形式
%
%            [1 4 6 4 1]
%   h = ---------------------
%                  16
%
% 二维高斯：
%
%   G = h' * h
%
% 水平和垂直方向均采用整数加权，
% 最终统一除以 16*16 = 256。


[h, w, c] = size(img);

% 上下左右各需要2个像素
padImg = padarray(img, [2, 2], 'symmetric');

tmp = zeros(h + 4, w, c, 'uint32');

% 最终输出为 uint16
dst = zeros(h, w, c, 'uint16');

% 水平 1D Gaussian
for ch = 1:c

    for y = 1:(h + 4)

        for x = 1:w

            % 将像素转为 uint32 以避免移位溢出
            p0 = uint32(padImg(y, x    , ch));
            p1 = uint32(padImg(y, x + 1, ch));
            p2 = uint32(padImg(y, x + 2, ch));
            p3 = uint32(padImg(y, x + 3, ch));
            p4 = uint32(padImg(y, x + 4, ch));

            % [1 4 6 4 1]
            %
            % 4*x = x << 2
            % 6*x = (x << 2) + (x << 1)

            sumH = ...
                p0 + ...
                bitshift(p1, 2) + ...
                bitshift(p2, 2) + bitshift(p2, 1) + ...
                bitshift(p3, 2) + ...
                p4;

            % 水平方向暂时不除16，
            % 保留完整整数精度
            tmp(y, x, ch) = sumH;

        end
    end
end

%  垂直 1D Gaussian
% =========================

for ch = 1:c

    for y = 1:h

        for x = 1:w

            % tmp 已经是 uint32
            p0 = tmp(y    , x, ch);
            p1 = tmp(y + 1, x, ch);
            p2 = tmp(y + 2, x, ch);
            p3 = tmp(y + 3, x, ch);
            p4 = tmp(y + 4, x, ch);

            sumV = ...
                p0 + ...
                bitshift(p1, 2) + ...
                bitshift(p2, 2) + bitshift(p2, 1) + ...
                bitshift(p3, 2) + ...
                p4;

            % 水平归一化系数 = 16
            % 垂直归一化系数 = 16
            %
            % 总归一化系数：
            % 16 * 16 = 256 = 2^8
            %
            % +128 后 >> 8：
            % 实现除256时的四舍五入

            dstPixel = bitshift(sumV + uint32(128), -8);

            dst(y, x, ch) = uint16(dstPixel);

        end
    end
end


end
