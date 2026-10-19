#!/data/data/com.termux/files/usr/bin/bash

echo "===================================================="
echo "         AUTORDIF INSTALLER & SETUP WIZARD          "
echo "===================================================="

# 1. Auto update & upgrade pakej Termux untuk elak ralat libcurl/ssl
echo "[*] Mengemas kini pakej sistem Termux..."
pkg update -y && pkg upgrade -y

# 2. Pasang alatan asas yang diperlukan
echo "[*] Memasang pakej curl dan termux-tools..."
pkg install curl termux-tools -y

# 3. Muat turun fail utama autordif.sh dari GitHub
echo "[*] Memuat turun fail utama autordif.sh..."
INSTALL_DIR="$HOME/.autordif"
mkdir -p "$INSTALL_DIR"

AUTORDIF_URL="https://raw.githubusercontent.com/NiAdif/Autordif/main/autordif.sh"

curl -s -o "$INSTALL_DIR/autordif.sh" "$AUTORDIF_URL"
chmod +x "$INSTALL_DIR/autordif.sh"

# 4. Buat jalan pintas (shortcut) 'autordif'
echo "[*] Menyediakan jalan pintas terminal..."
echo "bash $INSTALL_DIR/autordif.sh" > "$PREFIX/bin/autordif"
chmod +x "$PREFIX/bin/autordif"

echo "===================================================="
echo " [+] PEMASANGAN BERJAYA!"
echo " [+] Sekarang anda boleh taip 'autordif' pada bila-bila masa"
echo "===================================================="
sleep 2

# 5. Terus lancarkan skrip
bash "$INSTALL_DIR/autordif.sh"
