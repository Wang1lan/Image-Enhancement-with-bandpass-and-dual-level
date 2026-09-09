function [fineLayer, midLayer] = splitLayerDual_fx(img)

% 利用带通滤波提取双尺度细节层

[h, w, ch] = size(img);

fineLayer = zeros(h, w, ch);
midLayer = zeros(h, w, ch);

% 加载带通核
% fineKernel = createDoGKernel_fx(5, 0.7, 1.2);
% midKernel = createDoGKernel_fx(13, 1.5, 3);
fineKernel = load("kernel_5_0.7_1.2.mat", "kernel_fx");    % s14
midKernel = load("kernel_13_1.5_3.mat", "kernel_fx");      % s14


% padding
fineImgPad = mirrorPad(img, 2);
midImgPad = mirrorPad(img, 6);


% 提取细节层
for c = 1:ch
    for i = 1:h
        for j = 1:w

            % fineLayer
            fineBlock = fineImgPad(i:i+4, j:j+4, c);
            fineLayer(i, j, c) = sum(sum(int16(fineBlock) .* int16(fineKernel)));    % s17 

            % midLayer
            midBlock = midImgPad(i:i+12, j:j+12, c);
            midLayer(i, j, c) = sum(sum(int16(midBlock) .* int16(midKernel)));    % s17 
            
        end
    end
end

end
