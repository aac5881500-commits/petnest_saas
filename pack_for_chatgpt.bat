@echo off
chcp 65001 >nul
setlocal EnableExtensions

title PetNest ChatGPT 完整打包工具

set "PROJECT_DIR=%~dp0"
set "TEMP_DIR=%TEMP%\petnest_chatgpt_pack"
set "REPORT_DIR=%TEMP_DIR%\_project_reports"
set "ZIP_FILE=%PROJECT_DIR%upload_for_chatgpt.zip"

echo.
echo ==================================================
echo   PetNest ChatGPT 完整交接包建立中...
echo ==================================================
echo.
echo 專案位置：
echo %PROJECT_DIR%
echo.

echo [清理] 刪除舊資料...

if exist "%PROJECT_DIR%upload_for_chatgpt" (
    rmdir /s /q "%PROJECT_DIR%upload_for_chatgpt"
)

if exist "%TEMP_DIR%" (
    rmdir /s /q "%TEMP_DIR%"
)

if exist "%ZIP_FILE%" (
    del /f /q "%ZIP_FILE%"
)

mkdir "%TEMP_DIR%"
if errorlevel 1 goto ERROR_END

mkdir "%REPORT_DIR%"
if errorlevel 1 goto ERROR_END

echo.
echo [1/10] 複製 Flutter lib...

if exist "%PROJECT_DIR%lib" (
    robocopy "%PROJECT_DIR%lib" "%TEMP_DIR%\lib" /E /R:1 /W:1 /XD ".dart_tool" "build" /XF "*.log" "*.tmp" >nul
)

echo [2/10] 複製 Cloud Functions...

if exist "%PROJECT_DIR%functions" (
    robocopy "%PROJECT_DIR%functions" "%TEMP_DIR%\functions" /E /R:1 /W:1 /XD "node_modules" ".firebase" "coverage" "lib-cov" ".nyc_output" /XF "*.log" "*.tmp" ".env" ".env.*" "serviceAccountKey.json" "*service-account*.json" >nul
)

echo [3/10] 複製 assets...

if exist "%PROJECT_DIR%assets" (
    robocopy "%PROJECT_DIR%assets" "%TEMP_DIR%\assets" /E /R:1 /W:1 /XF "*.log" "*.tmp" >nul
)

echo [4/10] 複製 web...

if exist "%PROJECT_DIR%web" (
    robocopy "%PROJECT_DIR%web" "%TEMP_DIR%\web" /E /R:1 /W:1 /XD "build" /XF "*.log" "*.tmp" >nul
)

echo [5/10] 複製 Android 必要設定...

if exist "%PROJECT_DIR%android" (
    robocopy "%PROJECT_DIR%android" "%TEMP_DIR%\android" /E /R:1 /W:1 /XD ".gradle" "build" ".cxx" ".idea" /XF "key.properties" "local.properties" "*.jks" "*.keystore" "*.key" "*.log" "*.tmp" >nul
)

echo [6/10] 複製 iOS 必要設定...

if exist "%PROJECT_DIR%ios" (
    robocopy "%PROJECT_DIR%ios" "%TEMP_DIR%\ios" /E /R:1 /W:1 /XD "Pods" ".symlinks" "build" "DerivedData" /XF "*.p12" "*.cer" "*.mobileprovision" "*.key" "*.log" "*.tmp" >nul
)

echo [7/10] 複製 Firebase 與專案設定檔...

call :COPY_FILE "firebase.json"
call :COPY_FILE ".firebaserc"
call :COPY_FILE "firestore.rules"
call :COPY_FILE "firestore.indexes.json"
call :COPY_FILE "storage.rules"
call :COPY_FILE "database.rules.json"
call :COPY_FILE "pubspec.yaml"
call :COPY_FILE "pubspec.lock"
call :COPY_FILE "analysis_options.yaml"
call :COPY_FILE "README.md"
call :COPY_FILE "CHANGELOG.md"
call :COPY_FILE "l10n.yaml"

echo [8/10] 複製測試、工具與文件資料夾...

call :COPY_FOLDER "test"
call :COPY_FOLDER "integration_test"
call :COPY_FOLDER "scripts"
call :COPY_FOLDER "tools"
call :COPY_FOLDER "docs"

echo [9/10] 產生專案交接報告...

(
    echo PetNest SaaS ChatGPT 交接包
    echo.
    echo 建立日期：%DATE%
    echo 建立時間：%TIME%
    echo.
    echo 專案位置：
    echo %PROJECT_DIR%
    echo.
    echo 已排除大型或敏感資料：
    echo node_modules
    echo build
    echo .dart_tool
    echo .gradle
    echo Pods
    echo .env
    echo service account
    echo Android 簽署金鑰
) > "%REPORT_DIR%\PACK_INFO.txt"

where flutter >nul 2>nul
if errorlevel 1 (
    echo 找不到 Flutter 指令。 > "%REPORT_DIR%\FLUTTER_VERSION.txt"
) else (
    call flutter --version > "%REPORT_DIR%\FLUTTER_VERSION.txt" 2>&1
)

where dart >nul 2>nul
if errorlevel 1 (
    echo 找不到 Dart 指令。 > "%REPORT_DIR%\DART_VERSION.txt"
) else (
    call dart --version > "%REPORT_DIR%\DART_VERSION.txt" 2>&1
)

where node >nul 2>nul
if errorlevel 1 (
    echo 找不到 Node 指令。 > "%REPORT_DIR%\NODE_VERSION.txt"
) else (
    call node --version > "%REPORT_DIR%\NODE_VERSION.txt" 2>&1
)

where npm >nul 2>nul
if errorlevel 1 (
    echo 找不到 npm 指令。 > "%REPORT_DIR%\NPM_VERSION.txt"
) else (
    call npm --version > "%REPORT_DIR%\NPM_VERSION.txt" 2>&1
)

where firebase >nul 2>nul
if errorlevel 1 (
    echo 找不到 Firebase CLI。 > "%REPORT_DIR%\FIREBASE_VERSION.txt"
) else (
    call firebase --version > "%REPORT_DIR%\FIREBASE_VERSION.txt" 2>&1

    pushd "%PROJECT_DIR%"
    call firebase use > "%REPORT_DIR%\FIREBASE_CURRENT_PROJECT.txt" 2>&1
    popd
)

where git >nul 2>nul
if errorlevel 1 (
    echo 找不到 Git 指令。 > "%REPORT_DIR%\GIT_STATUS.txt"
) else (
    pushd "%PROJECT_DIR%"

    git status --short > "%REPORT_DIR%\GIT_STATUS.txt" 2>&1
    git branch --show-current > "%REPORT_DIR%\GIT_BRANCH.txt" 2>&1
    git log -10 --oneline > "%REPORT_DIR%\GIT_RECENT_COMMITS.txt" 2>&1
    git diff --stat > "%REPORT_DIR%\GIT_DIFF_STAT.txt" 2>&1
    git diff --name-status > "%REPORT_DIR%\GIT_CHANGED_FILES.txt" 2>&1

    popd
)

dir /B "%PROJECT_DIR%" > "%REPORT_DIR%\PROJECT_ROOT_FILES.txt" 2>&1

if exist "%TEMP_DIR%\functions\payments" (
    dir /S /B "%TEMP_DIR%\functions\payments" > "%REPORT_DIR%\PAYMENT_FILES.txt" 2>&1
)

if exist "%PROJECT_DIR%functions\package.json" (
    copy /Y "%PROJECT_DIR%functions\package.json" "%REPORT_DIR%\FUNCTIONS_PACKAGE.json" >nul
)

if exist "%PROJECT_DIR%functions\package-lock.json" (
    copy /Y "%PROJECT_DIR%functions\package-lock.json" "%REPORT_DIR%\FUNCTIONS_PACKAGE_LOCK.json" >nul
)

echo 建立完整檔案清單...

pushd "%TEMP_DIR%"
dir /S /B > "%REPORT_DIR%\PROJECT_FILE_LIST.txt" 2>&1
popd

echo 執行敏感資料安全清理...

for /R "%TEMP_DIR%" %%F in (.env) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (.env.*) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (key.properties) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (local.properties) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (serviceAccountKey.json) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (*service-account*.json) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (*.jks) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (*.keystore) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (*.p12) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (*.mobileprovision) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

for /R "%TEMP_DIR%" %%F in (*.cer) do (
    if exist "%%F" del /F /Q "%%F" >nul 2>&1
)

echo [10/10] 壓縮 ZIP...
echo 請稍候，依照專案大小可能需要一些時間。
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference = 'Stop'; Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%ZIP_FILE%' -CompressionLevel Optimal -Force"

if errorlevel 1 goto ERROR_END

if not exist "%ZIP_FILE%" goto ERROR_END

for %%A in ("%ZIP_FILE%") do set "ZIP_BYTES=%%~zA"

rmdir /s /q "%TEMP_DIR%"

echo.
echo ==================================================
echo   打包完成！
echo ==================================================
echo.
echo ZIP 位置：
echo %ZIP_FILE%
echo.
echo ZIP 大小：%ZIP_BYTES% Bytes
echo.
echo 已包含：
echo Flutter lib
echo Cloud Functions 與 payments
echo assets
echo Android、iOS、Web 必要檔案
echo Firebase Rules 與 Indexes
echo Git 修改紀錄
echo Flutter、Node、Firebase 版本
echo.
echo 已排除：
echo node_modules
echo build
echo .dart_tool
echo Pods
echo 簽署金鑰
echo service account
echo .env
echo.
echo 可以把 upload_for_chatgpt.zip 上傳到新聊天。
echo ==================================================
echo.
pause
goto END

:COPY_FILE
if exist "%PROJECT_DIR%%~1" (
    copy /Y "%PROJECT_DIR%%~1" "%TEMP_DIR%\" >nul
)
exit /b 0

:COPY_FOLDER
if exist "%PROJECT_DIR%%~1" (
    robocopy "%PROJECT_DIR%%~1" "%TEMP_DIR%\%~1" /E /R:1 /W:1 /XD "node_modules" "build" ".dart_tool" /XF "*.log" "*.tmp" ".env" ".env.*" >nul
)
exit /b 0

:ERROR_END
echo.
echo ==================================================
echo   打包失敗
echo ==================================================
echo.
echo 暫存資料保留在：
echo %TEMP_DIR%
echo.
echo 請截圖這個畫面給我。
echo.
pause
goto END

:END
endlocal