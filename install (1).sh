#!/usr/bin/env bash
# WG PANEL installer - Ubuntu 22.04/24.04 and Debian 11/12
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PANEL=/var/www/pterodactyl
WINGS_OK=1
G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; N='\033[0m'
say(){ echo -e "${G}==>${N} $*" >&2; }
warn(){ echo -e "${Y}!!${N} $*" >&2; }
die(){ echo -e "${R}ERROR:${N} $*" >&2; exit 1; }
trap 'die "Failed at line $LINENO"' ERR
[ "$EUID" -eq 0 ] || die "Run as root:  sudo bash install.sh"
ask(){ local v; read -rp "$1${2:+ [$2]}: " v; echo "${v:-$2}"; }
askpw(){ local a b; while :; do read -rsp "$1: " a; echo >&2; read -rsp "Confirm password: " b; echo >&2
  [ "${#a}" -ge 8 ] && [ "$a" = "$b" ] && { echo "$a"; return; }; warn "Passwords must match and be 8+ characters."; done; }
rand(){ tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-24}"; }
setenv(){ if grep -q "^$1=" $PANEL/.env; then sed -i "s|^$1=.*|$1=$2|" $PANEL/.env; else echo "$1=$2" >> $PANEL/.env; fi; }
# ---------- service layer: works with systemd AND without it (containers / LXC / Docker) ----------
SYSD=0; [ "$(cat /proc/1/comm 2>/dev/null)" = systemd ] && SYSD=1
svc_start(){ for n in "$@"; do if [ $SYSD = 1 ]; then systemctl enable --now "$n" >/dev/null 2>&1 || true; else service "$n" start >/dev/null 2>&1 || true; fi; done; }
svc_restart(){ for n in "$@"; do if [ $SYSD = 1 ]; then systemctl restart "$n" >/dev/null 2>&1 || true; else service "$n" restart >/dev/null 2>&1 || true; fi; done; }
supervisor_up(){ pgrep -x supervisord >/dev/null || { mkdir -p /var/log/supervisor; supervisord -c /etc/supervisor/supervisord.conf; sleep 2; }; }
add_daemon(){ # name "command" [user] [workdir]
  local n=$1 c=$2 u=${3:-root} w=${4:-/}
  if [ $SYSD = 1 ]; then
    cat >/etc/systemd/system/$n.service <<S
[Unit]
Description=WG PANEL $n
After=network-online.target docker.service redis-server.service
[Service]
User=$u
WorkingDirectory=$w
ExecStart=$c
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
S
    systemctl daemon-reload; systemctl enable --now "$n" >/dev/null 2>&1 || true
  else
    cat >/etc/supervisor/conf.d/$n.conf <<S
[program:$n]
command=$c
user=$u
directory=$w
autorestart=true
startretries=20
stdout_logfile=/var/log/$n.log
redirect_stderr=true
S
    supervisor_up; supervisorctl reread >/dev/null; supervisorctl update >/dev/null
  fi
}
rm_daemon(){ for n in "$@"; do if [ $SYSD = 1 ]; then systemctl disable --now "$n" >/dev/null 2>&1 || true; rm -f /etc/systemd/system/$n.service
  else supervisorctl stop "$n" >/dev/null 2>&1 || true; rm -f /etc/supervisor/conf.d/$n.conf; fi; done; }
reload_nginx(){ nginx -t >/dev/null && { nginx -s reload 2>/dev/null || svc_start nginx; }; }
write_wg_start(){ # used after a container restart when there is no systemd
  cat >/usr/local/bin/wg-start <<'S'
#!/usr/bin/env bash
# Start every WG PANEL service (needed after a container/LXC restart)
mkdir -p /run/mysqld /run/php; chown mysql:mysql /run/mysqld 2>/dev/null
for s in mariadb redis-server php8.3-fpm cron nginx; do service $s start >/dev/null 2>&1; done
pgrep -x supervisord >/dev/null || supervisord -c /etc/supervisor/supervisord.conf
command -v dockerd >/dev/null && ! docker info >/dev/null 2>&1 && (service docker start >/dev/null 2>&1 || (nohup dockerd >/var/log/dockerd.log 2>&1 &))
echo "WG PANEL services started."
S
  chmod +x /usr/local/bin/wg-start
}
ARCH=$(dpkg --print-architecture); case $ARCH in amd64) WARCH=amd64;; arm64) WARCH=arm64;; *) die "Unsupported CPU: $ARCH";; esac
. /etc/os-release; OSID=$ID
case "$OSID" in ubuntu|debian) ;; *) die "Unsupported OS: $PRETTY_NAME. WG PANEL needs a fresh Ubuntu 22.04/24.04 or Debian 11/12 server (Kali, Mint, Arch etc. will not work).";; esac

banner(){ clear; cat <<'B'
 __        __  ____     ____   _    _   _ _____ _
 \ \      / / / ___|   |  _ \ / \  | \ | | ____| |
  \ \ /\ / / | |  _    | |_) / _ \ |  \| |  _| | |
   \ V  V /  | |_| |   |  __/ ___ \| |\  | |___| |___
    \_/\_/    \____|   |_| /_/   \_\_| \_|_____|_____|
B
echo; }

# ---------- questions ----------
gather_panel(){
  echo "How will people open your panel?"
  echo "  1) I have a domain (free SSL certificate)"
  echo "  2) No domain - give me a free xxxx.trycloudflare.com link"
  echo "  3) No domain - use my server IP (http only)"
  while :; do MODE=$(ask "Choose 1-3" 2); [[ $MODE =~ ^[123]$ ]] && break; done
  if [ "$MODE" = 1 ]; then DOMAIN=$(ask "Domain (already pointed to this server, e.g. panel.example.com)"); [ -n "$DOMAIN" ] || die "Domain required"; fi
  echo; echo "Create the admin account:"
  ADMIN_EMAIL=$(ask "Admin email"); ADMIN_USER=$(ask "Admin username" admin)
  ADMIN_FIRST=$(ask "First name"); ADMIN_LAST=$(ask "Last name"); ADMIN_PASS=$(askpw "Admin password (8+ chars)")
  echo; echo "Summary: mode=$MODE ${DOMAIN:+domain=$DOMAIN} user=$ADMIN_USER email=$ADMIN_EMAIL"
  [[ $(ask "Continue installation? (y/n)" y) =~ ^[Yy] ]] || exit 0
}

# ---------- helpers ----------
base_pkgs(){
  say "Installing base packages"; export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq; apt-get install -y -qq curl ca-certificates gnupg lsb-release unzip git tar software-properties-common apt-transport-https >/dev/null
}
install_cloudflared(){
  command -v cloudflared >/dev/null && return
  curl -fsSLo /tmp/cf.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH.deb"; dpkg -i /tmp/cf.deb >/dev/null
}
make_tunnel(){ # name port -> prints URL
  local n=$1 p=$2 log=/var/log/wg-tunnel-$1.log u=""; : > "$log"
  add_daemon wg-tunnel-$n "/usr/bin/cloudflared tunnel --no-autoupdate --url http://localhost:$p --logfile $log"
  for _ in $(seq 1 45); do u=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$log" | head -1 || true); [ -n "$u" ] && { echo "$u"; return; }; sleep 2; done
  die "Could not get a trycloudflare.com link (check /var/log/wg-tunnel-$n.log)"
}

# ---------- panel ----------
install_panel(){
  base_pkgs
  say "Adding PHP repository"
  if [ "$OSID" = ubuntu ]; then add-apt-repository -y ppa:ondrej/php >/dev/null
  else curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury.gpg --yes
       echo "deb [signed-by=/usr/share/keyrings/sury.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" >/etc/apt/sources.list.d/sury.list; fi
  apt-get update -qq
  say "Installing PHP, MariaDB, Redis, Nginx (a few minutes)"
  [ $SYSD = 1 ] || { warn "No systemd detected (container/LXC). Using COMPATIBILITY MODE."; printf '#!/bin/sh\nexit 101\n' >/usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d; mkdir -p /run/mysqld /run/php; }
  apt-get install -y php8.3 php8.3-{cli,fpm,common,mysql,mbstring,bcmath,xml,curl,zip,gd,intl,redis} || { dpkg --configure -a || true; die "PHP install failed - read the lines above this message"; }
  apt-get install -y mariadb-server nginx redis-server cron certbot python3-certbot-nginx supervisor || { dpkg --configure -a || true; die "MariaDB/Nginx/Redis install failed - read the lines above this message"; }
  rm -f /usr/sbin/policy-rc.d; chown mysql:mysql /run/mysqld 2>/dev/null || true
  svc_start mariadb redis-server php8.3-fpm cron nginx
  [ $SYSD = 1 ] || { write_wg_start; supervisor_up; }
  for _ in $(seq 1 20); do mysqladmin ping >/dev/null 2>&1 && break; sleep 1; done
  mysqladmin ping >/dev/null 2>&1 || die "MariaDB did not start. Try: service mariadb start ; then run install.sh again"
  curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer >/dev/null

  say "Downloading panel"
  mkdir -p $PANEL; cd $PANEL
  curl -fsSL https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz | tar -xz
  chmod -R 755 storage/* bootstrap/cache; cp -n .env.example .env
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction -q
  php artisan key:generate --force >/dev/null

  say "Creating database"
  DBPASS=$(rand 28)
  mysql -e "CREATE DATABASE IF NOT EXISTS panel; CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASS'; ALTER USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '$DBPASS'; GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; FLUSH PRIVILEGES;"

  # panel URL
  case $MODE in
    1) APP_URL="https://$DOMAIN"; SERVER_NAME=$DOMAIN;;
    2) say "Creating your free trycloudflare.com link"; install_cloudflared; APP_URL=$(make_tunnel panel 80); SERVER_NAME=_;;
    3) IP=$(curl -4fsS https://ifconfig.me); APP_URL="http://$IP"; SERVER_NAME=_;;
  esac

  say "Configuring panel"
  php artisan p:environment:setup --author="$ADMIN_EMAIL" --url="$APP_URL" --timezone=UTC --cache=redis --session=redis --queue=redis \
    --redis-host=127.0.0.1 --redis-pass=null --redis-port=6379 --settings-ui=true --telemetry=false --no-interaction >/dev/null
  php artisan p:environment:database --host=127.0.0.1 --port=3306 --database=panel --username=pterodactyl --password="$DBPASS" --no-interaction >/dev/null
  setenv TRUSTED_PROXIES '*'
  php artisan migrate --seed --force >/dev/null
  php artisan p:user:make --email="$ADMIN_EMAIL" --username="$ADMIN_USER" --name-first="$ADMIN_FIRST" --name-last="$ADMIN_LAST" --password="$ADMIN_PASS" --admin=1 >/dev/null

  # cron + queue worker
  (crontab -l 2>/dev/null | grep -v 'pterodactyl/artisan'; echo "* * * * * php $PANEL/artisan schedule:run >> /dev/null 2>&1") | crontab -
  add_daemon pteroq "/usr/bin/php $PANEL/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3" www-data "$PANEL"
  # nginx
  rm -f /etc/nginx/sites-enabled/default
  cat >/etc/nginx/sites-available/wg-panel.conf <<S
server {
  listen 80; server_name $SERVER_NAME;
  root $PANEL/public; index index.php;
  client_max_body_size 100m;
  location / { try_files \$uri \$uri/ /index.php?\$query_string; }
  location ~ \.php\$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)\$;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock; fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    fastcgi_param PHP_VALUE "upload_max_filesize=100M \n post_max_size=100M";
  }
  location ~ /\.ht { deny all; }
}
S
  ln -sf /etc/nginx/sites-available/wg-panel.conf /etc/nginx/sites-enabled/wg-panel.conf
  reload_nginx
  if [ "$MODE" = 1 ]; then say "Getting SSL certificate"
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" --redirect || warn "SSL failed - is the domain pointed to this server? Re-run: certbot --nginx -d $DOMAIN"; fi

  apply_theme
  chown -R www-data:www-data $PANEL/*
  git clone --depth 1 -q https://github.com/parkervcp/eggs /opt/wg-eggs 2>/dev/null || true
  say "Panel installed: $APP_URL"
}

# ---------- theme / register ----------
apply_theme(){
  say "Applying WG PANEL theme + register page"
  cd $PANEL; mkdir -p public/wg
  cp "$DIR/assets/tiger.jpg" "$DIR/theme/wg.css" "$DIR/theme/wg.js" public/wg/
  [ -f public/wg/colors.css ] || echo ':root{}' > public/wg/colors.css
  cp "$DIR/patches/WgRegisterController.php" app/Http/Controllers/Auth/
  cp "$DIR/patches/WgThemeController.php" app/Http/Controllers/Admin/
  mkdir -p resources/views/wg
  cp "$DIR/patches/views/register.blade.php" resources/views/wg/
  cp "$DIR/patches/views/wg-theme.blade.php" resources/views/admin/
  grep -q WgRegisterController routes/auth.php || cat >> routes/auth.php <<'S'

Route::get('/register', [\Pterodactyl\Http\Controllers\Auth\WgRegisterController::class, 'show']);
Route::post('/register', [\Pterodactyl\Http\Controllers\Auth\WgRegisterController::class, 'store'])->middleware('throttle:10,1');
S
  grep -q WgThemeController routes/admin.php || cat >> routes/admin.php <<'S'

Route::get('/wg-theme', [\Pterodactyl\Http\Controllers\Admin\WgThemeController::class, 'show']);
Route::post('/wg-theme', [\Pterodactyl\Http\Controllers\Admin\WgThemeController::class, 'save']);
S
  local tag='<link rel="stylesheet" href="/wg/wg.css"><link rel="stylesheet" href="/wg/colors.css"><script defer src="/wg/wg.js"></script>'
  for f in resources/views/templates/wrapper.blade.php resources/views/layouts/admin.blade.php; do
    grep -q '/wg/wg.css' "$f" || sed -i "s#</head>#$tag</head>#" "$f"; done
  setenv APP_NAME '"WG PANEL"'
  php artisan view:clear >/dev/null; php artisan config:clear >/dev/null; php artisan route:clear >/dev/null
  chown -R www-data:www-data $PANEL/public/wg
}

# ---------- node / wings ----------
create_node(){
  cd $PANEL
  say "Creating default location and node"
  php artisan p:location:make --short=main --long="WG Main Location" >/dev/null
  LOC=$(mysql -N -e "select id from panel.locations order by id limit 1")
  case $MODE in
    1) FQDN=$DOMAIN; SCHEME=https; PROXY=0; DPORT=8080;;
    2) WURL=$(make_tunnel wings 8080); FQDN=${WURL#https://}; SCHEME=https; PROXY=1; DPORT=443;;
    3) FQDN=$(curl -4fsS https://ifconfig.me); SCHEME=http; PROXY=0; DPORT=8080;;
  esac
  MEM=$(awk '/MemTotal/{printf "%d",$2/1024*0.9}' /proc/meminfo)
  DISK=$(df -BM --output=avail /var/lib | tail -1 | tr -dc 0-9); DISK=$((DISK*9/10))
  php artisan p:node:make --name="WG Node 1" --description="Auto-created by WG PANEL" --locationId="$LOC" --fqdn="$FQDN" --public=1 \
    --scheme="$SCHEME" --proxy="$PROXY" --maxMemory="$MEM" --overallocateMemory=0 --maxDisk="$DISK" --overallocateDisk=0 \
    --uploadSize=100 --daemonListeningPort="$DPORT" --daemonSFTPPort=2022 --daemonBase=/var/lib/pterodactyl/volumes --no-interaction >/dev/null
  NODE=$(mysql -N -e "select id from panel.nodes order by id limit 1")
  say "Adding default ports (admins can edit them in Admin > Nodes > Allocation)"
  for p in $(seq 25565 25580) $(seq 3000 3010); do mysql -e "INSERT INTO panel.allocations (node_id,ip,port,created_at,updated_at) VALUES ($NODE,'0.0.0.0',$p,NOW(),NOW())"; done
}
install_wings_bin(){
  say "Installing Docker + Wings"
  command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh >/dev/null 2>&1 || true
  if [ $SYSD = 1 ]; then systemctl enable --now docker >/dev/null 2>&1 || true
  else service docker start >/dev/null 2>&1 || { nohup dockerd >/var/log/dockerd.log 2>&1 & sleep 8; }; fi
  if ! docker info >/dev/null 2>&1; then
    warn "Docker cannot run on this server (container/LXC without nesting, or no privileges)."
    warn "The panel still works. Wings (game servers) must run on another server that supports Docker."
    warn "Add that server later: Admin > Nodes. Skipping Wings here."; WINGS_OK=0; return 1
  fi
  WINGS_OK=1
  mkdir -p /etc/pterodactyl /var/lib/pterodactyl/volumes
  curl -fsSLo /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$WARCH"; chmod +x /usr/local/bin/wings
  add_daemon wings "/usr/local/bin/wings" root /etc/pterodactyl
  [ $SYSD = 1 ] || { supervisorctl stop wings >/dev/null 2>&1 || true; }   # started after config exists
}
wings_local(){ # same server as panel
  install_wings_bin || return 0; cd $PANEL
  php artisan p:node:configuration "$NODE" > /etc/pterodactyl/config.yml
  if [ "$MODE" = 2 ]; then sed -i -E 's/^(\s+port:) 443/\1 8080/; /ssl:/,/key:/ s/enabled: true/enabled: false/' /etc/pterodactyl/config.yml; fi
  if [ $SYSD = 1 ]; then systemctl restart wings >/dev/null 2>&1; else supervisorctl start wings >/dev/null 2>&1; fi; say "Wings running"
}
wings_remote(){
  install_wings_bin || die "Docker is required for Wings. Use a KVM VPS (or an LXC with nesting enabled)."
  echo; echo "In your panel go to: Admin > Nodes > (your node) > Configuration > 'Generate Token',"
  echo "then paste the full command it shows (starts with: cd /etc/pterodactyl && sudo wings configure ...)"
  CMD=$(ask "Paste command"); [[ $CMD == *"wings configure"* ]] || die "That doesn't look like the configure command"
  bash -c "$CMD"; if [ $SYSD = 1 ]; then systemctl restart wings >/dev/null 2>&1; else supervisorctl start wings >/dev/null 2>&1; fi; say "Wings running"
}

uninstall_all(){
  warn "This DELETES the panel, database, wings config and tunnels. Server data in /var/lib/pterodactyl is kept."
  [ "$(ask "Type 'yes' to continue" no)" = yes ] || exit 0
  rm_daemon pteroq wings wg-tunnel-panel wg-tunnel-wings
  rm -f /etc/nginx/sites-enabled/wg-panel.conf /etc/nginx/sites-available/wg-panel.conf /usr/local/bin/wings
  rm -rf $PANEL /etc/pterodactyl; mysql -e "DROP DATABASE IF EXISTS panel; DROP USER IF EXISTS 'pterodactyl'@'127.0.0.1';" 2>/dev/null || true
  [ $SYSD = 1 ] && systemctl daemon-reload; reload_nginx || true; say "Uninstalled."
}

summary(){ echo; echo -e "${G}=========== WG PANEL READY ===========${N}"; echo " URL:      $APP_URL"; echo " Username: $ADMIN_USER"; echo " Register: $APP_URL/auth/register"
  [ $SYSD = 1 ] || warn "Compatibility mode: after a container restart run  wg-start  to bring everything back up."
  [ "$MODE" = 2 ] && warn "Free trycloudflare links change if the server/tunnel restarts. For a permanent link use a domain."; echo; }

banner
echo "  1) Install Panel"
echo "  2) Install Wings only (this server will be a node for another panel)"
echo "  3) Install Panel + Wings on this server (recommended)"
echo "  4) Uninstall"
echo "  5) Re-apply WG theme / update theme files"
echo
CH=$(ask "Choose 1-5" 3)
case $CH in
  1) gather_panel; install_panel; summary;;
  2) base_pkgs; wings_remote;;
  3) gather_panel; install_panel; create_node; wings_local; summary;;
  4) uninstall_all;;
  5) apply_theme; chown -R www-data:www-data $PANEL; say "Done";;
  *) die "Invalid choice";;
esac
