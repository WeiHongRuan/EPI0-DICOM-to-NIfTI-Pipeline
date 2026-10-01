function results = convertDicomFolder(inputPath, outputDir, options)
% Internal DICOM-to-NIfTI conversion implementation.
    % Accept a conventional third positional options structure so the GUI
    % can call:
    %   convertDicomFolder(inputPath, outputDir, options)
    if nargin < 2 || isempty(outputDir)
        outputDir = '';
    end

    if nargin < 3 || isempty(options)
        options = struct;
    end

    if ~isstruct(options)
        error('The third input must be an options structure.');
    end

    defaults = struct( ...
        'RecursiveFolderDepth', 5, ...
        'Anonymize', true, ...
        'Gzip', true, ...
        'Output4D', true, ...
        'AppendDate', true, ...
        'AppendSeries', true, ...
        'AppendProtocolName', true, ...
        'AppendPatientName', false, ...
        'AppendSourceName', false, ...
        'ReorientToCanonical', false, ...
        'RotateDegrees', 0, ...
        'DetectScanTime', true, ...
        'UseParallel', false, ...
        'MaxParallelWorkers', 4, ...
        'MinimumFilesForParallel', 200, ...
        'PreferMRImCandidates', true, ...
        'Verbose', true);

    defaultNames = fieldnames(defaults);
    for optionIndex = 1:numel(defaultNames)
        optionName = defaultNames{optionIndex};
        if ~isfield(options, optionName) || isempty(options.(optionName))
            options.(optionName) = defaults.(optionName);
        end
    end

    validateattributes(inputPath, {'char','string'}, ...
        {'nonempty'}, mfilename, 'inputPath', 1);
    validateattributes(outputDir, {'char','string'}, ...
        {}, mfilename, 'outputDir', 2);
    validateattributes(options.RecursiveFolderDepth, {'numeric'}, ...
        {'scalar','integer','nonnegative'}, mfilename, ...
        'options.RecursiveFolderDepth');

    logicalOptionNames = { ...
        'Anonymize','Gzip','Output4D','AppendDate','AppendSeries', ...
        'AppendProtocolName','AppendPatientName','AppendSourceName', ...
        'ReorientToCanonical','DetectScanTime','UseParallel', ...
        'PreferMRImCandidates','Verbose'};

    for optionIndex = 1:numel(logicalOptionNames)
        optionName = logicalOptionNames{optionIndex};
        validateattributes(options.(optionName), {'logical','numeric'}, ...
            {'scalar'}, mfilename, ['options.' optionName]);
        options.(optionName) = logical(options.(optionName));
    end

    validateattributes(options.RotateDegrees, {'numeric'}, ...
        {'scalar'}, mfilename, 'options.RotateDegrees');
    if ~ismember(double(options.RotateDegrees), [0 90 180 270])
        error('options.RotateDegrees must be 0, 90, 180, or 270.');
    end

    validateattributes(options.MaxParallelWorkers, {'numeric'}, ...
        {'scalar','integer','positive'}, mfilename, ...
        'options.MaxParallelWorkers');
    validateattributes(options.MinimumFilesForParallel, {'numeric'}, ...
        {'scalar','integer','nonnegative'}, mfilename, ...
        'options.MinimumFilesForParallel');

    inputPath = char(inputPath);
    outputDir = char(outputDir);

    if ~isfile(inputPath) && ~isfolder(inputPath)
        error('Input path does not exist: %s', inputPath);
    end

    if isempty(outputDir)
        if isfolder(inputPath)
            outputDir = inputPath;
        else
            outputDir = fileparts(inputPath);
        end
    end

    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    files = collectFiles(inputPath, options.RecursiveFolderDepth, ...
        options.PreferMRImCandidates);

    if isempty(files)
        error('No files were found under: %s', inputPath);
    end

    useParallel = options.UseParallel && ...
        numel(files) >= options.MinimumFilesForParallel;
    if useParallel
        useParallel = epi0.ensureParallelPool(options.MaxParallelWorkers);
    end

    if options.Verbose
        fprintf('Inspecting %d files (%s mode)...\n', numel(files), ...
            epi0.ternaryText(useParallel, 'parallel', 'serial'));
    end

    records = inspectDicomFiles(files, options.Verbose, useParallel);
    options.UseParallel = useParallel;

    if isempty(records)
        error('No readable DICOM files were found.');
    end

    groups = groupDicomRecords(records);

    if options.Verbose
        fprintf('Found %d DICOM series/group(s).\n', numel(groups));
    end

    emptyResult = struct( ...
        'SeriesInstanceUID', '', ...
        'OutputFile', '', ...
        'NumberOfFiles', 0, ...
        'VolumeSize', [], ...
        'Warnings', {{}});

    results = repmat(emptyResult, 0, 1);

    for groupIndex = 1:numel(groups)
        group = groups{groupIndex};

        if options.Verbose
            fprintf('\n[%d/%d] Converting %d file(s)...\n', ...
                groupIndex, numel(groups), numel(group));
        end

        try
            [imageData, niftiInfo, warnings] = buildNiftiVolume(group, options);

            filename = buildOutputFilename(group, options);
            outputBase = fullfile(outputDir, filename);

            writeNiftiFile(imageData, outputBase, niftiInfo, options.Gzip);

            if options.Gzip
                outputFile = [outputBase '.nii.gz'];
            else
                outputFile = [outputBase '.nii'];
            end

            result = emptyResult;
            result.SeriesInstanceUID = getStringField(group(1).Info, ...
                'SeriesInstanceUID', group(1).GroupKey);
            result.OutputFile = outputFile;
            result.NumberOfFiles = numel(group);
            result.VolumeSize = size(imageData);
            result.Warnings = warnings;
            results(end+1, 1) = result; %#ok<AGROW>

            if options.Verbose
                fprintf('Saved: %s\n', outputFile);
                for warningIndex = 1:numel(warnings)
                    fprintf('  Warning: %s\n', warnings{warningIndex});
                end
            end

        catch ME
            result = emptyResult;
            result.SeriesInstanceUID = group(1).GroupKey;
            result.NumberOfFiles = numel(group);
            result.Warnings = {ME.message};
            results(end+1, 1) = result; %#ok<AGROW>

            warning('Failed to convert group %s:\n%s', ...
                group(1).GroupKey, getReport(ME, 'basic', 'hyperlinks', 'off'));
        end
    end
end


function files = collectFiles(inputPath, maximumDepth, preferMRImCandidates)
    if isfile(inputPath)
        files = {inputPath};
        return;
    end

    if maximumDepth == 0
        listing = dir(fullfile(inputPath, '*'));
        listing = listing(~[listing.isdir]);
        files = fullfile({listing.folder}', {listing.name}');
    else
        files = recurseFolder(inputPath, 0, maximumDepth);
    end

    % For this dataset, DICOM files are named MRIm####. Restricting the
    % candidate list avoids calling dicominfo on existing NIfTI/log files.
    % If no MRIm files are found, fall back to all files for compatibility.
    if preferMRImCandidates && ~isempty(files)
        [~, names, extensions] = cellfun(@fileparts, files, ...
            'UniformOutput', false);
        fullNames = strcat(names, extensions);
        mriMask = startsWith(fullNames, 'MRIm', 'IgnoreCase', true);
        if any(mriMask)
            files = files(mriMask);
        end
    end
end


function files = recurseFolder(folderPath, currentDepth, maximumDepth)
    files = {};
    listing = dir(folderPath);

    for index = 1:numel(listing)
        item = listing(index);

        if item.isdir
            if strcmp(item.name, '.') || strcmp(item.name, '..')
                continue;
            end

            if currentDepth < maximumDepth
                subfolder = fullfile(folderPath, item.name);
                files = [files; recurseFolder( ...
                    subfolder, currentDepth + 1, maximumDepth)]; %#ok<AGROW>
            end
        else
            files{end+1, 1} = fullfile(folderPath, item.name); %#ok<AGROW>
        end
    end
end


function records = inspectDicomFiles(files, verbose, useParallel)
    emptyRecord = createEmptyDicomRecord();
    recordCells = cell(numel(files), 1);
    validMask = false(numel(files), 1);

    if useParallel
        parfor fileIndex = 1:numel(files)
            [recordCells{fileIndex}, validMask(fileIndex)] = ...
                inspectOneDicomFile(files{fileIndex}, emptyRecord);
        end
    else
        for fileIndex = 1:numel(files)
            [recordCells{fileIndex}, validMask(fileIndex)] = ...
                inspectOneDicomFile(files{fileIndex}, emptyRecord);

            if verbose && mod(fileIndex, 500) == 0
                fprintf('  Inspected %d/%d files...\n', ...
                    fileIndex, numel(files));
            end
        end
    end

    recordCells = recordCells(validMask);
    if isempty(recordCells)
        records = repmat(emptyRecord, 0, 1);
    else
        records = vertcat(recordCells{:});
    end
end


function emptyRecord = createEmptyDicomRecord()
    emptyRecord = struct( ...
        'Path', '', ...
        'Info', struct(), ...
        'GroupKey', '', ...
        'Rows', NaN, ...
        'Columns', NaN, ...
        'Frames', 1, ...
        'InstanceNumber', NaN, ...
        'AcquisitionNumber', NaN, ...
        'TemporalPosition', NaN, ...
        'SliceCoordinate', NaN, ...
        'EchoNumber', NaN);
end


function [record, isValid] = inspectOneDicomFile(path, emptyRecord)
    record = emptyRecord;
    isValid = false;

    try
        info = dicominfo(path);
    catch
        return;
    end

    record.Path = path;
    record.Info = info;

    seriesUID = getStringField(info, 'SeriesInstanceUID', '');
    seriesNumber = getNumericField(info, 'SeriesNumber', NaN);
    protocol = getStringField(info, 'ProtocolName', ...
        getStringField(info, 'SeriesDescription', 'UnknownSeries'));

    if isempty(seriesUID)
        seriesUID = sprintf('Series_%s_%s', ...
            numberToToken(seriesNumber), sanitizeFilename(protocol));
    end

    record.Rows = getNumericField(info, 'Rows', NaN);
    record.Columns = getNumericField(info, 'Columns', NaN);
    record.Frames = getNumericField(info, 'NumberOfFrames', 1);
    record.InstanceNumber = getNumericField(info, 'InstanceNumber', NaN);
    record.AcquisitionNumber = getNumericField(info, ...
        'AcquisitionNumber', NaN);
    record.TemporalPosition = getNumericField(info, ...
        'TemporalPositionIdentifier', NaN);
    record.EchoNumber = getNumericField(info, 'EchoNumber', ...
        getNumericField(info, 'EchoNumbers', NaN));
    record.SliceCoordinate = calculateSliceCoordinate(info);

    record.GroupKey = sprintf('%s|%gx%g|echo=%s', ...
        seriesUID, record.Rows, record.Columns, ...
        numberToToken(record.EchoNumber));
    isValid = true;
end


function groups = groupDicomRecords(records)
    keys = {records.GroupKey};
    [uniqueKeys, ~, keyIndices] = unique(keys, 'stable');

    groups = cell(numel(uniqueKeys), 1);

    for keyIndex = 1:numel(uniqueKeys)
        group = records(keyIndices == keyIndex);
        groups{keyIndex} = group;
    end
end


function [data, niftiInfo, warningMessages] = buildNiftiVolume(group, options)
    warningMessages = {};

    if any([group.Frames] > 1)
        [data, info] = readMultiFrameGroup(group, options.UseParallel);
    else
        [data, info, warningMessages] = readSingleFrameGroup( ...
            group, options.Output4D, warningMessages, options.UseParallel);
    end

    data = applyIntensityScaling(data, info);

    [pixelDimensions, transformMatrix, transformWarnings] = ...
        deriveSpatialMetadata(info, group);
    warningMessages = [warningMessages, transformWarnings];

    if options.ReorientToCanonical
        [data, transformMatrix, reorientWarnings] = ...
            reorientVolumeApproximate(data, transformMatrix);
        warningMessages = [warningMessages, reorientWarnings];
    end

    if options.RotateDegrees ~= 0
        [data, pixelDimensions, transformMatrix, rotationWarnings] = ...
            rotateVolume( ...
                data, pixelDimensions, transformMatrix, ...
                options.RotateDegrees);
        warningMessages = [warningMessages, rotationWarnings];
    end

    if options.DetectScanTime
        [timeSpacing, timeSource, timeWarning] = ...
            detectScanTime(info);
        if ~isempty(timeWarning)
            warningMessages{end+1} = timeWarning;
        end
    else
        timeSpacing = 1;
        timeSource = 'Default';
    end

    if ndims(data) >= 4
        if numel(pixelDimensions) < 4
            pixelDimensions(4) = timeSpacing;
        else
            pixelDimensions(4) = timeSpacing;
        end
    end

    niftiInfo = struct;
    niftiInfo.PixelDimensions = pixelDimensions;
    niftiInfo.TimeSpacing = timeSpacing;
    niftiInfo.TimeSource = timeSource;
    niftiInfo.Transform = affine3d(transformMatrix');
    niftiInfo.Description = buildDescription(info, options);
end


function [data, representativeInfo] = readMultiFrameGroup(group, useParallel)
    if numel(group) > 1
        warning('Multiple multi-frame DICOM files were detected in one group. They will be concatenated.');
    end

    chunks = cell(numel(group), 1);
    infoCells = {group.Info}';

    if useParallel && numel(infoCells) > 1
        parfor index = 1:numel(infoCells)
            chunks{index} = squeeze(dicomread(infoCells{index}));
        end
    else
        for index = 1:numel(infoCells)
            chunks{index} = squeeze(dicomread(infoCells{index}));
        end
    end

    if numel(chunks) == 1
        data = chunks{1};
    else
        sizes = cellfun(@size, chunks, 'UniformOutput', false);
        if all(cellfun(@(x) numel(x) >= 3, sizes))
            data = cat(4, chunks{:});
        else
            data = cat(3, chunks{:});
        end
    end

    representativeInfo = group(1).Info;
end


function [data, representativeInfo, warningMessages] = ...
    readSingleFrameGroup(group, output4D, warningMessages, useParallel)

    representativeInfo = group(1).Info;

    if ~output4D
        sortedGroup = sortSlices(group);
        data = readSliceStack(sortedGroup, useParallel);
        return;
    end

    [isFourDimensional, volumeGroups, detectionMessage] = ...
        detectVolumesFromSlices(group);

    if ~isempty(detectionMessage)
        warningMessages{end+1} = detectionMessage;
    end

    if ~isFourDimensional
        sortedGroup = sortSlices(group);
        data = readSliceStack(sortedGroup, useParallel);
        return;
    end

    numberOfVolumes = numel(volumeGroups);
    slicesPerVolume = numel(volumeGroups{1});
    orderedInfos = cell(slicesPerVolume * numberOfVolumes, 1);

    for volumeIndex = 1:numberOfVolumes
        currentGroup = sortSlices(volumeGroups{volumeIndex});
        if numel(currentGroup) ~= slicesPerVolume
            error('Detected time points do not have matching slice counts.');
        end

        offset = (volumeIndex - 1) * slicesPerVolume;
        orderedInfos(offset + (1:slicesPerVolume)) = {currentGroup.Info}';
    end

    slices = readDicomSliceInfos(orderedInfos, useParallel);
    firstSlice = slices{1};
    rows = size(firstSlice, 1);
    columns = size(firstSlice, 2);
    data = zeros(rows, columns, slicesPerVolume, numberOfVolumes, ...
        'like', firstSlice);

    for volumeIndex = 1:numberOfVolumes
        offset = (volumeIndex - 1) * slicesPerVolume;
        for sliceIndex = 1:slicesPerVolume
            slice = slices{offset + sliceIndex};
            if ~isequal(size(slice), [rows, columns])
                error(['Detected time points do not have matching dimensions. ' ...
                       'Volume %d, slice %d has size %s; expected [%d %d].'], ...
                       volumeIndex, sliceIndex, mat2str(size(slice)), ...
                       rows, columns);
            end
            data(:, :, sliceIndex, volumeIndex) = slice;
        end
    end
end


function [isFourDimensional, volumeGroups, message] = ...
    detectVolumesFromSlices(group)

    isFourDimensional = false;
    volumeGroups = {};
    message = '';

    numberOfImages = numel(group);
    if numberOfImages < 2
        return;
    end

    sliceCoordinates = [group.SliceCoordinate];
    finiteMask = isfinite(sliceCoordinates);

    if all(finiteMask)
        tolerance = 1e-4;
        roundedCoordinates = round(sliceCoordinates ./ tolerance) .* tolerance;
        uniquePositions = unique(roundedCoordinates, 'sorted');
        slicesPerVolume = numel(uniquePositions);

        if slicesPerVolume >= 2 && ...
                mod(numberOfImages, slicesPerVolume) == 0
            numberOfVolumes = numberOfImages / slicesPerVolume;

            if numberOfVolumes > 1
                volumeGroups = assignImagesToVolumes( ...
                    group, roundedCoordinates, uniquePositions, ...
                    slicesPerVolume, numberOfVolumes);

                if ~isempty(volumeGroups)
                    isFourDimensional = true;
                    message = sprintf( ...
                        ['Detected 4-D series from repeated slice positions: ' ...
                         '%d slices per volume x %d time points = %d images.'], ...
                        slicesPerVolume, numberOfVolumes, numberOfImages);
                    return;
                end
            end
        end
    end

    temporalValues = [group.TemporalPosition];
    finiteTemporal = unique(temporalValues(isfinite(temporalValues)));

    if numel(finiteTemporal) > 1
        candidateGroups = cell(numel(finiteTemporal), 1);
        counts = zeros(numel(finiteTemporal), 1);

        for index = 1:numel(finiteTemporal)
            candidateGroups{index} = ...
                group(temporalValues == finiteTemporal(index));
            counts(index) = numel(candidateGroups{index});
        end

        if all(counts == counts(1)) && counts(1) >= 2
            isFourDimensional = true;
            volumeGroups = candidateGroups;
            message = sprintf( ...
                ['Detected 4-D series from TemporalPositionIdentifier: ' ...
                 '%d slices per volume x %d time points.'], ...
                counts(1), numel(candidateGroups));
            return;
        end
    end

    acquisitionValues = [group.AcquisitionNumber];
    finiteAcquisitions = unique( ...
        acquisitionValues(isfinite(acquisitionValues)));

    if numel(finiteAcquisitions) > 1
        candidateGroups = cell(numel(finiteAcquisitions), 1);
        counts = zeros(numel(finiteAcquisitions), 1);

        for index = 1:numel(finiteAcquisitions)
            candidateGroups{index} = ...
                group(acquisitionValues == finiteAcquisitions(index));
            counts(index) = numel(candidateGroups{index});
        end

        if all(counts == counts(1)) && counts(1) >= 2
            isFourDimensional = true;
            volumeGroups = candidateGroups;
            message = sprintf( ...
                ['Detected 4-D series from AcquisitionNumber: ' ...
                 '%d slices per volume x %d time points.'], ...
                counts(1), numel(candidateGroups));
            return;
        end
    end

    message = sprintf( ...
        ['No valid repeated volume structure was detected. ' ...
         'The %d images were treated as one 3-D stack.'], ...
        numberOfImages);
end


function volumeGroups = assignImagesToVolumes( ...
    group, roundedCoordinates, uniquePositions, ...
    slicesPerVolume, numberOfVolumes)

    volumeGroups = {};
    perPosition = cell(slicesPerVolume, 1);

    for positionIndex = 1:slicesPerVolume
        mask = roundedCoordinates == uniquePositions(positionIndex);
        positionGroup = group(mask);

        if numel(positionGroup) ~= numberOfVolumes
            return;
        end

        positionGroup = sortRepeatedSliceInstances( ...
            positionGroup);
        perPosition{positionIndex} = positionGroup;
    end

    volumeGroups = cell(numberOfVolumes, 1);

    for volumeIndex = 1:numberOfVolumes
        currentVolume = repmat(group(1), slicesPerVolume, 1);

        for positionIndex = 1:slicesPerVolume
            currentVolume(positionIndex) = ...
                perPosition{positionIndex}(volumeIndex);
        end

        volumeGroups{volumeIndex} = currentVolume;
    end
end


function sortedGroup = ...
    sortRepeatedSliceInstances(group)

    temporalValues = [group.TemporalPosition];
    acquisitionValues = [group.AcquisitionNumber];
    instanceValues = [group.InstanceNumber];

    if all(isfinite(temporalValues)) && ...
            numel(unique(temporalValues)) == numel(group)
        [~, order] = sort(temporalValues, 'ascend');

    elseif all(isfinite(acquisitionValues)) && ...
            numel(unique(acquisitionValues)) == numel(group)
        [~, order] = sort(acquisitionValues, 'ascend');

    elseif all(isfinite(instanceValues))
        [~, order] = sort(instanceValues, 'ascend');

    else
        [~, order] = sort({group.Path});
    end

    sortedGroup = group(order);
end


function sortedGroup = sortSlices(group)
    sliceCoordinates = [group.SliceCoordinate];
    instanceNumbers = [group.InstanceNumber];

    if any(isfinite(sliceCoordinates))
        key = sliceCoordinates;
        missing = ~isfinite(key);
        key(missing) = max(key(~missing)) + (1:sum(missing));
        [~, order] = sort(key, 'ascend');
    elseif any(isfinite(instanceNumbers))
        key = instanceNumbers;
        missing = ~isfinite(key);
        key(missing) = max(key(~missing)) + (1:sum(missing));
        [~, order] = sort(key, 'ascend');
    else
        [~, order] = sort({group.Path});
    end

    sortedGroup = group(order);
end


function volume = readSliceStack(group, useParallel)
    infoCells = {group.Info}';
    slices = readDicomSliceInfos(infoCells, useParallel);
    firstSlice = slices{1};

    rows = size(firstSlice, 1);
    columns = size(firstSlice, 2);
    volume = zeros(rows, columns, numel(slices), 'like', firstSlice);

    for sliceIndex = 1:numel(slices)
        slice = slices{sliceIndex};
        if ~isequal(size(slice), [rows, columns])
            error('Inconsistent DICOM slice dimensions in one series.');
        end
        volume(:, :, sliceIndex) = slice;
    end
end


function slices = readDicomSliceInfos(infoCells, useParallel)
    slices = cell(numel(infoCells), 1);

    if useParallel && numel(infoCells) > 1
        parfor index = 1:numel(infoCells)
            slices{index} = readOneDicomSlice(infoCells{index});
        end
    else
        for index = 1:numel(infoCells)
            slices{index} = readOneDicomSlice(infoCells{index});
        end
    end
end


function slice = readOneDicomSlice(info)
    % Reuse the dicominfo structure collected during inspection so
    % dicomread does not need to parse each DICOM header a second time.
    slice = squeeze(dicomread(info));
    if ndims(slice) > 2
        error(['A single-frame group contains an image with more than two ' ...
               'dimensions. Mosaic/color DICOM is not supported by this path.']);
    end
end


function data = applyIntensityScaling(data, info)
    slope = getNumericField(info, 'RescaleSlope', 1);
    intercept = getNumericField(info, 'RescaleIntercept', 0);

    if slope ~= 1 || intercept ~= 0
        data = single(data) .* single(slope) + single(intercept);
    end
end


function [pixelDimensions, transformMatrix, warnings] = ...
    deriveSpatialMetadata(info, group)

    warnings = {};

    pixelSpacing = getVectorField(info, 'PixelSpacing', [1; 1]);
    if numel(pixelSpacing) < 2
        pixelSpacing = [1; 1];
        warnings{end+1} = 'PixelSpacing was missing; 1 mm was assumed.';
    end

    % DICOM PixelSpacing = [row spacing; column spacing].
    rowSpacing = double(pixelSpacing(1));
    columnSpacing = double(pixelSpacing(2));
    sliceSpacing = estimateSliceSpacing(info, group);
    pixelDimensions = [rowSpacing, columnSpacing, sliceSpacing];

    orientation = getVectorField(info, 'ImageOrientationPatient', []);

    if numel(orientation) ~= 6
        transformMatrix = diag([rowSpacing, columnSpacing, sliceSpacing, 1]);
        warnings{end+1} = ...
            ['ImageOrientationPatient was missing; an axis-aligned transform ' ...
             'was used and spatial orientation is not reliable.'];
        return;
    end

    % DICOM ImageOrientationPatient:
    %   first triplet  = direction of increasing image column
    %   second triplet = direction of increasing image row
    columnIndexDirection = double(orientation(1:3));
    rowIndexDirection = double(orientation(4:6));

    columnIndexDirection = ...
        columnIndexDirection ./ norm(columnIndexDirection);
    rowIndexDirection = rowIndexDirection ./ norm(rowIndexDirection);

    if abs(dot(columnIndexDirection, rowIndexDirection)) > 1e-4
        warnings{end+1} = ...
            'ImageOrientationPatient vectors were not exactly orthogonal.';
        rowIndexDirection = rowIndexDirection - ...
            dot(rowIndexDirection, columnIndexDirection) .* ...
            columnIndexDirection;
        rowIndexDirection = rowIndexDirection ./ norm(rowIndexDirection);
    end

    sliceDirection = cross(columnIndexDirection, rowIndexDirection);
    sliceDirection = sliceDirection ./ norm(sliceDirection);

    % The volume is stored in ascending SliceCoordinate order. Therefore,
    % use the position of the first stored slice as the affine origin.
    sliceCoordinates = [group.SliceCoordinate];
    finiteIndices = find(isfinite(sliceCoordinates));

    if ~isempty(finiteIndices)
        [~, localFirst] = min(sliceCoordinates(finiteIndices));
        firstRecordIndex = finiteIndices(localFirst);
        positionLPS = getVectorField( ...
            group(firstRecordIndex).Info, 'ImagePositionPatient', []);
    else
        positionLPS = getVectorField(info, 'ImagePositionPatient', []);
    end

    if numel(positionLPS) < 3
        positionLPS = [0; 0; 0];
        warnings{end+1} = ...
            'ImagePositionPatient was missing; a zero origin was assumed.';
    end

    % Affine for MATLAB/NIfTI array order: row, column, slice.
    affineLPS = eye(4);
    affineLPS(1:3, 1) = rowIndexDirection(:) .* rowSpacing;
    affineLPS(1:3, 2) = columnIndexDirection(:) .* columnSpacing;
    affineLPS(1:3, 3) = sliceDirection(:) .* sliceSpacing;
    affineLPS(1:3, 4) = double(positionLPS(1:3));

    % DICOM patient coordinates are LPS; NIfTI scanner coordinates are RAS.
    lpsToRas = diag([-1, -1, 1, 1]);
    transformMatrix = lpsToRas * affineLPS;
end


function spacing = estimateSliceSpacing(info, group)
    sliceCoordinates = sort([group.SliceCoordinate]);
    sliceCoordinates = sliceCoordinates(isfinite(sliceCoordinates));

    if numel(sliceCoordinates) >= 2
        differences = abs(diff(sliceCoordinates));
        differences = differences(differences > eps);
        if ~isempty(differences)
            spacing = median(differences);
            return;
        end
    end

    spacing = getNumericField(info, 'SpacingBetweenSlices', NaN);
    if ~isfinite(spacing)
        spacing = getNumericField(info, 'SliceThickness', 1);
    end
end


function [data, transformMatrix, warnings] = ...
    reorientVolumeApproximate(data, transformMatrix)

    warnings = {};

    rotationScaling = transformMatrix(1:3, 1:3);
    axisVectors = rotationScaling ./ vecnorm(rotationScaling);

    [~, dominantAxes] = max(abs(axisVectors), [], 1);

    if numel(unique(dominantAxes)) ~= 3
        warnings{end+1} = ...
            'Canonical reorientation was skipped because the orientation is strongly oblique.';
        return;
    end

    permutation = zeros(1, 3);
    for worldAxis = 1:3
        permutation(worldAxis) = find(dominantAxes == worldAxis, 1);
    end

    dimensions = ndims(data);
    fullPermutation = [permutation, 4:dimensions];

    % Exact index mapping for the permutation.
    C = eye(4);
    C(1:3, 1:3) = 0;
    for newAxis = 1:3
        oldAxis = permutation(newAxis);
        C(oldAxis, newAxis) = 1;
    end

    data = permute(data, fullPermutation);
    transformMatrix = transformMatrix * C;
    newSize = size(data);

    for axisIndex = 1:3
        vector = transformMatrix(1:3, axisIndex);
        [~, worldAxis] = max(abs(vector));

        if vector(worldAxis) < 0
            data = flip(data, axisIndex);

            % Flipping changes the world coordinate of voxel (0,0,0).
            transformMatrix(1:3, 4) = ...
                transformMatrix(1:3, 4) + ...
                vector .* (newSize(axisIndex) - 1);
            transformMatrix(1:3, axisIndex) = -vector;

            warnings{end+1} = sprintf( ...
                'Data were flipped along MATLAB dimension %d during approximate reorientation.', ...
                axisIndex);
        end
    end

    warnings{end+1} = ...
        ['Approximate canonical reorientation was applied with an exact ' ...
         'index-to-world affine update. Verify strongly oblique acquisitions.'];
end


function [timeSpacing, sourceName, warningMessage] = ...
    detectScanTime(info)
    % Return temporal spacing in seconds.
    %
    % DICOM RepetitionTime and FrameTime are normally stored in
    % milliseconds. TemporalResolution may be stored in milliseconds by
    % many MR systems, so values greater than 20 are interpreted as ms.

    timeSpacing = 1;
    sourceName = 'Default';
    warningMessage = '';

    repetitionTime = getNumericField( ...
        info, 'RepetitionTime', NaN);
    if isfinite(repetitionTime) && repetitionTime > 0
        timeSpacing = repetitionTime / 1000;
        sourceName = 'RepetitionTime';
        return;
    end

    temporalResolution = getNumericField( ...
        info, 'TemporalResolution', NaN);
    if isfinite(temporalResolution) && temporalResolution > 0
        if temporalResolution > 20
            timeSpacing = temporalResolution / 1000;
        else
            timeSpacing = temporalResolution;
        end
        sourceName = 'TemporalResolution';
        return;
    end

    frameTime = getNumericField(info, 'FrameTime', NaN);
    if isfinite(frameTime) && frameTime > 0
        timeSpacing = frameTime / 1000;
        sourceName = 'FrameTime';
        return;
    end

    warningMessage = ...
        'No DICOM scan-time field was found; 1 second was used.';
end


function [data, pixelDimensions, transformMatrix, warnings] = ...
    rotateVolume( ...
        data, pixelDimensions, transformMatrix, rotateDegrees)

    warnings = {};
    oldSize = size(data);
    oldTransform = transformMatrix;

    % C maps zero-based indices in the rotated array back to indices in
    % the original array. The exact updated affine is A_new = A_old * C.
    switch double(rotateDegrees)
        case 0
            return;

        case 90
            % Clockwise:
            % oldRow = (nRows - 1) - newColumn
            % oldCol = newRow
            k = -1;
            C = [0, -1, 0, oldSize(1) - 1; ...
                 1,  0, 0, 0; ...
                 0,  0, 1, 0; ...
                 0,  0, 0, 1];

        case 180
            k = 2;
            C = [-1,  0, 0, oldSize(1) - 1; ...
                  0, -1, 0, oldSize(2) - 1; ...
                  0,  0, 1, 0; ...
                  0,  0, 0, 1];

        case 270
            % 270 degrees clockwise = 90 degrees counter-clockwise.
            % oldRow = newColumn
            % oldCol = (nColumns - 1) - newRow
            k = 1;
            C = [ 0, 1, 0, 0; ...
                 -1, 0, 0, oldSize(2) - 1; ...
                  0, 0, 1, 0; ...
                  0, 0, 0, 1];

        otherwise
            error('Unsupported rotation angle: %g', rotateDegrees);
    end

    data = rot90(data, k);
    transformMatrix = oldTransform * C;

    if ismember(double(rotateDegrees), [90 270])
        pixelDimensions([1 2]) = pixelDimensions([2 1]);
    end

    warnings{end+1} = sprintf( ...
        'Manual in-plane rotation of %d degrees clockwise was applied.', ...
        rotateDegrees);
    warnings{end+1} = sprintf( ...
        'Rotated volume size: %s.', mat2str(size(data)));
end


function filename = buildOutputFilename(group, options)
    info = group(1).Info;
    tokens = {};

    if options.AppendDate
        studyDate = getStringField(info, 'StudyDate', '');
        studyTime = getStringField(info, 'StudyTime', '');
        studyTime = regexprep(studyTime, '\..*$', '');

        if ~isempty(studyDate)
            tokens{end+1} = sanitizeFilename([studyDate '_' studyTime]); %#ok<AGROW>
        end
    end

    if options.AppendSeries
        seriesNumber = getNumericField(info, 'SeriesNumber', NaN);
        acquisitionNumber = getNumericField(info, 'AcquisitionNumber', NaN);

        if isfinite(seriesNumber)
            tokens{end+1} = sprintf('s%03d', round(seriesNumber)); %#ok<AGROW>
        end

        if isfinite(acquisitionNumber)
            tokens{end+1} = sprintf('a%03d', round(acquisitionNumber)); %#ok<AGROW>
        end
    end

    if options.AppendProtocolName
        protocol = getStringField(info, 'ProtocolName', ...
            getStringField(info, 'SeriesDescription', ''));

        if ~isempty(protocol)
            tokens{end+1} = sanitizeFilename(protocol); %#ok<AGROW>
        end
    end

    if options.AppendPatientName
        patientName = patientNameToString(info);
        if ~isempty(patientName)
            tokens{end+1} = sanitizeFilename(patientName); %#ok<AGROW>
        end
    end

    if options.AppendSourceName
        [~, sourceName] = fileparts(group(1).Path);
        tokens{end+1} = sanitizeFilename(sourceName); %#ok<AGROW>
    end

    if isempty(tokens)
        seriesUID = getStringField(info, 'SeriesInstanceUID', 'DICOM_series');
        tokens = {sanitizeFilename(seriesUID)};
    end

    filename = strjoin(tokens, '_');
    filename = regexprep(filename, '_+', '_');
    filename = regexprep(filename, '^_|_$', '');

    if isempty(filename)
        filename = 'DICOM_series';
    end
end


function writeNiftiFile(data, outputBase, niftiInfo, useGzip)
% Write voxel data once, then patch the compact NIfTI-1 header in place.
%
% The previous implementation wrote a full temporary NIfTI, read its
% metadata, and wrote the complete data a second time. This version avoids
% that duplicate disk write while preserving the same voxel array and
% scanner-space qform/sform.

    outputNii = [outputBase '.nii'];
    outputGz = [outputNii '.gz'];

    cleanupFiles = {outputNii, outputGz};
    for fileIndex = 1:numel(cleanupFiles)
        if isfile(cleanupFiles{fileIndex})
            delete(cleanupFiles{fileIndex});
        end
    end

    niftiwrite(data, outputNii);
    if ~isfile(outputNii)
        error('No NIfTI output file was created.');
    end

    try
        desiredPixelDimensions = double(niftiInfo.PixelDimensions(:)');
        if isfield(niftiInfo, 'TimeSpacing') && ...
                isfinite(niftiInfo.TimeSpacing) && ...
                niftiInfo.TimeSpacing > 0
            timeSpacing = double(niftiInfo.TimeSpacing);
        else
            timeSpacing = NaN;
        end

        description = '';
        if isfield(niftiInfo, 'Description')
            description = char(niftiInfo.Description);
        end

        epi0.patchNiftiCoreMetadata(outputNii, desiredPixelDimensions, ...
            timeSpacing, description);

        if isfield(niftiInfo, 'Transform') && ...
                isa(niftiInfo.Transform, 'affine3d')
            affineMatrix = double(niftiInfo.Transform.T');
            epi0.patchNiftiSpatialTransform(outputNii, affineMatrix);
        end
    catch ME
        if isfile(outputNii)
            delete(outputNii);
        end
        rethrow(ME);
    end

    if useGzip
        gzip(outputNii);

        if isfile(outputGz)
            delete(outputNii);
        else
            warning(['Compression failed. The uncompressed NIfTI was kept: %s'], ...
                outputNii);
        end
    end
end


function description = buildDescription(info, options)
    description = getStringField(info, 'SeriesDescription', ...
        getStringField(info, 'ProtocolName', 'Converted DICOM series'));

    if options.Anonymize
        description = sprintf('%s | anonymized metadata', description);
    end
end


function coordinate = calculateSliceCoordinate(info)
    orientation = getVectorField(info, 'ImageOrientationPatient', []);
    position = getVectorField(info, 'ImagePositionPatient', []);

    if numel(orientation) == 6 && numel(position) >= 3
        normal = cross(double(orientation(1:3)), double(orientation(4:6)));
        coordinate = dot(normal, double(position(1:3)));
    else
        coordinate = getNumericField(info, 'SliceLocation', NaN);
    end
end


function value = getStringField(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        raw = structure.(fieldName);

        if ischar(raw)
            value = strtrim(raw);
        elseif isstring(raw)
            value = strtrim(char(raw));
        elseif isnumeric(raw)
            value = num2str(raw);
        else
            value = defaultValue;
        end
    else
        value = defaultValue;
    end
end


function value = getNumericField(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        raw = structure.(fieldName);

        if isnumeric(raw) && ~isempty(raw)
            value = double(raw(1));
        elseif ischar(raw) || isstring(raw)
            parsed = str2double(raw);
            if isfinite(parsed)
                value = parsed;
            else
                value = defaultValue;
            end
        else
            value = defaultValue;
        end
    else
        value = defaultValue;
    end
end


function value = getVectorField(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        raw = structure.(fieldName);

        if isnumeric(raw)
            value = double(raw(:));
        elseif ischar(raw) || isstring(raw)
            parsed = sscanf(char(raw), '%f\%f\%f\%f\%f\%f');
            if isempty(parsed)
                value = defaultValue;
            else
                value = parsed(:);
            end
        else
            value = defaultValue;
        end
    else
        value = defaultValue;
    end
end


function token = numberToToken(value)
    if isfinite(value)
        token = sprintf('%g', value);
    else
        token = 'NA';
    end
end


function name = sanitizeFilename(name)
    name = char(name);
    name = strtrim(name);
    name = regexprep(name, '[^\w\-]+', '_');
    name = regexprep(name, '_+', '_');
    name = regexprep(name, '^_|_$', '');

    if isempty(name)
        name = 'unnamed';
    end
end


function patientName = patientNameToString(info)
    patientName = '';

    if ~isfield(info, 'PatientName')
        return;
    end

    raw = info.PatientName;

    if ischar(raw) || isstring(raw)
        patientName = char(raw);
    elseif isstruct(raw)
        components = {'FamilyName', 'GivenName', 'MiddleName', ...
            'NamePrefix', 'NameSuffix'};
        tokens = {};

        for index = 1:numel(components)
            field = components{index};
            if isfield(raw, field) && ~isempty(raw.(field))
                tokens{end+1} = char(raw.(field)); %#ok<AGROW>
            end
        end

        patientName = strjoin(tokens, '_');
    end
end
