function niiFiles = listUnscaledConvertedNiftiFiles(folderPath)
%LISTUNSCALEDCONVERTEDNIFTIFILES 找出已轉檔但尚未放大 10 倍的 NIfTI。

    niiFiles = dir(fullfile(folderPath, '*.nii'));

    if isempty(niiFiles)
        return;
    end

    names = {niiFiles.name};
    isEPI0 = strcmpi(names, 'EPI0.nii');
    isT2X = strcmpi(names, 'T2X.nii');
    isScaledX = endsWith(names, 'X.nii', 'IgnoreCase', true);
    isTemporary = contains(names, ...
        '_header_template', 'IgnoreCase', true);

    niiFiles = niiFiles( ...
        ~isEPI0 & ~isT2X & ~isScaledX & ~isTemporary);
end
