function outputFile = scaleNiftiSpaceByFactor(inputFile, scaleFactor)
%SCALENIFTISPACEBYFACTOR 只修改 NIfTI 空間標頭，不改 voxel 數值。
%
% 輸入 .nii 先逐 byte 複製，再只修改 pixdim、qform 與 sform。
% 不會 niftiread/niftiwrite 整個 4D 影像，因此速度較快。

    validateattributes(scaleFactor, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});

    info = niftiinfo(inputFile);

    if ~isfield(info, 'Transform') || ...
            ~isa(info.Transform, 'affine3d')
        error('輸入 NIfTI 沒有可用的 affine3d Transform：%s', ...
            inputFile);
    end

    affineMatrix = double(info.Transform.T');
    affineMatrix(1:3, :) = ...
        affineMatrix(1:3, :) .* scaleFactor;

    if numel(info.PixelDimensions) < 3
        error('NIfTI PixelDimensions 少於三維：%s', inputFile);
    end

    scaledPixelDimensions = double(info.PixelDimensions(:)');
    scaledPixelDimensions(1:3) = ...
        scaledPixelDimensions(1:3) .* scaleFactor;

    [folderPath, baseName] = fileparts(inputFile);
    outputFile = fullfile(folderPath, [baseName 'X.nii']);

    if isfile(outputFile)
        error('放大後的輸出已存在，程式拒絕覆蓋：%s', ...
            outputFile);
    end

    [copySucceeded, copyMessage] = ...
        copyfile(inputFile, outputFile);

    if ~copySucceeded
        error('無法複製 NIfTI 以建立放大版本：%s', ...
            copyMessage);
    end

    try
        timeSpacing = extractNiftiTimeSpacing(info);

        epi0.patchNiftiCoreMetadata( ...
            outputFile, scaledPixelDimensions, timeSpacing, '');

        epi0.patchNiftiSpatialTransform( ...
            outputFile, affineMatrix);

    catch ME
        if isfile(outputFile)
            delete(outputFile);
        end

        rethrow(ME);
    end
end


function timeSpacing = extractNiftiTimeSpacing(info)
    timeSpacing = NaN;

    if numel(info.PixelDimensions) >= 4 && ...
            isfinite(info.PixelDimensions(4)) && ...
            info.PixelDimensions(4) > 0

        timeSpacing = double(info.PixelDimensions(4));
        return;
    end

    if isfield(info, 'raw') && isstruct(info.raw) && ...
            isfield(info.raw, 'pixdim') && ...
            numel(info.raw.pixdim) >= 5

        candidate = double(info.raw.pixdim(5));

        if isfinite(candidate) && candidate > 0
            timeSpacing = candidate;
        end
    end
end
