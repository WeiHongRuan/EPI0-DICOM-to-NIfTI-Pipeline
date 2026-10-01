function report = run_EPI0_pipeline()
%RUN_EPI0_PIPELINE Modular, resumable EPI0 preparation pipeline.
% Dataset-specific workflow for DICOM cleanup, DICOM-to-NIfTI conversion,
% spatial metadata scaling, EPI0 naming, and destination organization.
%
% WARNING: This workflow can delete and move files. Test on a data copy first.
%
% 使用方式：
%   report = run_EPI0_pipeline;
%
% 請將本檔案與 +epi0 資料夾放在同一層，然後執行本程式。
%
% 各步驟已拆到 +epi0 套件資料夾：
%   Step 1      epi0.runStep1Delete
%   Steps 2-4   epi0.runSteps2To4Convert
%   Step 5      epi0.runStep5CreateDestinations
%   Step 6      epi0.runStep6MoveFiles
%
% 已完成步驟會自動跳過；目的地已有 EPI0.nii 時不覆蓋，
% 也不會從來源剪下另一份檔案。

    clc;
    pipelineTimer = tic;

    config = epi0.defaultConfig();
    destinationSuffixes = config.DestinationSuffixes;

    mainFolder = uigetdir(pwd, '請選擇要處理的最上層大資料夾');

    if isequal(mainFolder, 0)
        fprintf('已取消操作。\n');
        report = struct([]);
        return;
    end

    mainFolder = char(mainFolder);
    fprintf('\n選擇的大資料夾：\n%s\n', mainFolder);
    fprintf('正在掃描舊的 DICOM 子資料夾與既有處理成果，請稍候...\n');

    sourceFolders = epi0.discoverSourceFolders(mainFolder, config);

    if isempty(sourceFolders)
        warning(['找不到符合「日期-lhl-組別-動物編號」格式的舊資料夾。' ...
                 '未執行任何操作。']);
        report = struct([]);
        return;
    end

    processingMask = epi0.identifyPipelineFolders(sourceFolders, config);
    processingFolders = sourceFolders(processingMask);

    if isempty(processingFolders)
        warning(['找到舊資料夾，但沒有任何資料夾符合 EPI 流程條件，' ...
                 '也沒有偵測到可續做的中間成果。']);
        report = epi0.initializeReport(sourceFolders);
        return;
    end

    assignments = epi0.buildDestinationAssignments( ...
        processingFolders, mainFolder, destinationSuffixes);

    report = epi0.initializeReport(sourceFolders);

    for index = 1:numel(processingFolders)
        reportIndex = epi0.findReportIndex( ...
            report, processingFolders(index).Path);

        report(reportIndex).IsPipelineFolder = true;
        report(reportIndex).EligibleForConversion = true;

        assignmentIndex = epi0.findAssignmentIndex( ...
            assignments, processingFolders(index).Path);

        if ~isempty(assignmentIndex)
            report(reportIndex).AssignedDestination = ...
                assignments(assignmentIndex).DestinationFile;
        end
    end

    fprintf('找到 %d 個舊資料夾。\n', numel(sourceFolders));
    fprintf('其中 %d 個會納入本次 EPI 流程或續做流程。\n', ...
        numel(processingFolders));

    confirmationText = sprintf([ ...
        '此程式支援中斷後重新執行；已完成的步驟會自動跳過。\n\n' ...
        '可能執行的操作：\n' ...
        '1. 僅在仍有 MRIm0001*~MRIm1500* 且檔案數 > %d 時刪除\n' ...
        '2. 續做 DICOM 轉 NIfTI、空間尺度乘以 10、改名 EPI0.nii\n' ...
        '3. 建立分類資料夾\n' ...
        '4. 目的地已有 EPI0.nii 時不覆蓋、不剪下來源檔\n\n' ...
        '納入處理的舊資料夾：%d\n' ...
        '主資料夾：\n%s\n\n確定要繼續嗎？'], ...
        config.LargeFolderThreshold, numel(processingFolders), mainFolder);

    choice = questdlg(confirmationText, '確認執行 EPI0 可續做流程', ...
        '開始執行', '取消', '取消');

    if ~strcmp(choice, '開始執行')
        fprintf('已取消，未修改任何檔案。\n');
        report = struct([]);
        return;
    end

    [report, step1Stats] = epi0.runStep1Delete( ...
        processingFolders, assignments, report, config);

    [report, step2To4Stats] = epi0.runSteps2To4Convert( ...
        processingFolders, assignments, report, config);

    epi0.runStep5CreateDestinations( ...
        mainFolder, processingFolders, destinationSuffixes);

    [report, step6Stats] = epi0.runStep6MoveFiles( ...
        assignments, report, destinationSuffixes);

    logFile = epi0.saveReport(report, mainFolder);

    fprintf('\n============================================================\n');
    fprintf('完整流程執行完畢\n');
    fprintf('============================================================\n');
    fprintf('舊資料夾總數：%d\n', numel(sourceFolders));
    fprintf('納入 EPI/續做流程：%d\n', numel(processingFolders));
    fprintf('步驟 1 已經完成而跳過：%d\n', ...
        step1Stats.AlreadySkippedCount);
    fprintf('步驟 1 本次實際刪除的資料夾：%d\n', ...
        step1Stats.DeletedFolderCount);
    fprintf('步驟 2-4 因已有成果而跳過：%d\n', ...
        step2To4Stats.SkippedCount);
    fprintf('本次成功移動 EPI0.nii：%d\n', step6Stats.MovedCount);
    fprintf('目的地已有 EPI0.nii 而跳過移動：%d\n', ...
        step6Stats.DestinationOccupiedCount);
    fprintf('來源沒有 EPI0.nii、目的資料夾保持空白：%d\n', ...
        step6Stats.MissingSourceCount);
    fprintf('超過五個目的槽而保留於來源：%d\n', ...
        step6Stats.ExtraSourceCount);

    if ~isempty(logFile)
        fprintf('處理紀錄：%s\n', logFile);
    end

    fprintf('總處理時間：%.1f 秒\n', toc(pipelineTimer));
end
