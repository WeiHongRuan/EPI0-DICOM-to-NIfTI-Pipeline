function logFile = saveReport(report, mainFolder)
%SAVEREPORT 將處理結果儲存為 CSV。

    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    logFile = fullfile(mainFolder, ...
        ['EPI0_pipeline_log_' timestamp '.csv']);

    try
        writetable(struct2table(report), logFile);
    catch ME
        warning('無法寫入 CSV 報告：%s', ME.message);
        logFile = '';
    end
end
