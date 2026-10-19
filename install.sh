#!/data/data/com.termux/files/usr/bin/bash

echo "===================================================="
echo "         AUTORDIF INSTALLER & SETUP WIZARD          "
echo "===================================================="

# 1. Kemaskini dan pasang keperluan asas (curl, termux-api, dll)
echo "[*] Memeriksa dan memasang pakej yang diperlukan (curl, termux-tools)..."
pkg update -y >/dev/null 2>&1
pkg install curl termux-tools -y >/dev/null 2>&1

# 2. Muat turun fail utama autordif.sh dari GitHub/Gist
echo "[*] Memuat turun fail utama autordif.sh..."
INSTALL_DIR="$HOME/.autordif"
mkdir -p "$INSTALL_DIR"

# Gantikan URL di bawah dengan "raw link" fail autordif.sh kau yang sebenar nanti
AUTORDIF_URL="https://raw.githubusercontent.com/username/repo/main/autordif.sh"

curl -s -o "$INSTALL_DIR/autordif.sh" "$AUTORDIF_URL"
chmod +x "$INSTALL_DIR/autordif.sh"

# 3. Buat jalan pintas (shortcut) supaya senang buka guna satu perkataan 'autordif'
echo "[*] Menyediakan jalan pintas terminal..."
echo "bash $INSTALL_DIR/autordif.sh" > "$PREFIX/bin/autordif"
chmod +x "$PREFIX/bin/autordif"

echo "===================================================="
echo " [+] PEMASANGAN BERJAYA!"
echo " [+] Sekarang anda boleh taip 'autordif' pada bila-bila masa"
echo "===================================================="
sleep 2

# 4. Terus lancarkan skrip
bash "$INSTALL_DIR/autordif.sh"
