function state = inspectMRIIndexState(folderPath, firstIndex, lastIndex)
%INSPECTMRIINDEXSTATE 一次掃描檔名，判斷前段 MRI 檔案是否仍存在。

    listing = dir(fullfile(folderPath, '*'));
    listing = listing(~[listing.isdir]);

    indices = nan(numel(listing), 1);

    for index = 1:numel(listing)
        token = regexp(listing(index).name, '^MRIm(\d+)', ...
            'tokens', 'once', 'ignorecase');

        if ~isempty(token)
            indices(index) = str2double(token{1});
        end
    end

    validIndices = indices(isfinite(indices));

    state = struct;
    state.DirectFileCount = numel(listing);
    state.MRIFileCount = numel(validIndices);
    state.EarlyFileCount = sum( ...
        validIndices >= firstIndex & validIndices <= lastIndex);
    state.HasIndexAfterDeleteRange = any(validIndices > lastIndex);
end
