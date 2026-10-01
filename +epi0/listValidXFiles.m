function xFiles = listValidXFiles(folderPath)
%LISTVALIDXFILES 找出尚未改名的 *X.nii 中間檔。

    xFiles = dir(fullfile(folderPath, '*X.nii'));

    if isempty(xFiles)
        return;
    end

    invalidNames = {'EPI0.nii', 'T2X.nii'};
    validMask = ~ismember({xFiles.name}, invalidNames);
    xFiles = xFiles(validMask);
end
