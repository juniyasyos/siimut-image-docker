stikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
	  echo "Harap jalankan script ini sebagai root."
	    exit 1
fi

echo "🔄 Update sistem..."
apt update && apt upgrade -y

echo "🧰 Install dependensi umum..."
apt install -y software-properties-common curl gnupg2 unzip lsb-release ca-certificates apt-transport-https

echo "📦 Menambahkan repository PHP 8.4..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "⬇️ Menginstall PHP 8.4 dan ekstensi untuk Laravel..."
apt install -y php8.4 php8.4-cli php8.4-common php8.4-mbstring php8.4-xml php8.4-bcmath php8.4-curl php8.4-mysql php8.4-zip php8.4-gd php8.4-readline php8.4-soap php8.4-intl

echo "🔍 Mengecek versi PHP..."
php8.4 -v

echo "📦 Menginstall Composer (PHP package manager)..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

echo "🔍 Mengecek versi Composer..."
composer -V

echo "⬇️ Menginstall Node.js LTS dan npm..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

echo "🔍 Mengecek versi Node dan NPM..."
node -v
npm -v

echo "🌱 Menginstall Vue CLI..."
npm install -g @vue/cli

echo "🔍 Mengecek versi Vue CLI..."
vue --version

echo "🛢️ Menginstall MySQL Server..."
DEBIAN_FRONTEND=noninteractive apt install -y mysql-server

echo "🚀 Menjalankan dan mengaktifkan MySQL..."
systemctl start mysql
systemctl enable mysql

echo "🔒 Membuat user MySQL 'juni' dengan password 'password'..."
mysql -u root <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS 'juni'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'juni'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "✅ User 'juni' berhasil dibuat dan diberi akses penuh ke MySQL."

echo "📂 Membuat direktori project Laravel (opsional)..."
mkdir -p /var/www/laravel_project
chown -R $SUDO_USER:$SUDO_USER /var/www/laravel_project

echo "📦 Instalasi stack Laravel + Vue + MySQL selesai."
echo "👉 Langkah selanjutnya: cd /var/www/laravel_project && composer create-project laravel/laravel ."

