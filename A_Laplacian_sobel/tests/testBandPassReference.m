function tests = testBandPassReference
%TESTBANDPASSREFERENCE 本实验参考分支固定 5x5 / 9x9 的 DoG 验收。
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


function testDefaultImpulseUsesExactFiveAndNinePixelKernels(testCase)
    img = zeros(21, 21, 3, 'uint8');
    img(11, 11, 1) = 200;
    [fine, mid] = splitLayerDualBandPass(img);
    expectedFine = zeros(size(img));
    expectedMid = zeros(size(img));
    expectedFine(9:13, 9:13, 1) = 200 * independentDoG(5, 0.7, 1.2);
    expectedMid(7:15, 7:15, 1) = 200 * independentDoG(9, 1.1, 1.8);
    verifyEqual(testCase, fine, expectedFine, 'AbsTol', 1e-12);
    verifyEqual(testCase, mid, expectedMid, 'AbsTol', 1e-12);
    verifyClass(testCase, fine, 'double');
    verifyClass(testCase, mid, 'double');
    verifySize(testCase, fine, size(img));
    verifySize(testCase, mid, size(img));
    [fineRows, fineCols] = find(fine(:, :, 1) ~= 0);
    [midRows, midCols] = find(mid(:, :, 1) ~= 0);
    verifyEqual(testCase, [min(fineRows), max(fineRows), min(fineCols), max(fineCols)], ...
        [9, 13, 9, 13]);
    verifyEqual(testCase, [min(midRows), max(midRows), min(midCols), max(midCols)], ...
        [7, 15, 7, 15]);
    verifyLessThan(testCase, min(fine(:)), 0);
    verifyGreaterThan(testCase, max(fine(:)), 0);
    verifyLessThan(testCase, min(mid(:)), 0);
    verifyGreaterThan(testCase, max(mid(:)), 0);
end


function testDefaultSigmaPairsMatchExplicitParameters(testCase)
    img = uint8(reshape(mod(0:(11 * 13 * 3 - 1), 251), [11, 13, 3]));
    params = struct('sigmaFine1', 0.7, 'sigmaFine2', 1.2, ...
        'sigmaMid1', 1.1, 'sigmaMid2', 1.8);
    [fine, mid] = splitLayerDualBandPass(img);
    [fineExplicit, midExplicit] = splitLayerDualBandPass(img, params);
    verifyEqual(testCase, fine, fineExplicit);
    verifyEqual(testCase, mid, midExplicit);
end


function testConstantColorsHaveNoDetailAtReplicateBorders(testCase)
    color = reshape(uint8([0, 100, 255]), [1, 1, 3]);
    shapes = [11, 13; 1, 1; 1, 7; 7, 1];
    for i = 1:size(shapes, 1)
        img = repmat(color, [shapes(i, :), 1]);
        [fine, mid] = splitLayerDualBandPass(img);
        verifyLessThan(testCase, max(abs(fine(:))), 1e-10);
        verifyLessThan(testCase, max(abs(mid(:))), 1e-10);
    end
end


function testKernelGeneratorMatchesIndependentSeparableGaussian(testCase)
    settings = [5, 0.7, 1.2; 9, 1.1, 1.8];
    for i = 1:size(settings, 1)
        n = settings(i, 1);
        kernel = createDoGKernel(n, settings(i, 2), settings(i, 3));
        expected = independentDoG(n, settings(i, 2), settings(i, 3));
        verifySize(testCase, kernel, [n, n]);
        verifyEqual(testCase, kernel, expected, 'AbsTol', 1e-14);
        verifyLessThan(testCase, abs(sum(kernel(:))), 1e-12);
        verifyEqual(testCase, kernel, kernel.', 'AbsTol', 1e-15);
        verifyEqual(testCase, kernel, rot90(kernel, 2), 'AbsTol', 1e-15);
    end
end


function kernel = independentDoG(n, sigmaNarrow, sigmaWide)
    % 独立用一维 Gaussian 外积；不调用被测 createDoGKernel。
    x = -(n - 1) / 2:(n - 1) / 2;
    narrow = exp(-(x .^ 2) / (2 * sigmaNarrow ^ 2));
    wide = exp(-(x .^ 2) / (2 * sigmaWide ^ 2));
    narrow = narrow / sum(narrow);
    wide = wide / sum(wide);
    kernel = narrow.' * narrow - wide.' * wide;
end
