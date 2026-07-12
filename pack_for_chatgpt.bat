@echo off
chcp 65001 >nul
setlocal

title PetNest ChatGPT 打包工具

set "PROJECT_DIR=%~dp0"
set "TEMP_DIR=%TEMP%\petnest_chatgpt_pack"
set "ZIP_FILE=%PROJECT_DIR%upload_for_chatgpt.zip"

echo.
echo ================================
echo   PetNest ChatGPT 打包中...
echo ================================
echo.

:: 刪除舊的專案內暫存資料夾，避免 VS Code 出現兩份檔案
if exist "%PROJECT_DIR%upload_for_chatgpt" (
    echo 刪除舊的專案內暫存資料夾...
    rmdir /s /q "%PROJECT_DIR%upload_for_chatgpt"
)

:: 刪除舊的 Windows 暫存資料夾
if exist "%TEMP_DIR%" (
    rmdir /s /q "%TEMP_DIR%"
)

mkdir "%TEMP_DIR%"

echo 複製 lib...
xcopy "%PROJECT_DIR%lib" "%TEMP_DIR%\lib" /E /I /Y >nul

echo 複製 functions...
if exist "%PROJECT_DIR%functions" (
    xcopy "%PROJECT_DIR%functions" "%TEMP_DIR%\functions" /E /I /Y >nul

    if exist "%TEMP_DIR%\functions\node_modules" (
        rmdir /s /q "%TEMP_DIR%\functions\node_modules"
    )
)

echo 複製 assets...
if exist "%PROJECT_DIR%assets" (
    xcopy "%PROJECT_DIR%assets" "%TEMP_DIR%\assets" /E /I /Y >nul
)

echo 複製 web...
if exist "%PROJECT_DIR%web" (
    xcopy "%PROJECT_DIR%web" "%TEMP_DIR%\web" /E /I /Y >nul
)

echo 複製設定檔...

for %%F in (
    firebase.json
    firestore.rules
    firestore.indexes.json
    storage.rules
    pubspec.yaml
    pubspec.lock
) do (
    if exist "%PROJECT_DIR%%%F" (
        copy "%PROJECT_DIR%%%F" "%TEMP_DIR%\" >nul
    )
)

echo.
echo 壓縮 ZIP...

powershell -NoProfile -Command ^
    "Compress-Archive -Path '%TEMP_DIR%\*' -DestinationPath '%ZIP_FILE%' -Force"

if errorlevel 1 (
    echo.
    echo 打包失敗，請截圖這個畫面給我。
    pause
    exit /b 1
)

:: 壓縮完成後刪除暫存資料夾
rmdir /s /q "%TEMP_DIR%"

echo.
echo ================================
echo 打包完成！
echo.
echo 已產生：
echo %ZIP_FILE%
echo ================================
echo.

pause
endlocal