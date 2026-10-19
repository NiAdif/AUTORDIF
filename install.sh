#!/data/data/com.termux/files/usr/bin/bash

echo "===================================================="
echo "         AUTORDIF INSTALLER & SETUP WIZARD          "
echo "===================================================="

# 1. Pastikan storan Termux dibenarkan (jika perlu) & update repositori
echo "[*] Mengemas kini senarai repositori sistem Termux..."
pkg update -y

# 2. Paksa upgrade pakej asas untuk elak ralat konflik libcurl/openssl
echo "[*] Menaik taraf pakej teras Termux..."
pkg upgrade -y --force-yes

# 3. Pasang semua pakej penting yang diperlukan oleh skrip & peranti
echo "[*] Memasang pakej keperluan (curl, termux-tools, termux-api)..."
pkg install curl termux-tools termux-api -y

# 4. Muat turun fail utama autordif.sh dari GitHub
echo "[*] Memuat turun fail utama autordif.sh..."
INSTALL_DIR="$HOME/.autordif"
mkdir -p "$INSTALL_DIR"

AUTORDIF_URL="https://raw.githubusercontent.com/NiAdif/Autordif/main/autordif.sh"

curl -s -o "$INSTALL_DIR/autordif.sh" "$AUTORDIF_URL"
chmod +x "$INSTALL_DIR/autordif.sh"

# 5. Buat jalan pintas (shortcut) terminal 'autordif'
echo "[*] Menyediakan jalan pintas terminal..."
echo "bash $INSTALL_DIR/autordif.sh" > "$PREFIX/bin/autordif"
chmod +x "$PREFIX/bin/autordif"

echo "===================================================="
echo " [+] PEMASANGAN BERJAYA SEPENUHNYA!"
echo " [+] Sekarang anda boleh taip 'autordif' pada bila-bila masa"
echo "===================================================="
sleep 2

# 6. Terus lancarkan skrip
bash "$INSTALL_DIR/autordif.sh"
