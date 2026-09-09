function showImageComparison(imgList, titles, roi)
%SHOWIMAGECOMPARISON 显示多张图像及其相同 ROI 的局部放大对比
%   showImageComparison(imgList, titles, roi) 根据 imgList 中的图像数量
%   自动生成近似方形布局。图像必须是 uint8/uint16 RGB 图像。roi 的
%   格式为 [x, y, width, height]，其中 x、y 是从 1 开始的整数像素坐标。

%{
% 获取ROI

% 在 Original 单图中框选 ROI，双击确认。
originalFigure = figure();
originalAxes = axes('Parent', originalFigure);
imshow(img, 'Parent', originalAxes);
title(originalAxes, 'Original：请框选 ROI，双击确认');
roiHandle = drawrectangle(originalAxes, ...
    'Color', [1, 0, 0], ...
    'LineWidth', 1.5);
try
    wait(roiHandle);
catch selectionError
    if ~isgraphics(originalAxes, 'axes') || ~isvalid(roiHandle)
        error('demo_compare:ROISelectionCancelled', ...
            'ROI 框选已取消，无法生成对比图。');
    end
    rethrow(selectionError);
end

if ~isgraphics(originalAxes, 'axes') || ~isvalid(roiHandle)
    error('demo_compare:ROISelectionCancelled', ...
        'ROI 框选已取消，无法生成对比图。');
end
roiPosition = roiHandle.Position;

% 将连续坐标转换为从 1 开始的整数像素 ROI，并限制在图像范围内。
roi = round(roiPosition);
roi(1) = min(max(roi(1), 1), width);
roi(2) = min(max(roi(2), 1), height);
roi(3) = min(max(roi(3), 1), width - roi(1) + 1);
roi(4) = min(max(roi(4), 1), height - roi(2) + 1);

if isvalid(roiHandle)
    delete(roiHandle);
end

%}

    [titles, roi] = validateInputs(imgList, titles, roi);
    imageCount = numel(imgList);
    columnCount = ceil(sqrt(imageCount));
    rowCount = ceil(imageCount / columnCount);

    x = roi(1);
    y = roi(2);
    roiWidth = roi(3);
    roiHeight = roi(4);

    fig = figure( ...
        'Name', 'Image ROI Comparison', ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'Position', [100, 100, 1500, 650]);
    layout = tiledlayout(fig, rowCount, columnCount, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    mainAxes = gobjects(1, imageCount);
    insetAxes = gobjects(1, imageCount);

    for i = 1:imageCount
        mainAxes(i) = nexttile(layout, i);
        imshow(imgList{i}, 'Parent', mainAxes(i));
        title(mainAxes(i), titles(i), 'Interpreter', 'none');
        hold(mainAxes(i), 'on');
        rectangle(mainAxes(i), ...
            'Position', [x - 0.5, y - 0.5, roiWidth, roiHeight], ...
            'EdgeColor', [1, 0, 0], ...
            'LineWidth', 1.5);
        hold(mainAxes(i), 'off');
    end

    % 等待 tiledlayout 完成排版后，再按照各 tile 的实际位置创建 inset。
    drawnow;
    for i = 1:imageCount
        roiImage = imgList{i}( ...
            y:(y + roiHeight - 1), ...
            x:(x + roiWidth - 1), :);

        insetAxes(i) = axes( ...
            'Parent', fig, ...
            'Units', 'normalized');
        imshow(roiImage, 'Parent', insetAxes(i));
        axis(insetAxes(i), 'image');
        set(insetAxes(i), ...
            'Visible', 'on', ...
            'XTick', [], ...
            'YTick', [], ...
            'Box', 'on', ...
            'LineWidth', 2, ...
            'XColor', [1, 0, 0], ...
            'YColor', [1, 0, 0]);
    end

    updateInsetPositions(mainAxes, insetAxes);
    fig.SizeChangedFcn = @(~, ~) updateInsetPositions(mainAxes, insetAxes);

    % R2022a 中 tiledlayout 可能在 figure 缩放回调结束后才更新 axes。
    % 监听主 axes 完成重绘的事件，用新位置对 inset 做最终校正。
    layoutListeners = cell(1, imageCount);
    for i = 1:imageCount
        mainAxis = mainAxes(i);
        insetAxis = insetAxes(i);
        layoutListeners{i} = addlistener(mainAxis, 'MarkedClean', ...
            @(~, ~) updateSingleInsetPosition(mainAxis, insetAxis));
    end
    setappdata(fig, 'InsetLayoutListeners', layoutListeners);
end


function [titleStrings, roi] = validateInputs(imgList, titles, roi)
    if ~iscell(imgList) || isempty(imgList)
        error('showImageComparison:InvalidImageList', ...
            'imgList 必须是至少包含 1 张图像的非空元胞数组。');
    end

    imageCount = numel(imgList);

    firstImage = imgList{1};
    if ~isValidRgbImage(firstImage)
        error('showImageComparison:InvalidImageList', ...
            '每张图像必须是非空 uint8 或 uint16 RGB 图像。');
    end

    imageSize = size(firstImage);
    imageClass = class(firstImage);
    for i = 2:imageCount
        if ~isValidRgbImage(imgList{i}) || ...
                ~isequal(size(imgList{i}), imageSize) || ...
                ~strcmp(class(imgList{i}), imageClass)
            error('showImageComparison:InvalidImageList', ...
                '所有图像必须具有相同的尺寸和数据类型。');
        end
    end

    if isstring(titles)
        titleStrings = titles;
    elseif iscellstr(titles)
        titleStrings = string(titles);
    else
        error('showImageComparison:InvalidTitles', ...
            'titles 必须是字符串数组或字符元胞数组。');
    end
    if numel(titleStrings) ~= imageCount
        error('showImageComparison:InvalidTitles', ...
            'titles 的数量必须与 imgList 中的图像数量相同。');
    end
    titleStrings = reshape(titleStrings, 1, []);

    if ~isnumeric(roi) || ~isreal(roi) || numel(roi) ~= 4
        error('showImageComparison:InvalidROI', ...
            'roi 必须是 [x, y, width, height] 数值向量。');
    end
    roi = double(reshape(roi, 1, []));
    if any(~isfinite(roi)) || any(roi ~= round(roi)) || any(roi <= 0)
        error('showImageComparison:InvalidROI', ...
            'roi 必须包含 4 个正整数。');
    end

    imageHeight = imageSize(1);
    imageWidth = imageSize(2);
    if roi(1) + roi(3) - 1 > imageWidth || ...
            roi(2) + roi(4) - 1 > imageHeight
        error('showImageComparison:InvalidROI', ...
            'roi 超出图像范围。');
    end
end


function tf = isValidRgbImage(img)
    tf = ~isempty(img) && ...
        (isa(img, 'uint8') || isa(img, 'uint16')) && ...
        ndims(img) == 3 && size(img, 3) == 3;
end


function updateInsetPositions(mainAxes, insetAxes)
    for i = 1:numel(mainAxes)
        updateSingleInsetPosition(mainAxes(i), insetAxes(i));
    end
end


function updateSingleInsetPosition(mainAxis, insetAxis)
    if ~isgraphics(mainAxis, 'axes') || ~isgraphics(insetAxis, 'axes')
        return;
    end

    insetScale = 0.34;
    marginScale = 0.025;
    mainPosition = mainAxis.Position;
    insetWidth = insetScale * mainPosition(3);
    insetHeight = insetScale * mainPosition(4);
    marginX = marginScale * mainPosition(3);
    marginY = marginScale * mainPosition(4);
    insetPosition = [ ...
        mainPosition(1) + mainPosition(3) - insetWidth - marginX, ...
        mainPosition(2) + marginY, ...
        insetWidth, ...
        insetHeight];
    insetAxis.Position = insetPosition;
end
