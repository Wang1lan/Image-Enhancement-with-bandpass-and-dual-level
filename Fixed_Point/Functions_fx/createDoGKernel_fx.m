function createDoGKernel_fx(ksize, sigma1, sigma2)
%CREATEDOGKERNEL 构造归一化 Gaussian 差分的零和带通核。
%   kernel = createDoGKernel_fx(ksize, sigma1, sigma2)
%   ksize 为不小于 3 的奇数；0 < sigma1 < sigma2。
%   输出为 ksize x ksize 有符号 int16，带放大增益2^12。


    radius = (double(ksize) - 1) / 2;
    [x, y] = meshgrid(-radius:radius);
    distance = hypot(x, y);
    gaussian1 = exp(-0.5 * (distance / double(sigma1)).^2);
    gaussian2 = exp(-0.5 * (distance / double(sigma2)).^2);
    gaussian1 = gaussian1 / sum(gaussian1(:));
    gaussian2 = gaussian2 / sum(gaussian2(:));

    kernel = gaussian1 - gaussian2;
    kernel = kernel - mean(kernel(:));

    kernel_fx = int16(kernel * 4096);   % s14

    % 确保核的和为0
    kernel_fx(radius+1, radius+1) = kernel_fx(radius+1, radius+1) - sum(kernel_fx(:));

    save(['kernel_' num2str(ksize) '_' num2str(sigma1) '_' num2str(sigma2) '.mat'], 'kernel_fx');
end
