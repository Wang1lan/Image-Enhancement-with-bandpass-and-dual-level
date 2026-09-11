function tests = testSingleHighlightMask
%TESTSINGLEHIGHLIGHTMASK 阈值、保护范围及 Fine Mask 精确兼容性。
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


function testHardMaskThresholdBoundaries(testCase)
    % Te=237，Th=217，Tl=26，三个边界均包含等号。
    colors = uint8([237, 0, 0; 236, 0, 0; 217, 191, 200; ...
        217, 190, 200; 216, 216, 216; 217, 217, 217; ...
        236, 210, 220; 236, 209, 220]);
    img = permute(colors, [3, 1, 2]);
    [~, hard] = softHighlightMaskSingle(img);
    verifyEqual(testCase, hard, logical([1, 0, 1, 0, 0, 1, 1, 0]));
    verifyClass(testCase, hard, 'logical');
end


function testCenterSpotHasExactCoreAndGaussianOuterRing(testCase)
    img = zeros(9, 9, 3, 'uint8');
    img(5, 5, :) = 255;
    [soft, hard] = softHighlightMaskSingle(img);
    expectedHard = false(9);
    expectedHard(5, 5) = true;
    % 3 像素宽核心与 [1 4 6 4 1] 的一维重叠和，独立手算。
    overlap = [0, 1, 5, 11, 14, 11, 5, 1, 0];
    expectedU8 = floor(255 * (overlap.' * overlap) / 256 + 0.5);
    expectedU8(4:6, 4:6) = 255;
    verifyEqual(testCase, hard, expectedHard);
    verifyClass(testCase, soft, 'double');
    verifyEqual(testCase, soft, expectedU8 / 255);
    verifyEqual(testCase, soft(5, :), [0, 14, 70, 255, 255, 255, 70, 14, 0] / 255);
    verifyEqual(testCase, soft, rot90(soft, 2));
end


function testCornerSpotUsesSymmetricGaussianBoundary(testCase)
    img = zeros(7, 7, 3, 'uint8');
    img(1, 1, :) = 255;
    [soft, hard] = softHighlightMaskSingle(img);
    expectedHard = false(7);
    expectedHard(1, 1) = true;
    % 左上 2x2 核心镜像扩展后的高斯重叠和。
    overlap = [15, 11, 5, 1, 0, 0, 0];
    expectedU8 = floor(255 * (overlap.' * overlap) / 256 + 0.5);
    expectedU8(1:2, 1:2) = 255;
    verifyEqual(testCase, hard, expectedHard);
    verifyEqual(testCase, soft, expectedU8 / 255);
    verifyEqual(testCase, soft(1, 3:5), [75, 15, 0] / 255);
end


function testOnePixelAndOneDimensionalInputs(testCase)
    for level = [0, 255]
        img = repmat(uint8(level), [1, 1, 3]);
        [soft, hard] = softHighlightMaskSingle(img);
        verifyEqual(testCase, soft, double(level == 255));
        verifyEqual(testCase, hard, level == 255);
    end
    rowImg = zeros(1, 9, 3, 'uint8');
    rowImg(1, 5, :) = 255;
    [softRow, hardRow] = softHighlightMaskSingle(rowImg);
    expectedRow = [0, 16, 80, 255, 255, 255, 80, 16, 0] / 255;
    verifyEqual(testCase, softRow, expectedRow);
    verifyEqual(testCase, hardRow, logical([0, 0, 0, 0, 1, 0, 0, 0, 0]));
    [softCol, hardCol] = softHighlightMaskSingle(permute(rowImg, [2, 1, 3]));
    verifyEqual(testCase, softCol, expectedRow.');
    verifyEqual(testCase, hardCol, hardRow.');
end


function testDilationProtectsSquareNeighborhoodIncludingBorders(testCase)
    mask = false(7);
    mask(4, 4) = true;
    expectedOnce = false(7);
    expectedOnce(3:5, 3:5) = true;
    expectedTwice = false(7);
    expectedTwice(2:6, 2:6) = true;
    verifyEqual(testCase, dilate3x3(mask, 1), expectedOnce);
    verifyEqual(testCase, dilate3x3(mask, 2), expectedTwice);
    corner = false(4);
    corner(1, 1) = true;
    expectedCorner = false(4);
    expectedCorner(1:2, 1:2) = true;
    verifyEqual(testCase, dilate3x3(corner, 1), expectedCorner);
    verifyEqual(testCase, dilate3x3(logical([0, 1, 0, 0]), 1), logical([1, 1, 1, 0]));
    verifyEqual(testCase, dilate3x3(true, 1), true);
end


function testSingleExactlyMatchesDualFineAndHard(testCase)
    texture = uint8(reshape(mod(0:(13 * 15 * 3 - 1), 256), [13, 15, 3]));
    corner = zeros(7, 8, 3, 'uint8');
    corner(1, 1, :) = 255;
    corner(end, end, :) = 255;
    row = zeros(1, 9, 3, 'uint8');
    row(1, 5, :) = 255;
    images = {texture, corner, row, permute(row, [2, 1, 3]), ...
        zeros(1, 1, 3, 'uint8'), repmat(uint8(255), [1, 1, 3])};
    for i = 1:numel(images)
        [single, hard] = softHighlightMaskSingle(images{i});
        [~, fine, referenceHard] = softHighlightMaskDual(images{i});
        verifyEqual(testCase, single, fine);
        verifyEqual(testCase, hard, referenceHard);
    end
end
