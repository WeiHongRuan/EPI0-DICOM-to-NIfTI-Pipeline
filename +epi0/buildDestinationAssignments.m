function assignments = buildDestinationAssignments( ...
    processingFolders, mainFolder, destinationSuffixes)
%BUILDDESTINATIONASSIGNMENTS 建立固定的來源 E 編號與目的槽位對應。
%
% 使用完整來源清單排序，因此重新執行時不會發生 E2 往前補到 E1
% 目的資料夾的問題。

    emptyAssignment = struct( ...
        'SourcePath', '', ...
        'GroupAnimal', '', ...
        'EOrder', Inf, ...
        'SlotIndex', Inf, ...
        'DestinationFolder', '', ...
        'DestinationFile', '');

    assignments = repmat(emptyAssignment, 0, 1);

    if isempty(processingFolders)
        return;
    end

    groupKeys = {processingFolders.GroupAnimal};
    uniqueGroupKeys = unique(groupKeys, 'stable');

    for groupIndex = 1:numel(uniqueGroupKeys)
        groupKey = uniqueGroupKeys{groupIndex};
        groupSources = processingFolders(strcmp(groupKeys, groupKey));
        groupSources = sortSourceFoldersByE(groupSources);

        for sourceIndex = 1:numel(groupSources)
            entry = emptyAssignment;
            entry.SourcePath = groupSources(sourceIndex).Path;
            entry.GroupAnimal = groupKey;
            entry.EOrder = groupSources(sourceIndex).EOrder;
            entry.SlotIndex = sourceIndex;

            if sourceIndex <= numel(destinationSuffixes)
                entry.DestinationFolder = fullfile(mainFolder, groupKey, ...
                    sprintf('%s_%s', groupKey, ...
                    destinationSuffixes{sourceIndex}));

                entry.DestinationFile = fullfile( ...
                    entry.DestinationFolder, 'EPI0.nii');
            end

            assignments(end+1, 1) = entry; %#ok<AGROW>
        end
    end
end


function sortedFolders = sortSourceFoldersByE(sourceFolders)
    if isempty(sourceFolders)
        sortedFolders = sourceFolders;
        return;
    end

    sortTokens = cell(numel(sourceFolders), 1);

    for index = 1:numel(sourceFolders)
        eValue = sourceFolders(index).EOrder;

        if ~isfinite(eValue)
            eValue = 999999999;
        end

        sortTokens{index} = sprintf('%09d_%s', ...
            round(eValue), lower(sourceFolders(index).Name));
    end

    [~, order] = sort(sortTokens);
    sortedFolders = sourceFolders(order);
end
