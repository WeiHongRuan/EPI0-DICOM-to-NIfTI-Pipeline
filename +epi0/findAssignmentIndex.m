function assignmentIndex = findAssignmentIndex(assignments, sourcePath)
%FINDASSIGNMENTINDEX 依來源路徑找到固定目的槽位。

    assignmentIndex = find( ...
        strcmp({assignments.SourcePath}, sourcePath), 1);
end
