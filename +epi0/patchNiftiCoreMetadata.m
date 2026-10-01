function patchNiftiCoreMetadata(filename, pixelDimensions, ...
    timeSpacing, description)
% Patch pixdim, units and optional description in a little-endian NIfTI-1.

    fid = fopen(filename, 'r+', 'ieee-le');
    if fid < 0
        error('Could not open NIfTI header for metadata patching: %s', ...
            filename);
    end
    cleanupObject = onCleanup(@() fclose(fid));

    fseek(fid, 0, 'bof');
    headerSize = fread(fid, 1, 'int32');
    if headerSize ~= 348
        error('Unexpected NIfTI-1 header size: %g.', headerSize);
    end

    spatialDimensions = ones(1, 3);
    copyCount = min(3, numel(pixelDimensions));
    spatialDimensions(1:copyCount) = ...
        double(pixelDimensions(1:copyCount));

    fseek(fid, 80, 'bof');
    fwrite(fid, single(spatialDimensions), 'single');

    if isfinite(timeSpacing) && timeSpacing > 0
        fseek(fid, 92, 'bof');
        fwrite(fid, single(timeSpacing), 'single');
    end

    % Spatial units millimetres (2), temporal units seconds (8).
    fseek(fid, 123, 'bof');
    fwrite(fid, uint8(10), 'uint8');

    if nargin >= 4 && ~isempty(description)
        descriptionBytes = uint8(unicode2native(char(description), 'UTF-8'));
        descriptionBytes = descriptionBytes(1:min(79, numel(descriptionBytes)));
        fieldBytes = zeros(1, 80, 'uint8');
        fieldBytes(1:numel(descriptionBytes)) = descriptionBytes;
        fseek(fid, 148, 'bof');
        fwrite(fid, fieldBytes, 'uint8');
    end

    clear cleanupObject;
end
