function sourceFolders = discoverSourceFolders(mainFolder, config)
%DISCOVERSOURCEFOLDERS 找出符合日期-lhl-組別-動物編號格式的舊資料夾。

    if config.SearchOnlyDirectChildren
        listing = dir(mainFolder);
    else
        listing = dir(fullfile(mainFolder, '**', '*'));
    end

    listing = listing([listing.isdir]);
    listing = listing(~ismember({listing.name}, {'.', '..'}));

    emptySource = struct( ...
        'Path', '', ...
        'Name', '', ...
        'GroupAnimal', '', ...
        'EOrder', Inf, ...
        'DirectFileCount', 0);

    sourceFolders = repmat(emptySource, 0, 1);

    for index = 1:numel(listing)
        folderName = listing(index).name;
        [groupAnimal, eOrder] = parseSourceFolderName(folderName);

        if isempty(groupAnimal)
            continue;
        end

        folderPath = fullfile(listing(index).folder, folderName);
        directItems = dir(fullfile(folderPath, '*'));
        directFileCount = sum(~[directItems.isdir]);

        entry = emptySource;
        entry.Path = folderPath;
        entry.Name = folderName;
        entry.GroupAnimal = groupAnimal;
        entry.EOrder = eOrder;
        entry.DirectFileCount = directFileCount;

        sourceFolders(end+1, 1) = entry; %#ok<AGROW>
    end

    if ~isempty(sourceFolders)
        [~, uniqueIndices] = unique({sourceFolders.Path}, 'stable');
        sourceFolders = sourceFolders(uniqueIndices);
    end
end


function [groupAnimal, eOrder] = parseSourceFolderName(folderName)
    groupAnimal = '';
    eOrder = Inf;

    tokens = regexp(folderName, ...
        '^(?<date>\d{6,8})-lhl-(?<group>.+?)-(?<animal>nm\d+)(?:_|$)', ...
        'names', 'once', 'ignorecase');

    if isempty(tokens)
        return;
    end

    groupName = lower(sanitizeName(tokens.group));
    animalName = lower(sanitizeName(tokens.animal));
    groupAnimal = sprintf('%s-%s', groupName, animalName);

    eToken = regexp(folderName, '(?:^|_)E(\d+)(?:_|$)', ...
        'tokens', 'once', 'ignorecase');

    if ~isempty(eToken)
        eOrder = str2double(eToken{1});
    end
end


function name = sanitizeName(name)
    name = char(name);
    name = strtrim(name);
    name = regexprep(name, '[^\w\-]+', '_');
    name = regexprep(name, '_+', '_');
    name = regexprep(name, '^_|_$', '');

    if isempty(name)
        name = 'unnamed';
    end
end
