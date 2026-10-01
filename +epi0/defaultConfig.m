function config = defaultConfig()
%DEFAULTCONFIG 集中管理整個流程的參數。
%
% 日後最常修改的設定建議只改這個檔案。

    config = struct;

    config.LargeFolderThreshold = 2000;
    config.DeleteFirstIndex = 1;
    config.DeleteLastIndex = 1500;
    config.ScaleFactor = 10;
    config.MaximumDestinationFiles = 5;

    % 資料夾與輸出規則
    config.DestinationSuffixes = {'0-1X', '0-2X', '4X', '5X', '6X'};

    % 速度設定
    config.SearchOnlyDirectChildren = true;
    config.UseParallel = true;
    config.MaxParallelWorkers = 4;
    config.MinimumFilesForParallel = 200;
    config.PreferMRImCandidates = true;
    config.Verbose = false;
end
