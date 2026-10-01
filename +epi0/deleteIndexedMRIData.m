function deletedCount = deleteIndexedMRIData( ...
    folderPath, firstIndex, lastIndex)
%DELETEINDEXEDMRIDATA 刪除指定 MRIm 編號範圍內的檔案。

    deletedCount = 0;

    listing = dir(fullfile(folderPath, '*'));
    listing = listing(~[listing.isdir]);

    for index = 1:numel(listing)
        token = regexp(listing(index).name, '^MRIm(\d+)', ...
            'tokens', 'once', 'ignorecase');

        if isempty(token)
            continue;
        end

        fileNumber = str2double(token{1});

        if isfinite(fileNumber) && ...
                fileNumber >= firstIndex && fileNumber <= lastIndex

            targetPath = fullfile( ...
                listing(index).folder, listing(index).name);

            delete(targetPath);
            deletedCount = deletedCount + 1;
        end
    end
end
