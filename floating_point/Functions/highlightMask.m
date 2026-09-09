function mask = highlightMask(img)

% 利用阈值分割，形成亮斑掩码

% img  : RGB三通道 uint8 图像
% mask : logical二值亮斑掩模
%        1 - 亮斑
%        0 - 非亮斑

assert(isa(img, 'uint8'), '输入图像必须为 uint8 类型');
assert(size(img, 3) == 3, '输入图像必须为 RGB 三通道图像');

[height, width, ~] = size(img);

%% 参数设置
Te = uint8(round(255*0.93));
Th = uint8(round(255*0.85));
Tl = uint8(round(255*0.1));

%% 获取最大最小值
% Lmax 用于暗区增强和亮斑亮度判断
% Lmin 用于判断 RGB 三通道是否接近

Lmax = zeros(height, width);
Lmin = zeros(height, width);
lightMask = zeros(height, width);
mirroMask = zeros(height, width);

for i = 1:height
    for j = 1:width

        % RGB 最大值
        maxTemp = max(img(i,j,1), img(i,j,2));
        Lmax(i,j) = max(maxTemp, img(i,j,3));

        % RGB 最小值
        minTemp = min(img(i,j,1), img(i,j,2));
        Lmin(i,j) = min(minTemp, img(i,j,3));

        chromaDiff = Lmax(i,j) - Lmin(i,j);

        if Lmax(i,j) >= Te
            lightMask(i,j) = 1;
        elseif (Lmax(i,j) >= Th) && (chromaDiff <= Tl)
            mirroMask(i,j) = 1;
        end
    end
end

% Sum_m = sum(mirroMask(:));
% Sum_l = sum(lightMask(:));
% disp([Sum_m, Sum_l]);


mask = lightMask | mirroMask;

% figure(1), 
% subplot(1, 2, 1);
% imshow(img);
% title('原始图像');
% subplot(1, 2, 2);
% imshow(mask);
% title('亮斑掩码');

end