function [report, stats] = runStep6MoveFiles( ...
    assignments, report, destinationSuffixes)
%RUNSTEP6MOVEFILES 依固定 E 順序移動 EPI0.nii。
%
% 目的地已有 EPI0.nii 時，完全跳過該槽位，不覆蓋，也不剪下來源。

    fprintf('\n============================================================\n');
    fprintf('步驟 6/6：依完整 E 編號順序檢查並移動 EPI0.nii\n');
    fprintf('============================================================\n');

    stats = struct;
    stats.MovedCount = 0;
    stats.DestinationOccupiedCount = 0;
    stats.MissingSourceCount = 0;
    stats.ExtraSourceCount = 0;

    for assignmentIndex = 1:numel(assignments)
        assignment = assignments(assignmentIndex);

        reportIndex = epi0.findReportIndex( ...
            report, assignment.SourcePath);

        sourceFile = fullfile( ...
            assignment.SourcePath, 'EPI0.nii');

        if assignment.SlotIndex > numel(destinationSuffixes) || ...
                isempty(assignment.DestinationFile)

            if isfile(sourceFile)
                stats.ExtraSourceCount = ...
                    stats.ExtraSourceCount + 1;

                report(reportIndex).Step6Status = ...
                    'Extra source retained: no destination slot';

                report(reportIndex).Status = ...
                    'Extra EPI0 left in source folder';

                report(reportIndex).Message = epi0.appendMessage( ...
                    report(reportIndex).Message, ...
                    ['More than five EPI source folders existed ' ...
                     'for this group-animal ID.']);
            else
                report(reportIndex).Step6Status = ...
                    'No destination slot and no source EPI0';
            end

            continue;
        end

        destinationFolder = assignment.DestinationFolder;
        destinationFile = assignment.DestinationFile;

        if ~isfolder(destinationFolder)
            mkdir(destinationFolder);
        end

        if isfile(destinationFile)
            stats.DestinationOccupiedCount = ...
                stats.DestinationOccupiedCount + 1;

            report(reportIndex).MovedTo = destinationFile;
            report(reportIndex).Step6Status = ...
                'Skipped: destination EPI0 already exists';
            report(reportIndex).Status = ...
                'Move skipped: destination already completed';

            if isfile(sourceFile)
                report(reportIndex).Message = epi0.appendMessage( ...
                    report(reportIndex).Message, ...
                    ['Destination already contained EPI0.nii; ' ...
                     'source EPI0.nii was deliberately left in place.']);

                fprintf(['  [跳過] %s 已有 EPI0.nii；' ...
                         '來源檔保留、不剪下、不覆蓋。\n'], ...
                    destinationFolder);
            else
                fprintf('  [已完成] %s 已有 EPI0.nii。\n', ...
                    destinationFolder);
            end

            continue;
        end

        if ~isfile(sourceFile)
            stats.MissingSourceCount = ...
                stats.MissingSourceCount + 1;

            report(reportIndex).Step6Status = ...
                'Skipped: source EPI0 not available';
            report(reportIndex).Status = ...
                'Destination left empty';

            fprintf(['  [留空] E%d 的來源資料夾目前沒有 ' ...
                     'EPI0.nii：%s\n'], ...
                assignment.EOrder, assignment.SourcePath);

            continue;
        end

        movefile(sourceFile, destinationFile);

        stats.MovedCount = stats.MovedCount + 1;
        report(reportIndex).MovedTo = destinationFile;
        report(reportIndex).Step6Status = ...
            'Moved to assigned destination';
        report(reportIndex).Status = ...
            'Moved to destination';

        fprintf('  E%d -> %s\n', ...
            assignment.EOrder, destinationFile);
    end
end
