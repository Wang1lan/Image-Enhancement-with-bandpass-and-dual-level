clc;
clear;
close all;

addpath('./Functions_fx');

imgPath = ["D:\Endoscope\ImageEnhancement\ComenImg\消化道临床",...
            "D:\Endoscope\ImageEnhancement\ComenImg\BDI",...
            "D:\Endoscope\ImageEnhancement\ComenImg\分辨率板",...
            "D:\Endoscope\ImageEnhancement\OlympusImg"];

imgName_1 = ["20260710_161040694_SEI_1_.bmp", ...
            "20251204144145698.bmp", ...
            "20251204144725453.bmp", ...
            "20251204144729985.bmp", ...
            "20251204150152332.bmp", ...
            "20251204150644321.bmp"];

imgName_2 = ["19700101045511934.bmp", "19700101045515646.bmp"];

imgName_3 = ["20250516分辨率1.bmp", "20250516分辨率2.bmp"];

imgName_4 = ["CV-1500_07351590_20260819092655_PE_0001.jpg",...
            "CV-1500_07351590_20260819092658_PE_0002.jpg",...
            "CV-1500_07351590_20260819092702_PE_0003.jpg",...
            "CV-1500_07351590_20260819092704_PE_0004.jpg"];

imgName = {imgName_1, imgName_2, imgName_3, imgName_4};

%% 读取图像
img = imread(fullfile(imgPath(1), imgName{1}(5)));      % u8
img = bitshift(uint16(img), 4);                         % u12

%% 定点参数
params = parametersSet_fx();

%% softMask
softMask = softHighlightMask_fx(img);                   % u12

%% 提取细节层
[fineLayer, midLayer] = splitLayerDual_fx(img);

%% 图像增强
imgEnh_fx = reconstructImage_fx(img, softMask, fineLayer, midLayer, params);
