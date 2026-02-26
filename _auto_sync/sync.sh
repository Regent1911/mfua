#!/usr/bin/env bash

# PowerShell скрипт для синхронизации репозиториев (Bash версия)

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# === Настройки ===
BASE_DIR="$HOME/_Regent/Education"
DONOR_DIR="from_rurewa/mfua"
RECIP_DIR="local_rurewa/mfua"
DONOR_URL="https://gitflic.ru/project/rurewa/mfua.git"
RECIP_URL="https://github.com/Regent1911/mfua.git"

# Функции для вывода
write_color_step() {
    echo -e "${MAGENTA}[$2/7] $1${NC}"
}

write_success() {
    echo -e "  ${GREEN}✓ $1${NC}"
}

write_info() {
    echo -e "  ${GRAY}→ $1${NC}"
}

write_warning() {
    echo -e "  ${YELLOW}⚠ $1${NC}"
}

write_error() {
    echo -e "  ${RED}✗ $1${NC}"
}

# Очистка экрана
clear
echo -e "${CYAN}╔$(printf '═%.0s' {1..39})╗${NC}"
echo -e "${YELLOW}║    СИНХРОНИЗАЦИЯ РЕПОЗИТОРИЕВ    ║${NC}"
echo -e "${CYAN}╚$(printf '═%.0s' {1..39})╝${NC}"
echo ""

# Проверяем наличие Git
if ! command -v git &> /dev/null; then
    write_error "Git не установлен"
    echo -e "${YELLOW}Установите Git:${NC}"
    echo "  sudo apt-get install git    # для Ubuntu/Debian"
    echo "  sudo yum install git        # для CentOS/RHEL"
    echo "  sudo dnf install git        # для Fedora"
    echo "  brew install git            # для macOS"
    read -p $'\nНажмите Enter для выхода'
    exit 1
fi

# Проверяем версию Git
git_version=$(git --version)
write_info "Используется: $git_version"

# Создаем пути
DonorPath="$BASE_DIR/$DONOR_DIR"
RecipPath="$BASE_DIR/$RECIP_DIR"

# Функция для проверки и создания директории
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Функция для очистки неотслеживаемых файлов
clean_untracked_files() {
    local repo_path=$1

    cd "$repo_path" || return 1

    # Проверяем наличие неотслеживаемых файлов
    untracked=$(git ls-files --others --exclude-standard)

    if [ -n "$untracked" ]; then
        write_warning "Найдены неотслеживаемые файлы в репозитории:"
        echo "$untracked" | while read -r file; do
            echo -e "      ${GRAY}$file${NC}"
        done

        # Получаем текущую ветку
        current_branch=$(git branch --show-current)

        # Проверяем конфликтующие файлы
        conflicts=()
        while read -r file; do
            if [ -n "$file" ]; then
                # Проверяем, существует ли файл в удаленной ветке
                if git ls-tree -r "origin/$current_branch" --name-only 2>/dev/null | grep -Fx "$file" >/dev/null; then
                    conflicts+=("$file")
                fi
            fi
        done <<< "$untracked"

        if [ ${#conflicts[@]} -gt 0 ]; then
            write_warning "Найдены конфликтующие файлы, которые есть в удаленном репозитории:"
            for file in "${conflicts[@]}"; do
                echo -e "      ${YELLOW}$file${NC}"
            done

            # Спрашиваем пользователя
            echo -e "\n  ${CYAN}Выберите действие:${NC}"
            echo -e "    ${GRAY}1 - Удалить конфликтующие файлы (рекомендуется)${NC}"
            echo -e "    ${GRAY}2 - Пропустить обновление донора (риск рассинхронизации)${NC}"
            echo -e "    ${GRAY}3 - Принудительно сбросить репозиторий до состояния remote${NC}"

            read -p "  Ваш выбор (1/2/3): " choice

            case $choice in
                1)
                    write_info "Удаляю конфликтующие файлы..."
                    for file in "${conflicts[@]}"; do
                        rm -f "$file"
                        write_info "Удален: $file"
                    done
                    return 0
                    ;;
                2)
                    write_warning "Пропускаю обновление донора"
                    return 1
                    ;;
                3)
                    write_info "Выполняю жесткий сброс репозитория..."
                    git fetch origin
                    git reset --hard "origin/$current_branch"
                    git clean -fd
                    write_success "Репозиторий сброшен до состояния remote"
                    return 0
                    ;;
                *)
                    write_warning "Неверный выбор. Пропускаю обновление донора"
                    return 1
                    ;;
            esac
        fi
    fi
    return 0
}

# Функция для проверки и исправления состояния репозитория
fix_repository() {
    local repo_path=$1
    local repo_url=$2
    local repo_name=$3

    if [ ! -d "$repo_path" ]; then
        write_error "Путь не существует: $repo_path"
        return 1
    fi

    cd "$repo_path" || return 1

    # Проверяем, является ли папка git репозиторием
    if [ ! -d ".git" ]; then
        write_error "Папка не является git репозиторием: $repo_path"
        return 1
    fi

    # Проверяем, существует ли remote origin
    if ! git remote | grep -q "^origin$"; then
        write_info "Добавляю remote origin для $repo_name..."
        git remote add origin "$repo_url"
        if [ $? -ne 0 ]; then
            write_error "Не удалось добавить remote origin"
            return 1
        fi
        write_success "Remote origin добавлен"
    else
        # Проверяем правильность URL
        current_url=$(git remote get-url origin)
        if [ "$current_url" != "$repo_url" ]; then
            write_info "Обновляю URL remote origin для $repo_name..."
            git remote set-url origin "$repo_url"
            write_success "URL обновлен: $repo_url"
        fi
    fi

    # Получаем обновления с удаленного репозитория
    write_info "Получаю обновления с удаленного репозитория..."
    git fetch --all --prune
    if [ $? -ne 0 ]; then
        write_warning "Проблема при получении обновлений для $repo_name"
    fi

    # Проверяем текущее состояние
    branch=$(git branch --show-current 2>/dev/null)

    if [ -z "$branch" ]; then
        write_info "Репозиторий $repo_name в состоянии detached HEAD"

        # Пытаемся определить основную ветку
        if git branch -r | grep -q "origin/master$"; then
            write_info "Переключаюсь на ветку master..."
            git checkout master 2>/dev/null || git checkout -b master origin/master
            git branch --set-upstream-to=origin/master master
            write_success "Переключен на ветку master"
        elif git branch -r | grep -q "origin/main$"; then
            write_info "Переключаюсь на ветку main..."
            git checkout main 2>/dev/null || git checkout -b main origin/main
            git branch --set-upstream-to=origin/main main
            write_success "Переключен на ветку main"
        else
            # Берем первую доступную ветку
            first_branch=$(git branch -r | grep "^origin/" | head -n1 | sed 's/^origin\///' | xargs)
            if [ -n "$first_branch" ]; then
                write_info "Переключаюсь на ветку $first_branch..."
                git checkout "$first_branch" 2>/dev/null || git checkout -b "$first_branch" "origin/$first_branch"
                git branch --set-upstream-to="origin/$first_branch" "$first_branch"
                write_success "Переключен на ветку $first_branch"
            else
                write_error "Не могу найти ветку для репозитория $repo_name"
                return 1
            fi
        fi
    else
        write_success "Репозиторий $repo_name на ветке: $branch"

        # Проверяем, есть ли upstream для текущей ветки
        if ! git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null >/dev/null; then
            write_info "Устанавливаю upstream для ветки $branch..."
            if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
                git branch --set-upstream-to="origin/$branch" "$branch"
                write_success "Upstream установлен на origin/$branch"
            elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
                git branch --set-upstream-to="origin/master" "$branch"
                write_success "Upstream установлен на origin/master"
            elif git show-ref --verify --quiet "refs/remotes/origin/main"; then
                git branch --set-upstream-to="origin/main" "$branch"
                write_success "Upstream установлен на origin/main"
            fi
        fi
    fi

    return 0
}

# Основная логика
write_color_step "Проверяю каталоги..." 1

# Создаем базовую директорию если нужно
ensure_dir "$BASE_DIR"

# Проверяем/клонируем донор
if [ ! -d "$DonorPath/.git" ]; then
    write_info "Клонирую репозиторий донор..."
    write_info "URL: $DONOR_URL"
    git clone "$DONOR_URL" "$DonorPath"
    if [ $? -ne 0 ]; then
        write_error "Не удалось клонировать репозиторий донора"
        echo -e "\n${YELLOW}Проверьте:${NC}"
        echo -e "  ${GRAY}1. Доступность URL: $DONOR_URL${NC}"
        echo -e "  ${GRAY}2. Подключение к интернету${NC}"
        echo -e "  ${GRAY}3. Не требует ли репозиторий авторизации${NC}"
        read -p $'\nНажмите Enter для выхода'
        exit 1
    fi
    write_success "Репозиторий донора склонирован"
else
    write_success "Каталог донора найден"
fi

# Проверяем/клонируем реципиент
if [ ! -d "$RecipPath/.git" ]; then
    write_info "Клонирую репозиторий реципиент..."
    write_info "URL: $RECIP_URL"
    git clone "$RECIP_URL" "$RecipPath"
    if [ $? -ne 0 ]; then
        write_error "Не удалось клонировать репозиторий реципиент"
        read -p $'\nНажмите Enter для выхода'
        exit 1
    fi
    write_success "Репозиторий реципиента склонирован"
else
    write_success "Каталог реципиент найден"
fi

echo ""
write_color_step "Обновляю репозиторий донор..." 2

# Исправляем состояние донора если нужно
fix_repository "$DonorPath" "$DONOR_URL" "донора"
donor_fixed=$?

if [ $donor_fixed -eq 0 ]; then
    # Определяем текущую ветку
    current_branch=$(git -C "$DonorPath" branch --show-current)

    # Очищаем неотслеживаемые файлы если нужно
    clean_untracked_files "$DonorPath"
    can_update=$?

    if [ $can_update -eq 0 ]; then
        write_info "Обновляю ветку $current_branch..."
        pull_output=$(git -C "$DonorPath" pull origin "$current_branch" 2>&1)
        if [ $? -ne 0 ]; then
            write_warning "Не удалось обновить репозиторий донор"
            echo -e "  ${GRAY}Детали ошибки: $pull_output${NC}"

            # Пробуем альтернативную ветку
            if [ "$current_branch" = "master" ]; then
                alt_branch="main"
            else
                alt_branch="master"
            fi
            write_info "Пробую ветку $alt_branch..."
            pull_output=$(git -C "$DonorPath" pull origin "$alt_branch" 2>&1)
            if [ $? -eq 0 ]; then
                write_success "Донор успешно обновлен (ветка $alt_branch)"
            else
                write_warning "Не удалось обновить донор. Продолжаем с текущими файлами."
            fi
        else
            write_success "Донор успешно обновлен"
        fi
    else
        write_warning "Обновление донора пропущено"
    fi
fi

echo ""
write_color_step "Копирую файлы из репозитория донора..." 3
write_info "Из: $DonorPath"
write_info "В:  $RecipPath"

# Убеждаемся, что папка назначения существует
ensure_dir "$RecipPath"

# Копируем файлы (исключая .git)
file_count=0
dir_count=0
error_count=0

# Используем rsync если доступен, иначе cp
if command -v rsync &> /dev/null; then
    # rsync более эффективен для копирования
    rsync -av --exclude='.git' --exclude='.github' "$DonorPath/" "$RecipPath/" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        # Подсчитываем скопированные файлы
        file_count=$(find "$DonorPath" -type f -not -path "*/.git/*" -not -path "*/.github/*" | wc -l)
        dir_count=$(find "$DonorPath" -type d -not -path "*/.git/*" -not -path "*/.github/*" | wc -l)
        write_success "Скопировано через rsync"
    else
        write_warning "Ошибка при копировании через rsync, используем cp"
        # Падаем на cp
        command -v rsync &> /dev/null || true
    fi
fi

if ! command -v rsync &> /dev/null || [ $? -ne 0 ]; then
    # Копируем через cp
    for item in "$DonorPath"/* "$DonorPath"/.[!.]*; do
        # Пропускаем .git и .github
        if [[ "$item" == *"/.git"* ]] || [[ "$item" == *"/.github"* ]]; then
            continue
        fi

        if [ -e "$item" ]; then
            base_name=$(basename "$item")
            dest_path="$RecipPath/$base_name"

            if [ -d "$item" ]; then
                # Это папка
                cp -rf "$item" "$dest_path" 2>/dev/null
                if [ $? -eq 0 ]; then
                    ((dir_count++))
                    write_info "Папка: $base_name"
                else
                    write_warning "Не удалось скопировать папку: $base_name"
                    ((error_count++))
                fi
            else
                # Это файл
                cp -f "$item" "$dest_path" 2>/dev/null
                if [ $? -eq 0 ]; then
                    ((file_count++))
                    write_info "Файл: $base_name"
                else
                    write_warning "Не удалось скопировать файл: $base_name"
                    ((error_count++))
                fi
            fi
        fi
    done

    write_success "Скопировано: $file_count файлов, $dir_count папок"
    if [ $error_count -gt 0 ]; then
        write_warning "Ошибок при копировании: $error_count"
    fi
fi

echo ""
write_color_step "Перехожу в репозиторий реципиент..." 4
cd "$RecipPath" || exit 1
write_success "Текущая директория: $(pwd)"

echo ""
write_color_step "Добавляю изменения в Git..." 5
git add -A

# Проверяем, есть ли изменения для коммита
status=$(git status --porcelain)
if [ -z "$status" ]; then
    echo ""
    write_info "Нет изменений для коммита"
    echo ""
    echo -e "${CYAN}╔$(printf '═%.0s' {1..39})╗${NC}"
    echo -e "${YELLOW}║     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА     ║${NC}"
    echo -e "${CYAN}╚$(printf '═%.0s' {1..39})╝${NC}"
    read -p $'\nНажмите Enter для выхода'
    exit 0
fi

write_info "Найдены изменения:"
echo "$status" | while read -r line; do
    change_type="${line:0:2}"
    file_name="${line:3}"
    case "$change_type" in
        "M ")
            echo -e "    ${GRAY}📝 Изменен: $file_name${NC}"
            ;;
        "A ")
            echo -e "    ${GRAY}➕ Добавлен: $file_name${NC}"
            ;;
        "D ")
            echo -e "    ${GRAY}❌ Удален: $file_name${NC}"
            ;;
        "R ")
            echo -e "    ${GRAY}🔄 Переименован: $file_name${NC}"
            ;;
        "??")
            echo -e "    ${GRAY}❓ Новый: $file_name${NC}"
            ;;
        *)
            echo -e "    ${GRAY}$change_type $file_name${NC}"
            ;;
    esac
done

echo ""
write_color_step "Создаю коммит..." 6
date_str=$(date +"%d.%m.%Y %H:%M:%S")
commit_msg="Обновление из репозитория донора от $date_str"
git commit -m "$commit_msg"

if [ $? -ne 0 ]; then
    write_error "Не удалось создать коммит"
    read -p $'\nНажмите Enter для выхода'
    exit 1
fi

write_success "Коммит создан: $commit_msg"

echo ""
write_color_step "Отправляю на GitHub..." 7

# Проверяем состояние реципиента
fix_repository "$RecipPath" "$RECIP_URL" "реципиента"

# Определяем текущую ветку
current_branch=$(git branch --show-current)
write_info "Текущая ветка: $current_branch"

# Pull с rebase
write_info "Получаю обновления из удаленного репозитория..."
pull_output=$(git pull origin "$current_branch" --rebase 2>&1)
if [ $? -ne 0 ]; then
    write_warning "Не удалось получить обновления для ветки $current_branch"
    write_info "Пробую альтернативную ветку..."

    if [ "$current_branch" = "master" ]; then
        alt_branch="main"
    else
        alt_branch="master"
    fi

    pull_output=$(git pull origin "$alt_branch" --rebase 2>&1)
    if [ $? -eq 0 ]; then
        write_success "Обновления получены (ветка $alt_branch)"
        current_branch="$alt_branch"
    else
        write_warning "Не удалось получить обновления. Продолжаю с текущей веткой..."
    fi
else
    write_success "Обновления получены"
fi

# Push
write_info "Отправляю изменения..."
push_output=$(git push origin "$current_branch" 2>&1)
if [ $? -ne 0 ]; then
    write_warning "Не удалось отправить в ветку $current_branch"
    write_info "Пробую альтернативную ветку..."

    if [ "$current_branch" = "master" ]; then
        alt_branch="main"
    else
        alt_branch="master"
    fi

    push_output=$(git push origin "$alt_branch" 2>&1)
    if [ $? -ne 0 ]; then
        write_error "Не удалось отправить изменения"
        echo ""
        echo -e "${YELLOW}Возможные решения:${NC}"
        echo -e "  ${GRAY}1. Сделать pull вручную с merge вместо rebase:${NC}"
        echo -e "     git pull origin $current_branch --no-rebase${NC}"
        echo -e "  ${GRAY}2. Проверить конфликты:${NC}"
        echo -e "     git status${NC}"
        echo -e "  ${GRAY}3. Принудительная отправка (если уверены):${NC}"
        echo -e "     git push -f origin $current_branch${NC}"
    else
        write_success "Изменения отправлены на GitHub (ветка $alt_branch)"
    fi
else
    write_success "Изменения отправлены на GitHub (ветка $current_branch)"
fi

# Показываем статистику
echo ""
write_info "Статистика синхронизации:"
write_info "  Донор: $DONOR_URL"
write_info "  Реципиент: $RECIP_URL"
commit_hash=$(git rev-parse --short HEAD)
write_info "  Последний коммит: $commit_hash"

echo ""
echo -e "${CYAN}╔$(printf '═%.0s' {1..39})╗${NC}"
echo -e "${YELLOW}║     СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА     ║${NC}"
echo -e "${CYAN}╚$(printf '═%.0s' {1..39})╝${NC}"
read -p $'\nНажмите Enter для выхода'