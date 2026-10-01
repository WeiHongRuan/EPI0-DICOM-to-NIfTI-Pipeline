function [report, stats] = runStep1Delete( ...
    processingFolders, assignments, report, config)
%RUNSTEP1DELETE 步驟 1：檢查並刪除 MRIm0001~MRIm1500。

    fprintf('\n============================================================\n');
    fprintf('步驟 1/6：檢查並刪除前 1500 筆 MRI 檔案\n');
    fprintf('============================================================\n');

    stats = struct;
    stats.AlreadySkippedCount = 0;
    stats.DeletedFolderCount = 0;

    for index = 1:numel(processingFolders)
        folderPath = processingFolders(index).Path;
        reportIndex = epi0.findReportIndex(report, folderPath);

        assignmentIndex = epi0.findAssignmentIndex( ...
            assignments, folderPath);

        destinationFile = '';

        if ~isempty(assignmentIndex)
            destinationFile = ...
                assignments(assignmentIndex).DestinationFile;
        end

        fprintf('[%d/%d] %s\n', ...
            index, numel(processingFolders), folderPath);

        if ~isempty(destinationFile) && isfile(destinationFile)
            report(reportIndex).Step1Status = ...
                'Skipped: destination EPI0 already exists';
            report(reportIndex).Status = ...
                'Already completed in destination';

            stats.AlreadySkippedCount = ...
                stats.AlreadySkippedCount + 1;

            fprintf(['  目的地已有 EPI0.nii，視為此來源已完成；' ...
                     '跳過刪除。\n']);
            continue;
        end

        try
            mriState = epi0.inspectMRIIndexState(folderPath, ...
                config.DeleteFirstIndex, config.DeleteLastIndex);

            if mriState.EarlyFileCount == 0
                report(reportIndex).Step1Status = ...
                    'Skipped: first 1500 MRI files already absent';
                report(reportIndex).Status = ...
                    'Step 1 already completed or not needed';

                stats.AlreadySkippedCount = ...
                    stats.AlreadySkippedCount + 1;

                fprintf('  MRIm0001*~MRIm1500* 已不存在，跳過刪除。\n');

            elseif mriState.DirectFileCount > ...
                    config.LargeFolderThreshold

                deletedCount = epi0.deleteIndexedMRIData( ...
                    folderPath, config.DeleteFirstIndex, ...
                    config.DeleteLastIndex);

                report(reportIndex).DeletedCount = deletedCount;
                report(reportIndex).Step1Status = sprintf( ...
                    'Deleted %d early MRI files', deletedCount);
                report(reportIndex).Status = 'Step 1 completed';

                stats.DeletedFolderCount = ...
                    stats.DeletedFolderCount + 1;

                fprintf('  已刪除 %d 個檔案。\n', deletedCount);

            else
                report(reportIndex).Step1Status = ...
                    ['Skipped for safety: early files remain ' ...
                     'but count <= threshold'];

                report(reportIndex).Status = ...
                    'Step 1 not safely completed';

                report(reportIndex).Message = epi0.appendMessage( ...
                    report(reportIndex).Message, sprintf( ...
                    ['仍找到 %d 個 MRIm0001~MRIm1500 檔案，' ...
                     '但目前直接檔案數只有 %d（未超過 %d），' ...
                     '因此不自動刪除。'], ...
                    mriState.EarlyFileCount, ...
                    mriState.DirectFileCount, ...
                    config.LargeFolderThreshold));

                warning(['仍有前 1500 筆檔案，但資料夾目前未超過門檻；' ...
                         '為安全起見跳過刪除：\n%s'], folderPath);
            end

        catch ME
            report(reportIndex).Step1Status = ...
                'Delete check failed';
            report(reportIndex).Status = 'Delete failed';

            report(reportIndex).Message = epi0.appendMessage( ...
                report(reportIndex).Message, ME.message);

            warning('刪除檢查失敗：%s\n%s', ...
                folderPath, ME.message);
        end
    end
end
