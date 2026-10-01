function reportIndex = findReportIndex(report, folderPath)
%FINDREPORTINDEX 依來源資料夾找到 report 中對應的索引。

    reportIndex = find(strcmp({report.SourceFolder}, folderPath), 1);

    if isempty(reportIndex)
        error('Internal report index was not found for: %s', folderPath);
    end
end
