function tests = testLaplacianTexture
%TESTLAPLACIANTEXTURE Laplacian + Sobel + 单亮斑保护的行为验收。
    tests = functiontests(localfunctions);
end


function setupOnce(testCase)
    moduleRoot = fileparts(fileparts(mfilename('fullpath')));
    testCase.TestData.originalPath = path;
    addpath(fullfile(moduleRoot, 'Functions'));
    addpath(fullfile(moduleRoot, 'ReferenceBandPass'));
end


function teardownOnce(testCase)
    path(testCase.TestData.originalPath);
end


function testConstantColorsAreUnchangedIncludingSmallImages(testCase)
    colors = uint8([0, 0, 0; 73, 101, 149; 255, 255, 255]);
    shapes = [9, 11; 1, 1; 1, 7; 7, 1];
    for colorIndex = 1:size(colors, 1)
        for shapeIndex = 1:size(shapes, 1)
            img = repmat(reshape(colors(colorIndex, :), [1, 1, 3]), ...
                [shapes(shapeIndex, :), 1]);
            [out, debug] = enhanceTextureLaplacian(img);
            verifyEqual(testCase, out, img);
            verifyLessThan(testCase, max(abs(debug.detail(:))), 1e-10);
            verifyLessThan(testCase, max(abs(debug.weightedDetail(:))), 1e-10);
        end
    end
end


function testAlphaZeroIsIdentity(testCase)
    img = makeTexture();
    [out, debug] = enhanceTextureLaplacian(img, 0);
    verifyEqual(testCase, out, img);
    verifyEqual(testCase, debug.Yout, debug.Y);
end


function testDefaultAlphaEqualsThree(testCase)
    img = makeTexture();
    [outDefault, debugDefault] = enhanceTextureLaplacian(img);
    [outExplicit, debugExplicit] = enhanceTextureLaplacian(img, 3);
    verifyEqual(testCase, outDefault, outExplicit);
    verifyEqual(testCase, debugDefault, debugExplicit);
end


function testPositiveCenterKernelSharpensStepWithAddition(testCase)
    img = repmat(uint8(80), [11, 17, 3]);
    img(:, 9:end, :) = 140;
    [out, debug] = enhanceTextureLaplacian(img, 3);

    % 60 DN 阶跃：边缘 detail 为 -60/+60，平滑梯度为 96。
    verifyEqual(testCase, debug.detail(6, 8:9), [-60, 60], 'AbsTol', 1e-10);
    verifyEqual(testCase, debug.sobelWeight(6, 8:9), ...
        [96, 96] / 2040, 'AbsTol', 1e-12);
    verifyEqual(testCase, debug.Yout(6, 8:9), ...
        [80, 140] + 3 * [-60, 60] * (96 / 2040), 'AbsTol', 1e-10);
    verifyEqual(testCase, out(6, 8:9, 1), uint8([72, 148]));
    verifyEqual(testCase, out(:, [1, end], :), img(:, [1, end], :));
end


function testFloatingLumaAndSharedRgbIncrement(testCase)
    img = repmat(reshape(uint8([70, 90, 110]), [1, 1, 3]), [11, 11, 1]);
    img(6, 6, :) = reshape(uint8([100, 120, 140]), [1, 1, 3]);
    [out, debug] = enhanceTextureLaplacian(img);

    % 30 DN 单点脉冲的 Laplacian 中心为 120；Sobel L1 总量为 480。
    verifyEqual(testCase, debug.Y(6, 6), 116.3, 'AbsTol', 1e-12);
    verifyEqual(testCase, debug.Y(1, 1), 86.3, 'AbsTol', 1e-12);
    verifyEqual(testCase, debug.weightedDetail(6, 6), ...
        120 * (480 / 25) / 2040, 'AbsTol', 1e-12);
    verifyEqual(testCase, debug.Yout(6, 6), ...
        116.3 + 3 * 120 * (480 / 25) / 2040, 'AbsTol', 1e-12);
    verifyEqual(testCase, reshape(out(6, 6, :), 1, 3), uint8([103, 123, 143]));
    increment = double(out) - double(img);
    verifyEqual(testCase, increment(:, :, 1), increment(:, :, 2));
    verifyEqual(testCase, increment(:, :, 2), increment(:, :, 3));
end


function testLumaAndRgbSaturateAtBothRails(testCase)
    backgrounds = uint8([100, 80, 40; 115, 135, 175]);
    centers = uint8([210, 190, 150; 5, 25, 65]);
    expectedRgb = uint8([255, 254, 214; 0, 1, 41]);
    expectedY = [255, 0];
    for i = 1:2
        img = repmat(reshape(backgrounds(i, :), [1, 1, 3]), [11, 11, 1]);
        img(6, 6, :) = reshape(centers(i, :), [1, 1, 3]);
        [out, debug] = enhanceTextureLaplacian(img, 100);
        verifyEqual(testCase, debug.Yout(6, 6), expectedY(i));
        verifyEqual(testCase, reshape(out(6, 6, :), 1, 3), expectedRgb(i, :));
        verifyGreaterThanOrEqual(testCase, min(debug.Yout(:)), 0);
        verifyLessThanOrEqual(testCase, max(debug.Yout(:)), 255);
    end
end


function testHighlightCoreBlocksNonzeroDetail(testCase)
    img = repmat(uint8(100), [11, 11, 3]);
    img(6, 6, :) = 255;
    [out, debug] = enhanceTextureLaplacian(img, 100);
    verifyGreaterThan(testCase, debug.detail(6, 6), 0);
    verifyLessThan(testCase, debug.detail(6, 5), 0);
    verifyEqual(testCase, debug.highlightSoftMask(5:7, 5:7), ones(3));
    verifyEqual(testCase, debug.highlightWeight(5:7, 5:7), zeros(3));
    verifyEqual(testCase, debug.weightedDetail(5:7, 5:7), zeros(3));
    verifyEqual(testCase, out, img);
end


function testDebugContractPreservesSignedDoubleDetails(testCase)
    img = makeTexture();
    inputCopy = img;
    [out, debug] = enhanceTextureLaplacian(img);
    expectedFields = {'Y'; 'detail'; 'gx'; 'gy'; 'gradient'; ...
        'gradientSmooth'; 'sobelWeight'; 'highlightHardMask'; ...
        'highlightSoftMask'; 'highlightWeight'; 'weightedDetail'; 'Yout'};
    verifyEqual(testCase, sort(fieldnames(debug)), sort(expectedFields));
    verifyClass(testCase, out, 'uint8');
    verifySize(testCase, out, size(img));
    verifyEqual(testCase, img, inputCopy);
    for i = 1:numel(expectedFields)
        name = expectedFields{i};
        verifySize(testCase, debug.(name), [size(img, 1), size(img, 2)]);
        if strcmp(name, 'highlightHardMask')
            verifyClass(testCase, debug.(name), 'logical');
        else
            value = debug.(name);
            verifyClass(testCase, value, 'double');
            verifyTrue(testCase, all(isfinite(value(:))));
        end
    end
    verifyLessThan(testCase, min(debug.detail(:)), 0);
    verifyGreaterThan(testCase, max(debug.detail(:)), 0);
    verifyLessThan(testCase, min(debug.weightedDetail(:)), 0);
    verifyGreaterThan(testCase, max(debug.weightedDetail(:)), 0);
    verifyEqual(testCase, debug.highlightWeight, 1 - debug.highlightSoftMask);
end


function testLaplacianImpulseAndReplicateBoundary(testCase)
    Y = zeros(7);
    Y(4, 4) = 10;
    detail = getLaplacianDetail(Y);
    expected = zeros(7);
    expected(4, 4) = 40;
    expected([3, 5], 4) = -10;
    expected(4, [3, 5]) = -10;
    verifyEqual(testCase, detail, expected);
    verifyClass(testCase, detail, 'double');
    verifyEqual(testCase, getLaplacianDetail([10, 20, 20]), [-10, 10, 0]);
    verifyEqual(testCase, getLaplacianDetail([10; 20; 20]), [-10; 10; 0]);
    verifyEqual(testCase, getLaplacianDetail(17), 0);
end


function testSobelUsesL1FiveByFiveMeanAndFixedNormalization(testCase)
    [x, y] = meshgrid(1:11);
    [weight, gx, gy, gradient, smooth] = getSobelWeight(100 + 2 * x - 3 * y);
    verifyEqual(testCase, gx(6, 6), 16);
    verifyEqual(testCase, gy(6, 6), -24);
    verifyEqual(testCase, gradient(6, 6), 40);
    verifyEqual(testCase, smooth(6, 6), 40, 'AbsTol', 1e-12);
    verifyEqual(testCase, weight(6, 6), 40 / 2040, 'AbsTol', 1e-12);
    verifyEqual(testCase, gx(6, [1, end]), [8, 8]);
    verifyEqual(testCase, gy([1, end], 6), [-12; -12]);

    Y = zeros(11, 15);
    Y(:, 8:end) = 100;
    [weight, ~, ~, ~, smooth] = getSobelWeight(Y);
    expectedSmooth = [0, 80, 160, 160, 160, 160, 80, 0];
    verifyEqual(testCase, smooth(6, 4:11), expectedSmooth, 'AbsTol', 1e-12);
    verifyEqual(testCase, weight(6, 4:11), expectedSmooth / 2040, 'AbsTol', 1e-12);
end


function testInvalidImagesHaveStableErrorId(testCase)
    images = {zeros(7, 9), zeros(7, 9, 3), zeros(7, 9, 3, 'uint16'), ...
        zeros(7, 9, 'uint8'), zeros(7, 9, 4, 'uint8'), ...
        zeros(7, 9, 3, 2, 'uint8'), zeros(0, 9, 3, 'uint8')};
    for i = 1:numel(images)
        verifyError(testCase, @() enhanceTextureLaplacian(images{i}), ...
            'enhanceTextureLaplacian:InvalidImage');
    end
end


function testInvalidAlphaHasStableErrorId(testCase)
    img = repmat(uint8(100), [5, 5, 3]);
    values = {-1, NaN, Inf, -Inf, 1i, [], [1, 3], '3', true, struct()};
    for i = 1:numel(values)
        verifyError(testCase, @() enhanceTextureLaplacian(img, values{i}), ...
            'enhanceTextureLaplacian:InvalidParameter');
    end
end


function img = makeTexture()
    img = uint8(reshape(mod(0:(13 * 15 * 3 - 1), 201), [13, 15, 3]));
end
