#!/bin/sh
set -e

# --- Цветовые настройки ---
C_HEAD='\033[1;36m'  # Жирный бирюзовый (Cyan)
C_WARN='\033[1;31m'  # Жирный красный
C_OK='\033[1;32m'    # Жирный зеленый
C_INFO='\033[1;33m'  # Желтый
C_RESET='\033[0m'    # Сброс цвета
# --------------------------

DRY_RUN=1
OWUT_ARGS=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        run|--run) DRY_RUN=0; shift ;;
        *) OWUT_ARGS="$OWUT_ARGS $1"; shift ;;
    esac
done

if [ "$DRY_RUN" -eq 1 ]; then
    echo -e "\n${C_HEAD}========== START HYBRID UPGRADE (DRY RUN MODE) ==========${C_RESET}"
    echo "ℹ️ This is a safe test. No system files will be modified."
    echo -e "ℹ️ Extra target parameters: ${C_INFO}${OWUT_ARGS:-Auto (Current version)}${C_RESET}"
else
    echo -e "\n${C_WARN}========== START HYBRID UPGRADE (REAL RUN) ==========${C_RESET}"
    echo -e "${C_WARN}⚠️ WARNING: Destructive operations enabled!${C_RESET}"
fi
date

WORKDIR="/root/upgrade-momo"
PKG_DIR="$WORKDIR/pkgs"
CONF_BACKUP="$WORKDIR/config_backup"
USER_DATA_DIR="/root/my_data"
SCRIPT_PATH="$USER_DATA_DIR/upgrade-momo.sh"

mkdir -p $PKG_DIR $CONF_BACKUP $USER_DATA_DIR

echo -e "\n${C_HEAD}=== 1. Package list for offline backup ===${C_RESET}"
PKGS="sing-box momo luci-app-momo"
echo "Packages: $PKGS"

echo -e "\n${C_HEAD}=== 2. Update repositories ===${C_RESET}"
apk update

echo -e "\n${C_HEAD}=== 3. Ensure owut is installed ===${C_RESET}"
if ! command -v owut >/dev/null 2>&1; then
    echo "⚙️ Installing owut..."
    apk add owut || { echo -e "${C_WARN}ERROR: owut missing${C_RESET}"; exit 1; }
fi

echo -e "\n${C_HEAD}=== 4. Fetch custom APKs for offline backup ===${C_RESET}"
cd $PKG_DIR
rm -f *.apk
apk fetch --output $PKG_DIR $PKGS || { echo -e "${C_WARN}ERROR: Failed to fetch packages${C_RESET}"; exit 1; }
APK_COUNT=$(ls -1 *.apk 2>/dev/null | wc -l)
echo "✅ Offline backup complete. $APK_COUNT files ready."

echo -e "\n${C_HEAD}=== 5. Backup Momo configs & keys ===${C_RESET}"
rm -rf $CONF_BACKUP/momo_dir
cp -p /etc/config/momo $CONF_BACKUP/momo_config 2>/dev/null || true
cp -rp /etc/momo $CONF_BACKUP/momo_dir 2>/dev/null || true
cp -p /etc/apk/keys/momo.pem $CONF_BACKUP/momo.pem 2>/dev/null || true

echo -e "\n${C_HEAD}=== 6. Protect files during sysupgrade ===${C_RESET}"
if [ "$DRY_RUN" -eq 0 ]; then
    for path in \
        "$WORKDIR" \
        "$USER_DATA_DIR" \
        "/etc/apk/keys/momo.pem" \
        "$SCRIPT_PATH" \
        "/etc/hotplug.d/dhcp/90-telegram-notify" \
        "/etc/mac_whitelist.txt" \
        "/etc/zabbix_agentd.conf" \
        "/root/.profile" \
        "/etc/ssl/acme" \
        "/etc/nftables.d/99-block-quic.nft"
    do
        if [ -e "$path" ]; then
            grep -qxF "$path" /etc/sysupgrade.conf || echo "$path" >> /etc/sysupgrade.conf
        fi
    done
    echo "✅ Files, keys, hotplug scripts, certs, and QUIC block rules protected."
fi

echo -e "\n${C_HEAD}=== 7. Prepare uci-defaults restore script ===${C_RESET}"
if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p /etc/uci-defaults
    cat << 'EOF' > /etc/uci-defaults/99-momo-restore
#!/bin/sh

(
    trap "" HUP
    sleep 20

    LOG="/root/my_data/post-upgrade.log"
    PKG_DIR="/root/upgrade-momo/pkgs"
    CONF_BACKUP="/root/upgrade-momo/config_backup"

    {
        echo "========== POST UPGRADE START $(date) =========="
        
        echo "[1/6] Restoring configs..."
        cp -p $CONF_BACKUP/momo.pem /etc/apk/keys/momo.pem 2>/dev/null || true
        cp -p $CONF_BACKUP/momo_config /etc/config/momo 2>/dev/null || true
        rm -rf /etc/momo
        cp -rp $CONF_BACKUP/momo_dir /etc/momo 2>/dev/null || true

        echo "[2/6] Fixing cert timestamps..."
        touch -h -t 202603230013.51 /etc/ssl/acme/luci.rinat.top.* 2>/dev/null || true

        echo "[3/6] Updating apk indices..."
        apk update || true

        echo "[4/6] Installing Custom Momo (Offline)..."
        if ls $PKG_DIR/*.apk >/dev/null 2>&1; then
            apk add --allow-untrusted $PKG_DIR/*.apk
        fi

        echo "[5/6] Cleaning up .apk-new garbage..."
        rm -f /etc/config/momo.apk-new
        find /etc/momo -type f -name "*.apk-new" -exec rm -f {} \; 2>/dev/null || true

        echo "[6/6] Starting Momo..."
        /etc/init.d/momo enable || true
        /etc/init.d/momo start || true
        
        echo "========== POST UPGRADE DONE $(date) =========="
    } > "$LOG" 2>&1
) </dev/null >/dev/null 2>&1 &

exit 0
EOF
    chmod +x /etc/uci-defaults/99-momo-restore
    grep -qxF "/etc/uci-defaults/99-momo-restore" /etc/sysupgrade.conf || echo "/etc/uci-defaults/99-momo-restore" >> /etc/sysupgrade.conf
    echo "✅ Restore script injected."
fi

echo -e "\n${C_HEAD}=== 8. Hide unofficial packages from ASU ===${C_RESET}"
if [ "$DRY_RUN" -eq 0 ]; then
    apk del $PKGS || true
    echo "✅ Custom packages removed locally."
fi

echo -e "\n${C_HEAD}=== 9. ATTENDED SYSUPGRADE (OWUT) ===${C_RESET}"
if [ "$DRY_RUN" -eq 1 ]; then
    owut check -r "$PKGS" --ignored-defaults "wpad-basic-mbedtls" --force $OWUT_ARGS || true
    echo -e "\n${C_OK}========== DRY RUN COMPLETE ==========${C_RESET}"
    echo "To execute real upgrade, run: $SCRIPT_PATH run $OWUT_ARGS"
else
    echo -e "${C_WARN}WARNING: Building firmware...${C_RESET}"
    owut upgrade --ignored-defaults "wpad-basic-mbedtls" --force $OWUT_ARGS
fi
