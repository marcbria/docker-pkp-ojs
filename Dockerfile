FROM php:7.2-apache
LABEL maintainer="Marc Bria Ramírez <marc.bria@uab.cat>"

# Taken from wordpress oficial image:
# install the PHP extensions we need
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y \
		libjpeg-dev \
		libpng-dev \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	docker-php-ext-install gd mysqli opcache; \
	docker-php-ext-install pdo pdo_mysql; \
	docker-php-ext-install zip soap;
# TODO consider removing the *-dev deps and only keeping the necessary lib* packages
# MBR: Adding pdo, zip and soap support.

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN a2enmod rewrite expires

# Cloning and Cleaning OJS and PKP-LIB git repositories
RUN apt-get install git -y \
    && git config --global url.https://.insteadOf git:// \
    && rm -fr /var/www/html/* 

# Adding dev stuff (remove if not required)
RUN apt-get install nano net-tools

# Environment:
ENV OJS_BRANCH ${OJS_BRANCH:-ojs-3.1.0-1}
RUN echo Downloading code version: $OJS_BRANCH

RUN mkdir -p /var/www/html 
RUN mkdir -p /var/www/files 
WORKDIR /var/www/html

# A workarround for the permissions issue: https://github.com/docker-library/php/issues/222
# RUN sed -ri 's/^www-data:x:82:82:/www-data:x:1000:50:/' /etc/passwd

# A different workarround: Change alias (www-data) for user ID (33).

# Get OJS code from released tarball
RUN curl -o ojs.tar.gz -SL http://pkp.sfu.ca/ojs/download/${OJS_BRANCH}.tar.gz \
        && tar -xzf ojs.tar.gz -C /var/www/html --strip=1 \
        && rm ojs.tar.gz \
        && chown -R 33:33 /var/www/html

# Get OJS code from GitHub
# RUN git clone -v --recursive --progress -b ${OJS_BRANCH} --single-branch https://github.com/pkp/ojs.git /var/www/html

# RUN cd lib/pkp \
#     && curl -sS https://getcomposer.org/installer | php \
#     && php composer.phar update 

# Get mojo
RUN mkdir -p /opt/mojo
RUN git clone -v --progress -b docker --single-branch https://github.com/marcbria/mojo.git /opt/mojo
RUN ln -s /opt/mojo/scripts/mojo.sh /usr/bin/mojo
RUN mv /opt/mojo/scripts/config.mojo.TEMPLATE /opt/mojo/scripts/config.mojo

# Clean up
RUN cd /var/www/html \
    && find . | grep .git | xargs rm -rf \
    && apt-get remove git -y \
    && apt-get autoremove -y \
    && apt-get clean -y

# Setting OJS
RUN cp config.TEMPLATE.inc.php config.inc.php \
    && chmod ug+rw config.inc.php \
    && chown -R 33:33 /var/www

# Setting Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
COPY default.htaccess /var/www/html/.htaccess
RUN a2enmod rewrite \
    && service apache2 restart 
