function dst = gaussian5x5Fix(img)
% gaussian5x5Fix 5x5整数高斯滤波
%
% img : 输入图像，uint8
%       支持单通道灰度图或RGB三通道图
%
% dst : 高斯滤波输出，uint8，与输入尺寸一致
%
% 高斯核采用可分离整数形式：
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
%
% 设计特点：
%   1. 不使用浮点乘法；
%   2. 系数4、6使用移位加法实现；
%   3. 中间过程不提前截断；
%   4. 最后采用 +128 后右移8位实现四舍五入；
%   5. 便于后续映射到 FPGA / HLS。

%% ========================
%  输入检查
% =========================

assert(isa(img, 'uint8'), ...
    '输入图像必须为 uint8');

assert(ndims(img) == 2 || ...
      (ndims(img) == 3 && size(img, 3) == 3), ...
    '输入图像必须为单通道或RGB三通道 uint8 图像');

[h, w, c] = size(img);


%% ========================
%  镜像填充
% =========================

% 5x5 kernel：
% 上下左右各需要2个像素
padImg = padarray(img, [2, 2], 'symmetric');


%% ========================
%  中间变量
% =========================

% 水平滤波最大值：
%
% 255 * (1 + 4 + 6 + 4 + 1)
% = 255 * 16
% = 4080
%
% uint16 足够

tmp = zeros(h + 4, w, c, 'uint16');

% 最终输出仍然为uint8
dst = zeros(h, w, c, 'uint8');


%% ========================
%  水平 1D Gaussian
% =========================

for ch = 1:c

    for y = 1:(h + 4)

        for x = 1:w

            p0 = uint16(padImg(y, x    , ch));
            p1 = uint16(padImg(y, x + 1, ch));
            p2 = uint16(padImg(y, x + 2, ch));
            p3 = uint16(padImg(y, x + 3, ch));
            p4 = uint16(padImg(y, x + 4, ch));

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


%% ========================
%  垂直 1D Gaussian
% =========================

for ch = 1:c

    for y = 1:h

        for x = 1:w

            % 转uint32，避免后续累加位宽受限
            p0 = uint32(tmp(y    , x, ch));
            p1 = uint32(tmp(y + 1, x, ch));
            p2 = uint32(tmp(y + 2, x, ch));
            p3 = uint32(tmp(y + 3, x, ch));
            p4 = uint32(tmp(y + 4, x, ch));

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

            dst(y, x, ch) = uint8(dstPixel);

        end
    end
end

end
