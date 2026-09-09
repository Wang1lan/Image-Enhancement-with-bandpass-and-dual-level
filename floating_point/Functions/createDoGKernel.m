function kernel = createDoGKernel(ksize, sigma1, sigma2)
%CREATEDOGKERNEL 构造归一化 Gaussian 差分的零和带通核。
%   kernel = createDoGKernel(ksize, sigma1, sigma2)
%   ksize 为不小于 3 的奇数；0 < sigma1 < sigma2。
%   输出为 ksize x ksize 有符号 double，不额外缩放带通增益。

    narginchk(3, 3);
    if ~(isnumeric(ksize) && isreal(ksize) && isscalar(ksize) && ...
            isfinite(ksize) && ksize >= 3 && ...
            ksize == round(ksize) && mod(ksize, 2) == 1)
        error('createDoGKernel:InvalidKernelSize', ...
            'ksize 必须为不小于 3 的奇数。');
    end
    if ~isPositiveFiniteScalar(sigma1) || ...
            ~isPositiveFiniteScalar(sigma2) || sigma1 >= sigma2
        error('createDoGKernel:InvalidSigma', ...
            'sigma 必须是有限正数，并满足 sigma1 < sigma2。');
    end

    radius = (double(ksize) - 1) / 2;
    [x, y] = meshgrid(-radius:radius);
    distance = hypot(x, y);
    gaussian1 = exp(-0.5 * (distance / double(sigma1)).^2);
    gaussian2 = exp(-0.5 * (distance / double(sigma2)).^2);
    gaussian1 = gaussian1 / sum(gaussian1(:));
    gaussian2 = gaussian2 / sum(gaussian2(:));

    kernel = gaussian1 - gaussian2;
    kernel = kernel - mean(kernel(:));
end


function tf = isPositiveFiniteScalar(value)
    tf = isnumeric(value) && isreal(value) && isscalar(value) && ...
        isfinite(value) && value > 0;
end
