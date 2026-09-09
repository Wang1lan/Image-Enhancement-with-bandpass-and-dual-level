function imgEnh_fx = reconstructImage_fx(img, softMask, fineLayer, midLayer, params)

% 反转mask
softMask = 4095 - softMask;      % u12

% fineLayer
fineMap = int32(fineLayer) .* int32(softMask);                % s29
fineGainMap = int32(params.fineGain) .* int32(fineMap);       % s32

% midLayer
midMap = int32(midLayer) .* int32(softMask);                  % s29
midGainMap = int32(params.midGain) .* int32(midMap);          % s32

% 合并
imgEnh_fx_temp = img + fineGainMap;
imgEnh_fx = imgEnh_fx_temp + midGainMap;                  
end
