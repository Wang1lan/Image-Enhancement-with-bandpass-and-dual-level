function outputDirs = validateRealImageExperiments
%VALIDATEREALIMAGEEXPERIMENTS 两张实图的算法、显示导出和MAT保存检查。
%   使用明确固定的 ROI 进行自动检查；不替代 demo 的手动框选验收。
    moduleRoot = fileparts(fileparts(mfilename('fullpath')));
    projectRoot = fileparts(moduleRoot);
    originalPath = path;
    originalVisibility = get(groot, 'DefaultFigureVisible');
    environmentCleanup = onCleanup(@() restoreEnvironment( ...
        originalPath, originalVisibility));
    addpath(fullfile(moduleRoot, 'Functions'), '-begin');
    set(groot, 'DefaultFigureVisible', 'off');

    inputPaths = { ...
        fullfile(projectRoot, 'ComenImg', '消化道临床', '20251204144725453.bmp'), ...
        fullfile(projectRoot, 'OlympusImg', ...
            'CV-1500_07351590_20260819092655_PE_0001.jpg')};
    outputDirs = cell(size(inputPaths));
    for i = 1:numel(inputPaths)
        inputPath = inputPaths{i};
        img = imread(inputPath);
        roi = [floor(size(img, 2) / 3), floor(size(img, 1) / 3), 160, 120];
        startTime = tic;
        [outputDir, experiment] = runLaplacianTextureExperiment( ...
            inputPath, 3, roi, fullfile(moduleRoot, 'Results'));
        outputDirs{i} = outputDir;
        saved = load(fullfile(outputDir, 'experiment.mat'), 'experiment');
        assert(isequaln(saved.experiment, experiment), 'MAT 数据未完整保留。');
        assert(isequal(experiment.img, img), '原始输入发生变化。');
        assert(isequal(experiment.roi, roi), 'ROI 未完整保存。');
        assert(experiment.alpha == 3, 'alpha 与设定不一致。');
        assert(experiment.bandPass.kernelSizeFine == 5 && ...
            experiment.bandPass.kernelSizeMid == 9, 'BandPass 核尺寸不正确。');
        assert(isequal(experiment.bandPass.params, struct( ...
            'sigmaFine1', 0.7, 'sigmaFine2', 1.2, ...
            'sigmaMid1', 1.1, 'sigmaMid2', 1.8)), 'BandPass 参数不正确。');
        assert(experiment.bandPass.alphaFine == 7.5 && ...
            experiment.bandPass.alphaMid == 15, 'BandPass 增量增益不正确。');

        pngFiles = dir(fullfile(outputDir, '*.png'));
        assert(numel(pngFiles) == 12, '应保存十张设计图、BandPass图和对比图。');
        for j = 1:numel(pngFiles)
            filePath = fullfile(outputDir, pngFiles(j).name);
            png = imread(filePath);
            assert(~isempty(png), 'PNG 无法读取。');
            if ~strcmp(pngFiles(j).name, 'comparison.png')
                assert(size(png, 1) == size(img, 1) && ...
                    size(png, 2) == size(img, 2), 'PNG 尺寸与原图不一致。');
            end
        end
        assert(isequal(imread(fullfile(outputDir, '01_original.png')), img));
        assert(isequal(imread(fullfile(outputDir, '10_output.png')), experiment.outImg));
        assert(isequal(imread(fullfile(outputDir, '11_bandpass_output.png')), ...
            experiment.bandPass.output));

        debug = experiment.debug;
        assert(all(isfinite(debug.detail(:))) && any(debug.detail(:) < 0) && ...
            any(debug.detail(:) > 0), 'Laplacian 有符号细节未保留。');
        assert(all(isfinite(debug.weightedDetail(:))), '加权细节存在非有限值。');
        core = dilate3x3(debug.highlightHardMask, 1);
        assert(all(debug.highlightSoftMask(core) == 1));
        assert(all(debug.weightedDetail(core) == 0));
        for channel = 1:3
            inputChannel = img(:, :, channel);
            outputChannel = experiment.outImg(:, :, channel);
            assert(isequal(inputChannel(core), outputChannel(core)), ...
                '高光膨胀核心内输出发生变化。');
        end
        scale = experiment.displayScales.detailAbsMax;
        expectedDetail = uint8(round(255 * min(max( ...
            0.5 + 0.5 * debug.detail / scale, 0), 1)));
        expectedWeighted = uint8(round(255 * min(max( ...
            0.5 + 0.5 * debug.weightedDetail / scale, 0), 1)));
        assert(isequal(imread(fullfile(outputDir, '02_laplacian_detail.png')), expectedDetail));
        assert(isequal(imread(fullfile(outputDir, '09_weighted_detail.png')), expectedWeighted));
        fprintf('REAL_IMAGE_PASS %d size=%dx%d elapsed=%.2fs\n%s\n', ...
            i, size(img, 2), size(img, 1), toc(startTime), outputDir);
        close all;
    end
    fprintf('REAL_IMAGE_TOTAL=%d PASSED=%d\n', numel(inputPaths), numel(outputDirs));
    clear environmentCleanup;
end


function restoreEnvironment(originalPath, originalVisibility)
    path(originalPath);
    set(groot, 'DefaultFigureVisible', originalVisibility);
end
