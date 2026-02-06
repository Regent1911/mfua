@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM === Настройки ===
REM  BASE_DIR - каталог, где лежат репозитории
set "BASE_DIR=D:\_Regent\Education"
set "DONOR_DIR=from_rurewa\mfua"
set "RECIP_DIR=local_rurewa\mfua"
set "DONOR_URL=https://gitflic.ru/project/rurewa/mfua"
set "RECIP_URL=https://github.com/Regent1911/mfua"

title Тянем изменения репозиториев
color 0A

echo ========================================
echo     'СИНХРОНИЗАЦИЯ' РЕПОЗИТОРИЕВ
echo ========================================
echo.

REM Проверяем наличие Git
where git >nul 2>nul
if errorlevel 1 (
    echo ОШИБКА: Git не установлен или не добавлен в PATH
    echo Установите Git с https://git-scm.com/
    pause
    exit /b 1
)

echo [1/7] Проверяю каталоги...
if not exist "%BASE_DIR%\%DONOR_DIR%\.git" (
    echo   Клонирую репозиторий донор...
    git clone "%DONOR_URL%" "%BASE_DIR%\%DONOR_DIR%"
    if errorlevel 1 (
        echo ОШИБКА: Не удалось клонировать репозиторий донора
        pause
        exit /b 1
    )
) else (
    echo   Каталог донора найден
)

if not exist "%BASE_DIR%\%RECIP_DIR%\.git" (
    echo   Клонирую репозиторий реципиент...
    git clone "%RECIP_URL%" "%BASE_DIR%\%RECIP_DIR%"
    if errorlevel 1 (
        echo ОШИБКА: Не удалось клонировать репозиторий реципиент
        pause
        exit /b 1
    )
) else (
    echo   Каталог реципиент найден
)

echo.
echo [2/7] Обновляю репозиторий донор...
cd /d "%BASE_DIR%\%DONOR_DIR%"
git fetch origin
git pull origin master
if errorlevel 1 (
    git pull origin main
    if errorlevel 1 (
        echo ВНИМАНИЕ: Не удалось обновить репозиторий донор
    )
)

echo.
echo [3/7] Копирую файлы из репозитория донора...
cd /d "%BASE_DIR%"
echo   Из: %BASE_DIR%\%DONOR_DIR%
echo   В:  %BASE_DIR%\%RECIP_DIR%

REM Создаем временный файл со списком файлов для копирования
dir "%BASE_DIR%\%DONOR_DIR%" /b /a-d > "%temp%\files_to_copy.txt" 2>nul
dir "%BASE_DIR%\%DONOR_DIR%" /b /ad | findstr /v /i ".git" > "%temp%\dirs_to_copy.txt" 2>nul

REM Копируем файлы
for /f "delims=" %%f in ('type "%temp%\files_to_copy.txt"') do (
    if not "%%f"=="files_to_copy.txt" (
        copy "%BASE_DIR%\%DONOR_DIR%\%%f" "%BASE_DIR%\%RECIP_DIR%\" >nul
        echo   Файл: %%f
    )
)

REM Копируем папки (рекурсивно)
for /f "delims=" %%d in ('type "%temp%\dirs_to_copy.txt"') do (
    xcopy "%BASE_DIR%\%DONOR_DIR%\%%d" "%BASE_DIR%\%RECIP_DIR%\%%d" /E /Y /I >nul
    echo   Папка: %%d
)

del "%temp%\files_to_copy.txt" "%temp%\dirs_to_copy.txt" >nul 2>nul

echo.
echo [4/7] Перехожу в репозиторий реципиент...
cd /d "%BASE_DIR%\%RECIP_DIR%"

echo.
echo [5/7] Добавляю изменения в Git...
git add .

echo.
echo [6/7] Создаю коммит...
set "commit_msg=Обновление из репозитория донор %date% %time:~0,8%"
git commit -m "%commit_msg%"

if errorlevel 1 (
    echo   Нет изменений для коммита
    goto :skip_push
)

echo.
echo [7/7] Отправляю на GitHub...
git pull origin master --rebase
if errorlevel 1 (
    git pull origin main --rebase
)

git push origin master
if errorlevel 1 (
    git push origin main
    if errorlevel 1 (
        echo ВНИМАНИЕ: Не удалось отправить изменения
        echo Возможно нужна принудительная отправка:
        echo   git push -f origin master
    ) else (
        echo УСПЕХ: Изменения отправлены на GitHub
    )
) else (
    echo УСПЕХ: Изменения отправлены на GitHub
)

:skip_push
echo.
echo ========================================
echo     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА
echo ========================================
echo.
pause