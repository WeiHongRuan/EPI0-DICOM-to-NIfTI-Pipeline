function [report, stats] = runSteps2To4Convert( ...
    processingFolders, assignments, report, config)
%RUNSTEPS2TO4CONVERT 續做 DICOM 轉檔、尺度乘 10、改名 EPI0.nii。

    fprintf('\n============================================================\n');
    fprintf('步驟 2-4/6：續做轉檔、空間尺度乘以 10、改名 EPI0.nii\n');
    fprintf('============================================================\n');

    conversionOptions = createConversionOptions(config);

    stats = struct;
    stats.SkippedCount = 0;

    for index = 1:numel(processingFolders)
        folderPath = processingFolders(index).Path;
        reportIndex = epi0.findReportIndex(report, folderPath);
        epi0Path = fullfile(folderPath, 'EPI0.nii');

        assignmentIndex = epi0.findAssignmentIndex( ...
            assignments, folderPath);

        destinationFile = '';

        if ~isempty(assignmentIndex)
            destinationFile = ...
                assignments(assignmentIndex).DestinationFile;
        end

        fprintf('\n[%d/%d] 處理：%s\n', ...
            index, numel(processingFolders), folderPath);

        try
            if ~isempty(destinationFile) && isfile(destinationFile)
                report(reportIndex).Step2To4Status = ...
                    ['Skipped: assigned destination already ' ...
                     'contains EPI0'];

                report(reportIndex).Status = ...
                    'Already completed in destination';

                stats.SkippedCount = stats.SkippedCount + 1;

                fprintf(['  指定的目的子資料夾已存在 EPI0.nii，' ...
                         '跳過轉檔、放大與改名。\n']);
                continue;
            end

            if isfile(epi0Path)
                report(reportIndex).EPI0Created = epi0Path;
                report(reportIndex).Step2To4Status = ...
                    'Skipped: source EPI0 already exists';
                report(reportIndex).Status = ...
                    'Existing source EPI0 retained';

                stats.SkippedCount = stats.SkippedCount + 1;

                fprintf('  原資料夾已存在 EPI0.nii，跳過重複處理。\n');
                continue;
            end

            existingX = epi0.listValidXFiles(folderPath);

            if numel(existingX) == 1
                existingXPath = fullfile( ...
                    existingX(1).folder, existingX(1).name);

                movefile(existingXPath, epi0Path);

                report(reportIndex).ScaledFile = existingXPath;
                report(reportIndex).EPI0Created = epi0Path;
                report(reportIndex).Step2To4Status = ...
                    'Resumed: existing X renamed to EPI0';
                report(reportIndex).Status = ...
                    'Existing X renamed to EPI0';

                fprintf(['  找到既有 *X.nii，' ...
                         '已直接改名為 EPI0.nii。\n']);
                continue;

            elseif numel(existingX) > 1
                error(['同一資料夾中有多個 *X.nii，無法安全判斷' ...
                       '哪一個應改名。請先人工確認。']);
            end

            existingConverted = ...
                epi0.listUnscaledConvertedNiftiFiles(folderPath);

            if numel(existingConverted) == 1
                convertedFile = fullfile( ...
                    existingConverted(1).folder, ...
                    existingConverted(1).name);

                report(reportIndex).ConvertedFile = convertedFile;

                scaledFile = epi0.scaleNiftiSpaceByFactor( ...
                    convertedFile, config.ScaleFactor);

                report(reportIndex).ScaledFile = scaledFile;

                movefile(scaledFile, epi0Path);

                report(reportIndex).EPI0Created = epi0Path;
                report(reportIndex).Step2To4Status = ...
                    'Resumed: existing NIfTI scaled and renamed';
                report(reportIndex).Status = ...
                    'EPI0 created from existing NIfTI';

                fprintf(['  找到既有轉檔結果，已續做放大與改名：' ...
                         '%s\n'], epi0Path);
                continue;

            elseif numel(existingConverted) > 1
                generatedNames = strjoin( ...
                    {existingConverted.name}, ' | ');

                error(['同一資料夾中有多個未放大的 .nii，' ...
                       '無法安全選擇：%s'], generatedNames);
            end

            mriState = epi0.inspectMRIIndexState(folderPath, ...
                config.DeleteFirstIndex, config.DeleteLastIndex);

            if mriState.EarlyFileCount > 0
                error(['仍有 %d 個 MRIm0001*~MRIm1500* 檔案。' ...
                       '為避免把應刪除的前段資料一起轉檔，' ...
                       '本資料夾停止於此。'], ...
                       mriState.EarlyFileCount);
            end

            conversionResults = epi0.convertDicomFolder( ...
                folderPath, folderPath, conversionOptions);

            successfulMask = arrayfun(@(x) ...
                ~isempty(x.OutputFile) && isfile(x.OutputFile), ...
                conversionResults);

            successfulResults = ...
                conversionResults(successfulMask);

            if isempty(successfulResults)
                error('沒有成功產生任何 NIfTI 檔案。');
            end

            if numel(successfulResults) ~= 1
                generatedNames = strjoin( ...
                    {successfulResults.OutputFile}, ' | ');

                error(['此資料夾產生了 %d 個 NIfTI 檔案。' ...
                       '為避免錯誤覆蓋，程式不會自動挑選：%s'], ...
                       numel(successfulResults), generatedNames);
            end

            convertedFile = successfulResults(1).OutputFile;
            report(reportIndex).ConvertedFile = convertedFile;

            scaledFile = epi0.scaleNiftiSpaceByFactor( ...
                convertedFile, config.ScaleFactor);

            report(reportIndex).ScaledFile = scaledFile;

            if isfile(epi0Path)
                error('EPI0.nii 已存在，程式拒絕覆蓋：%s', ...
                    epi0Path);
            end

            movefile(scaledFile, epi0Path);

            report(reportIndex).EPI0Created = epi0Path;
            report(reportIndex).Step2To4Status = ...
                'Completed from DICOM';
            report(reportIndex).Status = 'EPI0 created';

            fprintf('  完成：%s\n', epi0Path);

        catch ME
            report(reportIndex).Step2To4Status = ...
                'Conversion pipeline failed';
            report(reportIndex).Status = ...
                'Conversion pipeline failed';

            report(reportIndex).Message = epi0.appendMessage( ...
                report(reportIndex).Message, ME.message);

            warning('資料夾處理失敗：%s\n%s', ...
                folderPath, ME.message);
        end
    end
end


function options = createConversionOptions(config)
    options = struct;

    options.RecursiveFolderDepth = 0;
    options.Anonymize = true;
    options.Gzip = false;
    options.Output4D = true;
    options.AppendDate = true;
    options.AppendSeries = true;
    options.AppendProtocolName = true;
    options.AppendPatientName = false;
    options.AppendSourceName = false;
    options.ReorientToCanonical = false;
    options.RotateDegrees = 90;
    options.DetectScanTime = true;

    options.UseParallel = config.UseParallel;
    options.MaxParallelWorkers = config.MaxParallelWorkers;
    options.MinimumFilesForParallel = ...
        config.MinimumFilesForParallel;
    options.PreferMRImCandidates = ...
        config.PreferMRImCandidates;
    options.Verbose = config.Verbose;
end
