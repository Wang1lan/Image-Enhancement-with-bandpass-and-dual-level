clc;
clear;
close all;

% Laplacian + Sobel + Single Highlight SoftMask 独立浮点实验。
% 运行时框选一次 ROI，三图共用；只比较和保存，不计算评价指标。
moduleRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(moduleRoot);

%% 输入及唯一的新算法调参项
inputPath = fullfile(projectRoot, 'ComenImg', '消化道临床', ...
    '20251204144725453.bmp');
alpha = 3;
outputRoot = fullfile(moduleRoot, 'Results');

originalPath = path;
addpath(fullfile(moduleRoot, 'Functions'), '-begin');
try
    img = imread(inputPath);
    if ~(isa(img, 'uint8') && ~isempty(img) && ...
            ndims(img) == 3 && size(img, 3) == 3)
        error('demo_laplacian_texture:InvalidImage', ...
            '输入必须为非空 RGB uint8 图像。');
    end

    %% 原图上运行时框选，R2022a 的 wait 没有返回值
    roi = selectComparisonROI(img);

    %% 同图对照并保存完整实验
    % BandPass: Fine 5x5 / 0.7,1.2；Mid 9x9 / 1.1,1.8；增量 7.5/15。
    outputDir = runLaplacianTextureExperiment(inputPath, alpha, roi, outputRoot);
    fprintf('Saved experiment: %s\n', outputDir);
catch experimentError
    path(originalPath);
    rethrow(experimentError);
end
path(originalPath);


function roi = selectComparisonROI(img)
    originalFigure = figure('Name', 'Select shared ROI', 'NumberTitle', 'off');
    figureCleanup = onCleanup(@() closeIfValid(originalFigure));
    originalAxes = axes('Parent', originalFigure);
    imshow(img, 'Parent', originalAxes);
    title(originalAxes, '原图：框选需比较的 ROI，双击确认');
    try
        roiHandle = drawrectangle(originalAxes, 'Color', [1, 0, 0], ...
            'LineWidth', 1.5);
        if isempty(roiHandle) || ~isvalid(roiHandle) || isempty(roiHandle.Position)
            error('demo_laplacian_texture:ROISelectionCancelled', ...
                'ROI 框选已取消。');
        end
        wait(roiHandle);
    catch selectionError
        if ~isgraphics(originalAxes, 'axes') || ...
                ~exist('roiHandle', 'var') || isempty(roiHandle) || ...
                ~isvalid(roiHandle)
            error('demo_laplacian_texture:ROISelectionCancelled', ...
                'ROI 框选已取消，未生成实验结果。');
        end
        rethrow(selectionError);
    end
    if ~isgraphics(originalAxes, 'axes') || ~isvalid(roiHandle)
        error('demo_laplacian_texture:ROISelectionCancelled', ...
            'ROI 框选已取消，未生成实验结果。');
    end
    position = roiHandle.Position;
    if numel(position) ~= 4 || any(~isfinite(position)) || ...
            any(position(3:4) <= 0)
        error('demo_laplacian_texture:ROISelectionCancelled', ...
            '未完成有效 ROI 框选。');
    end
    selected = round(position);
    x1 = max(selected(1), 1);
    y1 = max(selected(2), 1);
    x2 = min(selected(1) + selected(3) - 1, size(img, 2));
    y2 = min(selected(2) + selected(4) - 1, size(img, 1));
    if x2 < x1 || y2 < y1
        error('demo_laplacian_texture:InvalidROI', ...
            '框选 ROI 与图像没有有效像素交集。');
    end
    roi = [x1, y1, x2 - x1 + 1, y2 - y1 + 1];
    clear figureCleanup;
end


function closeIfValid(fig)
    if isgraphics(fig, 'figure')
        close(fig);
    end
end
