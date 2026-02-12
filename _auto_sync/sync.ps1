#!/usr/bin/env pwsh
# PowerShell скрипт для синхронизации репозиториев

# Настройки кодировки
$OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
chcp 65001 > $null

# === Настройки ===
$BASE_DIR = "D:\_Regent\Education"
$DONOR_DIR = "from_rurewa\mfua"
$RECIP_DIR = "local_rurewa\mfua"
$DONOR_URL = "https://gitflic.ru/project/rurewa/mfua"
$RECIP_URL = "https://github.com/Regent1911/mfua"

# Цвета для вывода
$Host.UI.RawUI.WindowTitle = "Тянем изменения репозиториев"
$Host.UI.RawUI.ForegroundColor = 'Green'

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    'СИНХРОНИЗАЦИЯ' РЕПОЗИТОРИЕВ" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Проверяем наличие Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: Git не установлен или не добавлен в PATH" -ForegroundColor Red
    Write-Host "Установите Git с https://git-scm.com/" -ForegroundColor Yellow
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

Write-Host "[1/7] Проверяю каталоги..." -ForegroundColor Magenta

# Создаем пути
$DonorPath = Join-Path $BASE_DIR $DONOR_DIR
$RecipPath = Join-Path $BASE_DIR $RECIP_DIR

# Проверяем/клонируем донор
if (-not (Test-Path (Join-Path $DonorPath ".git"))) {
    Write-Host "  Клонирую репозиторий донор..." -ForegroundColor Yellow
    git clone $DONOR_URL $DonorPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось клонировать репозиторий донора" -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
} else {
    Write-Host "  Каталог донора найден" -ForegroundColor Green
}

# Проверяем/клонируем реципиент
if (-not (Test-Path (Join-Path $RecipPath ".git"))) {
    Write-Host "  Клонирую репозиторий реципиент..." -ForegroundColor Yellow
    git clone $RECIP_URL $RecipPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ОШИБКА: Не удалось клонировать репозиторий реципиент" -ForegroundColor Red
        Read-Host "Нажмите Enter для выхода"
        exit 1
    }
} else {
    Write-Host "  Каталог реципиент найден" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/7] Обновляю репозиторий донор..." -ForegroundColor Magenta
Set-Location $DonorPath

git fetch origin
$pullResult = git pull origin master
if ($LASTEXITCODE -ne 0) {
    git pull origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ВНИМАНИЕ: Не удалось обновить репозиторий донор" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[3/7] Копирую файлы из репозитория донора..." -ForegroundColor Magenta
Write-Host "  Из: $DonorPath" -ForegroundColor Gray
Write-Host "  В:  $RecipPath" -ForegroundColor Gray

# Создаем временные файлы
$tempFiles = [System.IO.Path]::GetTempFileName()
$tempDirs = [System.IO.Path]::GetTempFileName()

try {
    # Получаем список файлов и папок
    $items = Get-ChildItem $DonorPath -Exclude ".git"

    $files = $items | Where-Object { -not $_.PSIsContainer }
    $dirs = $items | Where-Object { $_.PSIsContainer -and $_.Name -ne ".git" }

    # Копируем файлы
    foreach ($file in $files) {
        Copy-Item $file.FullName $RecipPath -Force -ErrorAction SilentlyContinue
        Write-Host "  Файл: $($file.Name)" -ForegroundColor Gray
    }

    # Копируем папки рекурсивно
    foreach ($dir in $dirs) {
        $destPath = Join-Path $RecipPath $dir.Name
        Copy-Item $dir.FullName $destPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Папка: $($dir.Name)" -ForegroundColor Gray
    }
} finally {
    # Удаляем временные файлы
    Remove-Item $tempFiles, $tempDirs -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "[4/7] Перехожу в репозиторий реципиент..." -ForegroundColor Magenta
Set-Location $RecipPath

Write-Host ""
Write-Host "[5/7] Добавляю изменения в Git..." -ForegroundColor Magenta
git add .

Write-Host ""
Write-Host "[6/7] Создаю коммит..." -ForegroundColor Magenta
$date = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
$commitMsg = "Обновление из репозитория донор $date"
git commit -m $commitMsg

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Нет изменений для коммита" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Read-Host "Нажмите Enter для выхода"
    exit 0
}

Write-Host ""
Write-Host "[7/7] Отправляю на GitHub..." -ForegroundColor Magenta

# Pull с rebase
git pull origin master --rebase
if ($LASTEXITCODE -ne 0) {
    git pull origin main --rebase
}

# Push
git push origin master
if ($LASTEXITCODE -ne 0) {
    git push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ВНИМАНИЕ: Не удалось отправить изменения" -ForegroundColor Yellow
        Write-Host "Возможно нужна принудительная отправка:" -ForegroundColor Yellow
        Write-Host "  git push -f origin master" -ForegroundColor Gray
    } else {
        Write-Host "УСПЕХ: Изменения отправлены на GitHub" -ForegroundColor Green
    }
} else {
    Write-Host "УСПЕХ: Изменения отправлены на GitHub" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Read-Host "Нажмите Enter для выхода"