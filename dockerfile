# Use an official PHP image with Apache as the base
FROM php:7.4-apache

# Set environment variables for DVWA configuration
ENV DB_SERVER="db" \
    DB_DATABASE="dvwa" \
    DB_USERNAME="dvwa" \
    DB_PASSWORD="password" \
    DVWA_RECAPTCHA_PUBLIC_KEY="6LeR0hSWAAAAADv_3Kk3s3_C444444444444444444444444444444444444444444" \
    DVWA_RECAPTCHA_PRIVATE_KEY="6LeR0hSWAAAAADv_3Kk3s3_C444444444444444444444444444444444444444444"

# Install necessary system dependencies and PHP extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    unzip \
    mariadb-client \
    # Install PHP extensions required by DVWA
    # php-mysql for database connection
    # php-gd for CAPTCHA images
    # php-xml for XML parsing vulnerabilities
    # php-mbstring for multi-byte string functions
    php-mysql \
    php-gd \
    php-xml \
    php-mbstring \
    && rm -rf /var/lib/apt/lists/*

# Download DVWA source code
# Using a specific release to ensure consistency. You can change this to a different version if needed.
RUN git clone https://github.com/ethicalhack3r/DVWA.git /var/www/html/dvwa

# Configure Apache
# Remove the default Apache index.html
RUN rm /var/www/html/index.html

# Set DVWA as the document root for Apache
# This modifies the default Apache configuration file
RUN sed -i 's!/var/www/html!/var/www/html/dvwa!' /etc/apache2/sites-available/000-default.conf && \
    # Enable Apache rewrite module, often needed for web apps
    a2enmod rewrite

# Configure PHP settings for DVWA
# Copy the default PHP configuration for Apache
COPY --from=php:7.4-apache /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Adjust PHP settings required by DVWA
# allow_url_include is often needed for file inclusion vulnerabilities
# display_errors for debugging (should be off in production)
# short_open_tag for compatibility with some older PHP code
RUN echo "allow_url_include = On" >> /usr/local/etc/php/php.ini && \
    echo "display_errors = On" >> /usr/local/etc/php/php.ini && \
    echo "short_open_tag = On" >> /usr/local/etc/php/php.ini

# Configure DVWA
# Copy the distributed configuration file and rename it
RUN cp /var/www/html/dvwa/config/config.inc.php.dist /var/www/html/dvwa/config/config.inc.php

# Replace placeholders in DVWA's config.inc.php with environment variables
# This allows dynamic configuration via Docker environment variables
RUN sed -i "s/\$DVWA['db_server'] = '127.0.0.1';/\$DVWA['db_server'] = '\$DB_SERVER';/" /var/www/html/dvwa/config/config.inc.php && \
    sed -i "s/\$DVWA['db_database'] = 'dvwa';/\$DVWA['db_database'] = '\$DB_DATABASE';/" /var/www/html/dvwa/config/config.inc.php && \
    sed -i "s/\$DVWA['db_username'] = 'root';/\$DVWA['db_username'] = '\$DB_USERNAME';/" /var/www/html/dvwa/config/config.inc.php && \
    sed -i "s/\$DVWA['db_password'] = '';/\$DVWA['db_password'] = '\$DB_PASSWORD';/" /var/www/html/dvwa/config/config.inc.php && \
    sed -i "s/\$DVWA['recaptcha_public_key'] = '';/\$DVWA['recaptcha_public_key'] = '\$DVWA_RECAPTCHA_PUBLIC_KEY';/" /var/www/html/dvwa/config/config.inc.php && \
    sed -i "s/\$DVWA['recaptcha_private_key'] = '';/\$DVWA['recaptcha_private_key'] = '\$DVWA_RECAPTCHA_PRIVATE_KEY';/" /var/www/html/dvwa/config/config.inc.php

# Set correct permissions for DVWA to function
# Apache runs as www-data user/group
RUN chown -R www-data:www-data /var/www/html/dvwa && \
    chmod -R 777 /var/www/html/dvwa/hackable/uploads && \
    chmod -R 777 /var/www/html/dvwa/external/phpids/0.6/lib/IDS/tmp

# Expose port 80 for web traffic
EXPOSE 80

# The base image's CMD (apache2-foreground) will start Apache
# CMD ["apache2-foreground"] # This is typically inherited from php:apache
