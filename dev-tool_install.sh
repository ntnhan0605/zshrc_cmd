#!/bin/bash

# Đường dẫn cài đặt và tên lệnh mong muốn
BIN_DIR="$HOME/.local/bin"
SCRIPT_PATH="$BIN_DIR/dev-tool"

echo "📥 Bắt đầu cài đặt dev-tool..."

# 1. Tạo thư mục bin nếu chưa có
mkdir -p "$BIN_DIR"

# 2. Ghi nội dung script dev-tool thông minh vào thư mục đích
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

PROJECT_DIR="$1"

if [ -z "$PROJECT_DIR" ]; then
    echo "❌ Lỗi: Vui lòng cung cấp đường dẫn thư mục dự án."
    echo "💡 Sử dụng: dev-tool /duong/dan/tới/project"
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Lỗi: Thư mục '$PROJECT_DIR' không tồn tại."
    exit 1
fi

PROJECT_DIR=$(cd "$PROJECT_DIR" && pwd)
echo "🚀 Đang khởi động môi trường dev cho: $PROJECT_DIR"

open "$PROJECT_DIR"
code "$PROJECT_DIR"

DEV_COMMAND=""
if [ -f "$PROJECT_DIR/package.json" ]; then
    echo "📦 Phát hiện dự án: Node.js / JavaScript"
    DEV_COMMAND="npm run dev"
elif [ -f "$PROJECT_DIR/go.mod" ]; then
    echo "🐹 Phát hiện dự án: Go"
    DEV_COMMAND=$([ -f "$PROJECT_DIR/main.go" ] && echo "go run main.go" || echo "go run .")
elif [ -f "$PROJECT_DIR/Cargo.toml" ]; then
    echo "🦀 Phát hiện dự án: Rust"
    DEV_COMMAND="cargo run"
elif [ -f "$PROJECT_DIR/requirements.txt" ] || [ -f "$PROJECT_DIR/main.py" ] || [ -f "$PROJECT_DIR/app.py" ]; then
    echo "🐍 Phát hiện dự án: Python"
    [ -d "$PROJECT_DIR/venv" ] && DEV_COMMAND="source venv/bin/activate && "
    [ -d "$PROJECT_DIR/.venv" ] && DEV_COMMAND="source .venv/bin/activate && "
    [ -f "$PROJECT_DIR/main.py" ] && DEV_COMMAND="${DEV_COMMAND}python3 main.py" || DEV_COMMAND="${DEV_COMMAND}python3 app.py"
elif ls "$PROJECT_DIR"/*.csproj &>/dev/null || [ -f "$PROJECT_DIR/Program.cs" ]; then
    echo "🔷 Phát hiện dự án: C# / .NET"
    DEV_COMMAND="dotnet run"
elif [ -f "$PROJECT_DIR/Makefile" ]; then
    echo "⚙️ Phát hiện dự án: C/C++ (Makefile)"
    DEV_COMMAND="make dev || make"
elif [ -f "$PROJECT_DIR/main.c" ]; then
    echo "🧱 Phát hiện dự án: C thuần"
    DEV_COMMAND="gcc main.c -o main_app && ./main_app"
else
    echo "❓ Không nhận diện được framework. Mở Terminal trống."
    DEV_COMMAND="clear"
fi

osascript <<INNEREOF
    tell application "Terminal"
        activate
        do script "cd '$PROJECT_DIR' && $DEV_COMMAND"
    end tell
INNEREOF
EOF

# 3. Cấp quyền thực thi cho file script vừa tạo
chmod +x "$SCRIPT_PATH"
echo "✅ Đã tạo cấu trúc file và cấp quyền thực thi tại: $SCRIPT_PATH"

# 4. Tự động nhận diện Shell để cấu hình PATH
CURRENT_SHELL=$(basename "$SHELL")
SHELL_RC=""

if [ "$CURRENT_SHELL" == "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ "$CURRENT_SHELL" == "bash" ]; then
    SHELL_RC="$HOME/.bash_profile"
else
    echo "⚠️ Không xác định được Shell phù hợp (chỉ hỗ trợ zsh/bash). Vui lòng cấu hình $BIN_DIR vào PATH thủ công."
    exit 0
fi

# 5. Kiểm tra xem PATH đã được add vào file cấu hình chưa, nếu chưa thì append vào
if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
    echo -e "\n# Dev-tool CLI path configuration\nexport PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$SHELL_RC"
    echo "📝 Đã thêm cấu hình PATH vào file $SHELL_RC"
else
    echo "ℹ️ Đường dẫn PATH đã được cấu hình trước đó trong $SHELL_RC."
fi

echo "🎉 Cài đặt HOÀN TẤT! Vui lòng chạy lệnh sau để áp dụng thay đổi ngay lập tức:"
echo "👉 source $SHELL_RC"