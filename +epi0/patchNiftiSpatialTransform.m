function patchNiftiSpatialTransform(filename, affineMatrix)
    % Write matching scanner-anatomical qform and sform fields.
    %
    % affineMatrix uses the NIfTI premultiply convention:
    %   [x; y; z; 1] = affineMatrix * [i; j; k; 1]
    % where i, j, k are zero-based voxel indices.

    validateattributes(affineMatrix, {'numeric'}, ...
        {'size', [4 4], 'finite', 'nonsparse'});

    linearPart = double(affineMatrix(1:3, 1:3));
    voxelSizes = vecnorm(linearPart, 2, 1);

    if any(~isfinite(voxelSizes)) || any(voxelSizes <= 0)
        error('The affine contains an invalid voxel-axis scale.');
    end

    rotation = linearPart ./ voxelSizes;

    % qform cannot represent shear. DICOM orientation should be orthogonal.
    orthogonalityError = norm(rotation' * rotation - eye(3), 'fro');
    if orthogonalityError > 1e-4
        error(['The affine contains shear or nonorthogonal axes ' ...
               '(orthogonality error %.6g); qform cannot represent it.'], ...
               orthogonalityError);
    end

    % Make the quaternion rotation proper; encode handedness in qfac.
    qfac = 1;
    if det(rotation) < 0
        rotation(:, 3) = -rotation(:, 3);
        qfac = -1;
    end

    [~, quaternionB, quaternionC, quaternionD] = ...
        epi0.rotationMatrixToNiftiQuaternion(rotation);

    fid = fopen(filename, 'r+', 'ieee-le');
    if fid < 0
        error('Could not open NIfTI header for spatial patching: %s', ...
            filename);
    end

    cleanupObject = onCleanup(@() fclose(fid));

    fseek(fid, 0, 'bof');
    headerSize = fread(fid, 1, 'int32');
    if headerSize ~= 348
        error('Unexpected NIfTI-1 header size: %g.', headerSize);
    end

    % pixdim[0] = qfac; pixdim[1:3] = spatial voxel sizes.
    % Do not overwrite pixdim[4], which stores temporal spacing.
    fseek(fid, 76, 'bof');
    fwrite(fid, single(qfac), 'single');
    fseek(fid, 80, 'bof');
    fwrite(fid, single(voxelSizes), 'single');

    % qform_code = 1 and sform_code = 1:
    % NIFTI_XFORM_SCANNER_ANAT.
    fseek(fid, 252, 'bof');
    fwrite(fid, int16([1, 1]), 'int16');

    % Quaternion b, c, d.
    fseek(fid, 256, 'bof');
    fwrite(fid, single([quaternionB, quaternionC, quaternionD]), 'single');

    % qoffset_x, qoffset_y, qoffset_z.
    fseek(fid, 268, 'bof');
    fwrite(fid, single(affineMatrix(1:3, 4)), 'single');

    % srow_x, srow_y, srow_z.
    fseek(fid, 280, 'bof');
    fwrite(fid, single(affineMatrix(1, :)), 'single');
    fwrite(fid, single(affineMatrix(2, :)), 'single');
    fwrite(fid, single(affineMatrix(3, :)), 'single');

    clear cleanupObject;
end
