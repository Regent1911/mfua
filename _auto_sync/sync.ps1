#!/usr/bin/env pwsh
# PowerShell скрипт для синхронизации репозиториев

# Настройки кодировки
$OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
chcp 65001 > $null

# === Настройки ===
$BASE_DIR = "E:\_Regent\Education"
$DONOR_DIR = "from_rurewa\mfua"
$RECIP_DIR = "local_rurewa\mfua"
$DONOR_URL = "https://gitflic.ru/project/rurewa/mfua.git"  # Добавлен .git
$RECIP_URL = "https://github.com/Regent1911/mfua.git"      # Добавлен .git

# Цвета для вывода
$Host.UI.RawUI.WindowTitle = "Синхронизация репозиториев"
$Host.UI.RawUI.ForegroundColor = 'Green'

function Write-ColorStep {
    param([string]$Text, [int]$Step)
    Write-Host "[$Step/7] $Text" -ForegroundColor Magenta
}

function Write-Success {
    param([string]$Text)
    Write-Host "  ✓ $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "  → $Text" -ForegroundColor Gray
}

function Write-Warning {
    param([string]$Text)
    Write-Host "  ⚠ $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "  ✗ $Text" -ForegroundColor Red
}

Clear-Host
Write-Host "╔" + ("═" * 39) + "╗" -ForegroundColor Cyan
Write-Host "║    СИНХРОНИЗАЦИЯ РЕПОЗИТОРИЕВ    ║" -ForegroundColor Yellow
Write-Host "╚" + ("═" * 39) + "╝" -ForegroundColor Cyan
Write-Host ""

# Проверяем наличие Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "Git не установлен или не добавлен в PATH"
    Write-Host "Установите Git с https://git-scm.com/" -ForegroundColor Yellow
    Read-Host "`nНажмите Enter для выхода"
    exit 1
}

# Проверяем версию Git
$gitVersion = git --version
Write-Info "Используется: $gitVersion"

# Создаем пути
$DonorPath = Join-Path $BASE_DIR $DONOR_DIR
$RecipPath = Join-Path $BASE_DIR $RECIP_DIR

# Функция для проверки и исправления состояния репозитория
function Fix-Repository {
    param(
        [string]$RepoPath,
        [string]$RepoUrl,
        [string]$RepoName
    )

    if (-not (Test-Path $RepoPath)) {
        Write-Error "Путь не существует: $RepoPath"
        return $false
    }

    Set-Location $RepoPath

    # Проверяем, является ли папка git репозиторием
    if (-not (Test-Path ".git")) {
        Write-Error "Папка не является git репозиторием: $RepoPath"
        return $false
    }

    # Проверяем, существует ли remote origin
    $remotes = git remote
    if ($remotes -notcontains "origin") {
        Write-Info "Добавляю remote origin для $RepoName..."
        git remote add origin $RepoUrl
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Не удалось добавить remote origin"
            return $false
        }
        Write-Success "Remote origin добавлен"
    } else {
        # Проверяем правильность URL
        $currentUrl = git remote get-url origin
        if ($currentUrl -ne $RepoUrl) {
            Write-Info "Обновляю URL remote origin для $RepoName..."
            git remote set-url origin $RepoUrl
            Write-Success "URL обновлен: $RepoUrl"
        }
    }

    # Получаем обновления с удаленного репозитория
    Write-Info "Получаю обновления с удаленного репозитория..."
    git fetch --all --prune
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Проблема при получении обновлений для $RepoName"
    }

    # Проверяем текущее состояние
    $branch = git branch --show-current 2>$null
    if (-not $branch) {
        Write-Info "Репозиторий $RepoName в состоянии detached HEAD"

        # Пытаемся определить основную ветку
        $remoteBranches = git branch -r | ForEach-Object { $_.Trim() }

        if ($remoteBranches -match "origin/master$") {
            Write-Info "Переключаюсь на ветку master..."
            git checkout master 2>$null
            if ($LASTEXITCODE -ne 0) {
                git checkout -b master origin/master
            }
            git branch --set-upstream-to=origin/master master
            Write-Success "Переключен на ветку master"
        }
        elseif ($remoteBranches -match "origin/main$") {
            Write-Info "Переключаюсь на ветку main..."
            git checkout main 2>$null
            if ($LASTEXITCODE -ne 0) {
                git checkout -b main origin/main
            }
            git branch --set-upstream-to=origin/main main
            Write-Success "Переключен на ветку main"
        }
        else {
            # Если нет ни master ни main, берем первую доступную ветку
            $firstBranch = ($remoteBranches | Where-Object { $_ -match "^origin/" } | Select-Object -First 1)
            if ($firstBranch) {
                $branchName = $firstBranch -replace "^origin/", ""
                Write-Info "Переключаюсь на ветку $branchName..."
                git checkout $branchName 2>$null
                if ($LASTEXITCODE -ne 0) {
                    git checkout -b $branchName $firstBranch
                }
                git branch --set-upstream-to=$firstBranch $branchName
                Write-Success "Переключен на ветку $branchName"
            } else {
                Write-Error "Не могу найти ветку для репозитория $RepoName"
                return $false
            }
        }
    }
    else {
        Write-Success "Репозиторий $RepoName на ветке: $branch"

        # Проверяем, есть ли upstream для текущей ветки
        $upstream = git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
        if (-not $upstream) {
            Write-Info "Устанавливаю upstream для ветки $branch..."
            if (git show-ref --verify --quiet "refs/remotes/origin/$branch") {
                git branch --set-upstream-to="origin/$branch" $branch
                Write-Success "Upstream установлен на origin/$branch"
            } elseif (git show-ref --verify --quiet "refs/remotes/origin/master") {
                git branch --set-upstream-to="origin/master" $branch
                Write-Success "Upstream установлен на origin/master"
            } elseif (git show-ref --verify --quiet "refs/remotes/origin/main") {
                git branch --set-upstream-to="origin/main" $branch
                Write-Success "Upstream установлен на origin/main"
            }
        }
    }

    return $true
}

Write-ColorStep -Text "Проверяю каталоги..." -Step 1

# Проверяем/клонируем донор
if (-not (Test-Path (Join-Path $DonorPath ".git"))) {
    Write-Info "Клонирую репозиторий донор..."
    Write-Info "URL: $DONOR_URL"
    git clone $DONOR_URL $DonorPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Не удалось клонировать репозиторий донора"
        Write-Host "`nПроверьте:" -ForegroundColor Yellow
        Write-Host "  1. Доступность URL: $DONOR_URL" -ForegroundColor Gray
        Write-Host "  2. Подключение к интернету" -ForegroundColor Gray
        Write-Host "  3. Не требует ли репозиторий авторизации" -ForegroundColor Gray
        Read-Host "`nНажмите Enter для выхода"
        exit 1
    }
    Write-Success "Репозиторий донора склонирован"
} else {
    Write-Success "Каталог донора найден"
}

# Проверяем/клонируем реципиент
if (-not (Test-Path (Join-Path $RecipPath ".git"))) {
    Write-Info "Клонирую репозиторий реципиент..."
    Write-Info "URL: $RECIP_URL"
    git clone $RECIP_URL $RecipPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Не удалось клонировать репозиторий реципиент"
        Read-Host "`nНажмите Enter для выхода"
        exit 1
    }
    Write-Success "Репозиторий реципиента склонирован"
} else {
    Write-Success "Каталог реципиент найден"
}

Write-Host ""
Write-ColorStep -Text "Обновляю репозиторий донор..." -Step 2

# Исправляем состояние донора если нужно
$donorFixed = Fix-Repository -RepoPath $DonorPath -RepoUrl $DONOR_URL -RepoName "донора"

if ($donorFixed) {
    # Определяем текущую ветку
    $currentBranch = git -C $DonorPath branch --show-current

    Write-Info "Обновляю ветку $currentBranch..."
    git -C $DonorPath pull origin $currentBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Не удалось обновить репозиторий донор"
        # Пробуем альтернативную ветку
        $altBranch = if ($currentBranch -eq "master") { "main" } else { "master" }
        Write-Info "Пробую ветку $altBranch..."
        git -C $DonorPath pull origin $altBranch
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Донор успешно обновлен (ветка $altBranch)"
        }
    } else {
        Write-Success "Донор успешно обновлен"
    }
}

Write-Host ""
Write-ColorStep -Text "Копирую файлы из репозитория донора..." -Step 3
Write-Info "Из: $DonorPath"
Write-Info "В:  $RecipPath"

# Убеждаемся, что папка назначения существует
if (-not (Test-Path $RecipPath)) {
    New-Item -ItemType Directory -Path $RecipPath -Force | Out-Null
}

# Получаем список файлов и папок (исключая .git)
$items = Get-ChildItem $DonorPath -Exclude ".git", ".github"
$fileCount = 0
$dirCount = 0
$errorCount = 0

foreach ($item in $items) {
    $destPath = Join-Path $RecipPath $item.Name

    try {
        if ($item.PSIsContainer) {
            # Это папка
            Copy-Item $item.FullName $destPath -Recurse -Force -ErrorAction Stop
            $dirCount++
            Write-Info "Папка: $($item.Name)" -ForegroundColor Gray
        } else {
            # Это файл
            Copy-Item $item.FullName $destPath -Force -ErrorAction Stop
            $fileCount++
            Write-Info "Файл: $($item.Name)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Не удалось скопировать: $($item.Name) - $_"
        $errorCount++
    }
}

Write-Success "Скопировано: $fileCount файлов, $dirCount папок"
if ($errorCount -gt 0) {
    Write-Warning "Ошибок при копировании: $errorCount"
}

Write-Host ""
Write-ColorStep -Text "Перехожу в репозиторий реципиент..." -Step 4
Set-Location $RecipPath
Write-Success "Текущая директория: $(Get-Location)"

Write-Host ""
Write-ColorStep -Text "Добавляю изменения в Git..." -Step 5
git add -A  # -A добавляет все изменения, включая удаления

# Проверяем, есть ли изменения для коммита
$status = git status --porcelain
if (-not $status) {
    Write-Host ""
    Write-Info "Нет изменений для коммита"
    Write-Host ""
    Write-Host "╔" + ("═" * 39) + "╗" -ForegroundColor Cyan
    Write-Host "║     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА     ║" -ForegroundColor Yellow
    Write-Host "╚" + ("═" * 39) + "╝" -ForegroundColor Cyan
    Read-Host "`nНажмите Enter для выхода"
    exit 0
}

Write-Info "Найдены изменения:"
$status | ForEach-Object {
    $changeType = $_.Substring(0,2)
    $fileName = $_.Substring(3)
    switch ($changeType) {
        "M " { Write-Host "    📝 Изменен: $fileName" -ForegroundColor Gray }
        "A " { Write-Host "    ➕ Добавлен: $fileName" -ForegroundColor Gray }
        "D " { Write-Host "    ❌ Удален: $fileName" -ForegroundColor Gray }
        "R " { Write-Host "    🔄 Переименован: $fileName" -ForegroundColor Gray }
        "??" { Write-Host "    ❓ Новый: $fileName" -ForegroundColor Gray }
        default { Write-Host "    $changeType $fileName" -ForegroundColor Gray }
    }
}

Write-Host ""
Write-ColorStep -Text "Создаю коммит..." -Step 6
$date = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
$commitMsg = "Обновление из репозитория донора от $date"
git commit -m $commitMsg

if ($LASTEXITCODE -ne 0) {
    Write-Error "Не удалось создать коммит"
    Read-Host "`nНажмите Enter для выхода"
    exit 1
}

Write-Success "Коммит создан: $commitMsg"

Write-Host ""
Write-ColorStep -Text "Отправляю на GitHub..." -Step 7

# Сначала проверяем состояние реципиента
$recipientFixed = Fix-Repository -RepoPath $RecipPath -RepoUrl $RECIP_URL -RepoName "реципиента"

# Пытаемся определить текущую ветку
$currentBranch = git branch --show-current
Write-Info "Текущая ветка: $currentBranch"

# Pull с rebase
Write-Info "Получаю обновления из удаленного репозитория..."
$pullResult = git pull origin $currentBranch --rebase 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Не удалось получить обновления для ветки $currentBranch"
    Write-Info "Пробую альтернативную ветку..."

    $altBranch = if ($currentBranch -eq "master") { "main" } else { "master" }
    $pullResult = git pull origin $altBranch --rebase 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Обновления получены (ветка $altBranch)"
        $currentBranch = $altBranch
    } else {
        Write-Warning "Не удалось получить обновления. Продолжаю с текущей веткой..."
    }
} else {
    Write-Success "Обновления получены"
}

# Push
Write-Info "Отправляю изменения..."
$pushResult = git push origin $currentBranch 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Не удалось отправить в ветку $currentBranch"
    Write-Info "Пробую альтернативную ветку..."

    $altBranch = if ($currentBranch -eq "master") { "main" } else { "master" }
    $pushResult = git push origin $altBranch 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Не удалось отправить изменения"
        Write-Host ""
        Write-Host "Возможные решения:" -ForegroundColor Yellow
        Write-Host "  1. Сделать pull вручную с merge вместо rebase:" -ForegroundColor Gray
        Write-Host "     git pull origin $currentBranch --no-rebase" -ForegroundColor Gray
        Write-Host "  2. Проверить конфликты:" -ForegroundColor Gray
        Write-Host "     git status" -ForegroundColor Gray
        Write-Host "  3. Принудительная отправка (если уверены):" -ForegroundColor Gray
        Write-Host "     git push -f origin $currentBranch" -ForegroundColor Gray
    } else {
        Write-Success "Изменения отправлены на GitHub (ветка $altBranch)"
    }
} else {
    Write-Success "Изменения отправлены на GitHub (ветка $currentBranch)"
}

# Показываем статистику
Write-Host ""
Write-Info "Статистика синхронизации:"
Write-Info "  Донор: $DONOR_URL"
Write-Info "  Реципиент: $RECIP_URL"
$commitHash = git rev-parse --short HEAD
Write-Info "  Последний коммит: $commitHash"

Write-Host ""
Write-Host "╔" + ("═" * 39) + "╗" -ForegroundColor Cyan
Write-Host "║     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА     ║" -ForegroundColor Yellow
Write-Host "╚" + ("═" * 39) + "╝" -ForegroundColor Cyan
Read-Host "`nНажмите Enter для выхода"