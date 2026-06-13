#!/bin/bash

# Xác định thư mục cài đặt dựa trên OS
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash)
    BIN_DIR="/usr/local/bin"
    [ ! -w "$BIN_DIR" ] && BIN_DIR="$HOME/bin"
else
    # macOS / Linux
    BIN_DIR="$HOME/.local/bin"
fi

# ĐỔI TÊN COMMAND THÀNH 'dev' Ở ĐÂY
SCRIPT_PATH="$BIN_DIR/dev"
echo "📥 Bắt đầu cài đặt câu lệnh 'dev' đa nền tảng..."
mkdir -p "$BIN_DIR"

# Ghi nội dung script dev
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

PROJECT_DIR="$1"

if [ -z "$PROJECT_DIR" ]; then
    echo "❌ Lỗi: Vui lòng cung cấp đường dẫn thư mục dự án."
    echo "💡 Sử dụng: dev /duong/dan/tới/project"
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Lỗi: Thư mục '$PROJECT_DIR' không tồn tại."
    exit 1
fi

# Chuẩn hóa đường dẫn tuyệt đối
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd -W)
else
    PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
fi

echo "🚀 Đang khởi động môi trường dev cho: $PROJECT_DIR"

# 1. NHẬN DIỆN HỆ ĐIỀU HÀNH
OS_TYPE="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS_TYPE="windows"
fi

# 2. MỞ VS CODE
code "$PROJECT_DIR"

# 3. TỰ ĐỘNG NHẬN DIỆN NGÔN NGỮ ĐỂ LẤY LỆNH RUN
DEV_COMMAND=""
if [ -f "$PROJECT_DIR/package.json" ]; then
    DEV_COMMAND="npm run dev"
elif [ -f "$PROJECT_DIR/go.mod" ]; then
    DEV_COMMAND=$([ -f "$PROJECT_DIR/main.go" ] && echo "go run main.go" || echo "go run .")
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    DEV_COMMAND="cargo run"
elif [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/main.py" ] || [ -f "$PROJECT_DIR/app.py" ]; then
    [ -d "$PROJECT_DIR/venv" ] && DEV_COMMAND="source venv/bin/activate && "
    [ -d "$PROJECT_DIR/.venv" ] && DEV_COMMAND="source .venv/bin/activate && "
    [ -f "$PROJECT_DIR/main.py" ] && DEV_COMMAND="${DEV_COMMAND}python3 main.py" || DEV_COMMAND="${DEV_COMMAND}python3 app.py"
elif ls "$PROJECT_DIR"/*.csproj &>/dev/null || [ -f "$PROJECT_DIR/Program.cs" ]; then
    DEV_COMMAND="dotnet run"
elif [ -f "$PROJECT_DIR/Makefile" ]; then
    DEV_COMMAND="make dev || make"
elif [ -f "$PROJECT_DIR/main.c" ]; then
    DEV_COMMAND="gcc main.c -o main_app && ./main_app"
else
    DEV_COMMAND="clear"
fi

# 4. THỰC THI THEO TỪNG HỆ ĐIỀU HÀNH
case "$OS_TYPE" in
    "macos")
        open "$PROJECT_DIR"
        osascript <<INNEREOF
            tell application "Terminal"
                activate
                do script "cd '$PROJECT_DIR' && $DEV_COMMAND"
            end tell
INNEREOF
        ;;
    "windows")
        explorer.exe "$(echo "$PROJECT_DIR" | sed 's/\//\\/g')"
        start bash -c "cd '$PROJECT_DIR' && echo '⚡ Đang chạy câu lệnh dev...' && $DEV_COMMAND; exec bash"
        ;;
    "linux")
        xdg-open "$PROJECT_DIR" &>/dev/null &
        if command -v gnome-terminal &>/dev/null; then
            gnome-terminal -- bash -c "cd '$PROJECT_DIR' && $DEV_COMMAND; exec bash"
        elif command -v xterm &>/dev/null; then
            xterm -e "cd '$PROJECT_DIR' && $DEV_COMMAND; exec bash"
        else
            echo "⚠️ Không tìm thấy Terminal Emulator phù hợp. Vui lòng tự chạy lệnh dev: $DEV_COMMAND"
        fi
        ;;
    *)
        echo "❌ Hệ điều hành chưa được hỗ trợ mở Terminal tự động."
        ;;
esac
EOF

# Cấp quyền thực thi cho file script
chmod +x "$SCRIPT_PATH"
echo "✅ Đã tạo command line tại: $SCRIPT_PATH"

# 5. CẤU HÌNH BIẾN MÔI TRƯỜNG PATH TỰ ĐỘNG
CURRENT_SHELL=$(basename "$SHELL")
SHELL_RC=""

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    if [ "$CURRENT_SHELL" == "zsh" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ "$CURRENT_SHELL" == "bash" ]; then
        SHELL_RC="$HOME/.bash_profile"
        [ ! -f "$SHELL_RC" ] && SHELL_RC="$HOME/.bashrc"
    fi
fi

if [ ! -z "$SHELL_RC" ]; then
    if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
        echo -e "\n# Dev CLI Path\nexport PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
        echo "📝 Đã thêm cấu hình PATH vào file: $SHELL_RC"
    fi
fi

echo "🎉 CÀI ĐẶT HOÀN TẤT!"
echo "👉 Hãy chạy lệnh này để áp dụng ngay: source $SHELL_RC"