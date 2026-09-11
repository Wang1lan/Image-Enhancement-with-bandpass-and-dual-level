function [outputDir, experiment] = runLaplacianTextureExperiment( ...
        inputPath, alpha, roi, outputRoot)
%RUNLAPLACIANTEXTUREEXPERIMENT 同图计算、显示并保存两条增强链。
%   demo 负责运行时框选；本函数接收明确的整数像素 ROI [x y w h]。
%   自动保存检查可提供固定 ROI，不将它当作手动交互验收。
%   BandPass 使用独立副本：5x5 / 0.7,1.2 和 9x9 / 1.1,1.8，增量7.5/15。
%   PNG 为显示映射；experiment.mat 保留原始有符号 double 数据。

    narginchk(4, 4);
    moduleRoot = fileparts(fileparts(mfilename('fullpath')));
    originalPath = path;
    pathCleanup = onCleanup(@() path(originalPath));
    addpath(fullfile(moduleRoot, 'ReferenceBandPass'), '-begin');
    addpath(fullfile(moduleRoot, 'Functions'), '-begin');

    img = imread(inputPath);
    if ~(isa(img, 'uint8') && ~isempty(img) && ...
            ndims(img) == 3 && size(img, 3) == 3)
        error('runLaplacianTextureExperiment:InvalidImage', ...
            '输入必须为非空 RGB uint8 图像。');
    end
    if ~(isnumeric(roi) && isreal(roi) && isequal(size(roi), [1, 4]) && ...
            all(isfinite(roi)) && all(roi == round(roi)) && all(roi >= 1) && ...
            roi(1) + roi(3) - 1 <= size(img, 2) && ...
            roi(2) + roi(4) - 1 <= size(img, 1))
        error('runLaplacianTextureExperiment:InvalidROI', ...
            'roi 必须为图像内的整数像素矩形 [x y width height]。');
    end
    roi = double(roi);

    [outImg, debug] = enhanceTextureLaplacian(img, alpha);
    alpha = double(alpha);
    bandPassParams = struct('sigmaFine1', 0.7, 'sigmaFine2', 1.2, ...
        'sigmaMid1', 1.1, 'sigmaMid2', 1.8);
    alphaFine = 7.5;
    alphaMid = 15;
    [detailFine, detailMid] = splitLayerDualBandPass(img, bandPassParams);
    [softMaskMid, softMaskFine, hardMask] = softHighlightMaskDual(img);
    imgRawBandPass = double(img) ...
        + alphaFine .* detailFine .* (1 - softMaskFine) ...
        + alphaMid .* detailMid .* (1 - softMaskMid);
    imgBandPass = uint8(round(min(max(imgRawBandPass, 0), 255)));

    showImageComparison({img, imgBandPass, outImg}, ...
        ["原图", "BandPass (5x5 / 9x9)", "Laplacian + Sobel"], roi);
    comparisonFigure = gcf;

    % 细节图共享对称尺度，梯度图共享尺度；全零时使用安全显示尺度1。
    displayScales = struct( ...
        'detailAbsMax', max(max(abs(debug.detail(:))), 1), ...
        'gradientMax', max(max(debug.gradient(:)), 1), ...
        'signedZeroLevel', 0.5, 'weightRange', [0, 1]);
    bandPass = struct('params', bandPassParams, ...
        'kernelSizeFine', 5, 'kernelSizeMid', 9, ...
        'alphaFine', alphaFine, 'alphaMid', alphaMid, ...
        'detailFine', detailFine, 'detailMid', detailMid, ...
        'softMaskFine', softMaskFine, 'softMaskMid', softMaskMid, ...
        'hardMask', hardMask, 'rawOutput', imgRawBandPass, 'output', imgBandPass);
    experiment = struct('inputPath', char(inputPath), 'img', img, ...
        'alpha', alpha, 'roi', roi, 'debug', debug, 'outImg', outImg, ...
        'bandPass', bandPass, 'displayScales', displayScales);

    [~, imageStem] = fileparts(char(inputPath));
    runName = [imageStem, '_', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))];
    outputDir = fullfile(outputRoot, runName);
    suffix = 1;
    while exist(outputDir, 'file') || exist(outputDir, 'dir')
        outputDir = fullfile(outputRoot, sprintf('%s_%d', runName, suffix));
        suffix = suffix + 1;
    end
    mkdir(outputDir);
    imwrite(img, fullfile(outputDir, '01_original.png'));
    imwrite(signedDisplay(debug.detail, displayScales.detailAbsMax), ...
        fullfile(outputDir, '02_laplacian_detail.png'));
    imwrite(unitDisplay(debug.gradient / displayScales.gradientMax), ...
        fullfile(outputDir, '03_sobel_gradient.png'));
    imwrite(unitDisplay(debug.gradientSmooth / displayScales.gradientMax), ...
        fullfile(outputDir, '04_sobel_gradient_smooth.png'));
    imwrite(unitDisplay(debug.sobelWeight), fullfile(outputDir, '05_sobel_weight.png'));
    imwrite(debug.highlightHardMask, fullfile(outputDir, '06_highlight_hard_mask.png'));
    imwrite(unitDisplay(debug.highlightSoftMask), ...
        fullfile(outputDir, '07_highlight_soft_mask.png'));
    imwrite(unitDisplay(debug.highlightWeight), ...
        fullfile(outputDir, '08_highlight_weight.png'));
    imwrite(signedDisplay(debug.weightedDetail, displayScales.detailAbsMax), ...
        fullfile(outputDir, '09_weighted_detail.png'));
    imwrite(outImg, fullfile(outputDir, '10_output.png'));
    imwrite(imgBandPass, fullfile(outputDir, '11_bandpass_output.png'));
    exportgraphics(comparisonFigure, fullfile(outputDir, 'comparison.png'), ...
        'Resolution', 150);
    save(fullfile(outputDir, 'experiment.mat'), 'experiment', '-v7.3');
    % 恢复调用前路径，显示窗口继续保留供观察。
    clear pathCleanup;
end


function imageU8 = signedDisplay(values, scale)
    imageU8 = unitDisplay(0.5 + 0.5 * values / scale);
end


function imageU8 = unitDisplay(values)
    imageU8 = uint8(round(255 * min(max(values, 0), 1)));
end
