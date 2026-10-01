# EPI0 模組化流程使用說明

此 MATLAB 程式用於 EPI 資料前處理前的資料整理，包括移除指定 DICOM EPI 檔案、將剩餘 DICOM 轉換成 NIfTI、調整空間尺度、重新命名為 `EPI0.nii`，並依規則移動到指定資料夾。

> **注意：此程式包含刪除與移動檔案的操作。第一次使用時請務必先在資料副本上測試。**

## 資料夾結構

```text
EPI0-DICOM-to-NIfTI-Pipeline/
├── run_EPI0_pipeline.m
└── +epi0/
    ├── defaultConfig.m
    ├── runStep1Delete.m
    ├── runSteps2To4Convert.m
    ├── runStep5CreateDestinations.m
    ├── runStep6MoveFiles.m
    ├── convertDicomFolder.m
    └── 其他工具函式
```

`+epi0` 前面的 `+` 是 MATLAB package 的必要命名，請勿移除。

## 執行方式

在 MATLAB 將 Current Folder 設定到 repository 根目錄後執行：

```matlab
report = run_EPI0_pipeline;
```

接著選擇包含 EPI 資料的最上層資料夾，確認程式顯示的處理內容後再開始執行。

## 最常修改的位置

1. 數量、倍率、目的資料夾與平行運算設定：`+epi0/defaultConfig.m`
2. 第一步刪除規則：`+epi0/runStep1Delete.m`、`+epi0/deleteIndexedMRIData.m`
3. DICOM 轉 NIfTI：`+epi0/convertDicomFolder.m`
4. NIfTI 空間尺度調整：`+epi0/scaleNiftiSpaceByFactor.m`
5. 建立分類資料夾：`+epi0/runStep5CreateDestinations.m`
6. EPI0 移動規則：`+epi0/runStep6MoveFiles.m`、`+epi0/buildDestinationAssignments.m`

## GitHub 上傳注意事項

請不要把原始 DICOM、NIfTI、受試者/動物識別資料或實驗資料直接放進 repository。本專案的 `.gitignore` 已預設排除常見的影像資料格式。
