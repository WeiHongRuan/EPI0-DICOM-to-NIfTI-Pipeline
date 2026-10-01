function runStep5CreateDestinations( ...
    mainFolder, processingFolders, destinationSuffixes)
%RUNSTEP5CREATEDESTINATIONS 建立組別-動物與五個固定子資料夾。

    fprintf('\n============================================================\n');
    fprintf('步驟 5/6：建立組別-動物編號資料夾與五個子資料夾\n');
    fprintf('============================================================\n');

    groupKeys = {processingFolders.GroupAnimal};
    uniqueGroupKeys = unique(groupKeys, 'stable');

    for groupIndex = 1:numel(uniqueGroupKeys)
        groupKey = uniqueGroupKeys{groupIndex};
        groupRoot = fullfile(mainFolder, groupKey);

        if ~isfolder(groupRoot)
            mkdir(groupRoot);
            fprintf('建立：%s\n', groupRoot);
        else
            fprintf('已存在，跳過建立：%s\n', groupRoot);
        end

        for suffixIndex = 1:numel(destinationSuffixes)
            destinationFolder = fullfile(groupRoot, ...
                sprintf('%s_%s', groupKey, ...
                destinationSuffixes{suffixIndex}));

            if ~isfolder(destinationFolder)
                mkdir(destinationFolder);
                fprintf('  建立：%s\n', destinationFolder);
            else
                fprintf('  已存在，跳過建立：%s\n', ...
                    destinationFolder);
            end
        end
    end
end
