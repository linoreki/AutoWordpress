#!/bin/bash

# Comprobación de permisos
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta el script como usuario root."
  exit 1
fi

# Variables configurables

read -p "Puerto en el que hostear wordpress (por defecto: 80): " HOST_PORT
HOST_PORT=${HOST_PORT:-80}
read -p "Versión de PHP requerida (por defecto: 8.1): " PHP_VERSION
PHP_VERSION=${PHP_VERSION:-8.1}
read -p "Introduce el nombre de la base de datos para WordPress: " DB_NAME
read -p "Introduce el nombre del usuario de la base de datos: " DB_USER
read -sp "Introduce la contraseña para el usuario de la base de datos: " DB_PASSWORD
echo
read -p "Introduce el dominio o IP para acceder al sitio web: " SITE_DOMAIN

# Actualizar el sistema
echo "Actualizando paquetes del sistema..."
apt update && apt upgrade -y

# Instalar Apache
echo "Instalando Apache..."
apt install apache2 -y
systemctl start apache2
systemctl enable apache2

# Instalar PHP y extensiones necesarias
echo "Instalando PHP y extensiones necesarias..."
apt update
apt install -y software-properties-common
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y php$PHP_VERSION libapache2-mod-php$PHP_VERSION \
php$PHP_VERSION-cli php$PHP_VERSION-curl php$PHP_VERSION-xml \
php$PHP_VERSION-mbstring php$PHP_VERSION-zip php$PHP_VERSION-mysql \
apache2 git unzip

if [ "$HOST_PORT" -ne 80 ]; then
  echo "=== Configurando Apache para escuchar en el puerto $HOST_PORT ==="
  echo "Listen $HOST_PORT" >> /etc/apache2/ports.conf
fi
# Instalar MySQL
echo "Instalando MySQL..."
apt install mysql-server -y

# Configurar MySQL
echo "Configurando la base de datos MySQL..."
mysql -u root <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "Base de datos configurada: $DB_NAME"
echo "Usuario: $DB_USER"

# Descargar e instalar WordPress
echo "Descargando WordPress..."
wget https://wordpress.org/latest.tar.gz -P /tmp
tar -xvzf /tmp/latest.tar.gz -C /tmp
mv /tmp/wordpress /var/www/html/

# Configurar permisos para WordPress
echo "Configurando permisos..."
chown -R www-data:www-data /var/www/html/wordpress
chmod -R 755 /var/www/html/wordpress

# Configurar Apache
echo "Configurando Apache..."
cat <<EOL > /etc/apache2/sites-available/wordpress.conf
<VirtualHost *:$HOST_PORT>
    ServerAdmin admin@$SITE_DOMAIN
    DocumentRoot /var/www/html/wordpress
    ServerName $SITE_DOMAIN
    <Directory /var/www/html/wordpress>
        AllowOverride All
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOL

a2ensite wordpress
a2enmod rewrite
systemctl restart apache2

# Configuración opcional: Certificado SSL con Certbot
read -p "¿Quieres instalar un certificado SSL con Let's Encrypt? (y/n): " SSL_CHOICE
if [[ "$SSL_CHOICE" == "y" ]]; then
    apt install certbot python3-certbot-apache -y
    certbot --apache -d $SITE_DOMAIN
fi

# Mensaje final
echo "Instalación completada. Accede a http://$SITE_DOMAIN para completar la configuración de WordPress."
echo "Datos de la base de datos:"
echo "  Nombre: $DB_NAME"
echo "  Usuario: $DB_USER"
echo "  Contraseña: $DB_PASSWORD"
echo "Datos de el servidor:"
echo "  Host: $SITE_DOMAIN"
echo "  Puerto: $HOST_PORT"
