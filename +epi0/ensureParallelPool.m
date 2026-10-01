function enabled = ensureParallelPool(maxWorkers)
%ENSUREPARALLELPOOL 啟用小型 CPU worker pool。
%
% 大量小檔案 I/O 不適合開太多 worker，因此預設上限由 config 控制。

    enabled = false;

    try
        hasToolbox = ...
            license('test', 'Distrib_Computing_Toolbox') && ...
            ~isempty(ver('parallel'));

        if ~hasToolbox
            return;
        end

        pool = gcp('nocreate');

        if isempty(pool)
            cluster = parcluster('local');
            workerCount = min( ...
                double(maxWorkers), double(cluster.NumWorkers));

            pool = parpool(cluster, workerCount);
        end

        enabled = ~isempty(pool) && pool.NumWorkers >= 2;

    catch ME
        warning(['無法啟用平行運算，將改用單核心流程：%s'], ...
            ME.message);

        enabled = false;
    end
end
