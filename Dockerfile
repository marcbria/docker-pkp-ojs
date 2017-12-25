FROM php:5.6-apache 
LABEL maintainer="Marc Bria Ramírez <marc.bria@uab.cat>"

# PHP Dependencies 
RUN apt-get update \
    && apt-get install zlib1g-dev libxml2-dev -y \
    && docker-php-ext-install pdo pdo_mysql \
    && docker-php-ext-install mysqli mysql zip soap
#    && apt-get install php5-mysql -y 

# Dev stuff 
RUN apt-get install nano net-tools

# Environment: 
RUN echo "-> OS: " && cat /etc/issue
RUN echo "-> PHP: " &&php -v

ENV OJS_BRANCH ${OJS_BRANCH:-ojs-3.1.0-1} 
RUN echo -> Downloading code version: $OJS_BRANCH

RUN mkdir -p /var/www/html 
RUN mkdir -p /var/www/files
WORKDIR /var/www/html

# Get OJS code from released tarball 
RUN curl -o ojs.tar.gz -SL http://pkp.sfu.ca/ojs/download/${OJS_BRANCH}.tar.gz \
        && tar -xzf ojs.tar.gz -C /var/www/html --strip=1 \
        && rm ojs.tar.gz \
        && chown -R www-data:www-data /var/www/html

# ALTERNATIVE: Get OJS code from GitHub
# Cloning and Cleaning OJS and PKP-LIB git repositories
# RUN apt-get install git -y \
#    && git config --global url.https://.insteadOf git:// \
#    && rm -fr /var/www/html/*
# RUN git clone -v --recursive --progress -b ${OJS_BRANCH} --single-branch https://github.com/pkp/ojs.git /var/www/html
# RUN cd lib/pkp \
#     && curl -sS https://getcomposer.org/installer | php \
#     && php composer.phar update

# Get mojo
# RUN mkdir -p /opt/mojo
# RUN git clone -v --progress -b docker --single-branch https://github.com/marcbria/mojo.git /opt/mojo
# RUN ln -s /opt/mojo/scripts/mojo.sh /usr/bin/mojo
# RUN mv /opt/mojo/scripts/config.mojo.TEMPLATE /opt/mojo/scripts/config.mojo

# Clean up 
RUN cd /var/www/html \
    && find . | grep .git | xargs rm -rf \
    && apt-get remove git -y \
    && apt-get autoremove -y \
    && apt-get clean -y

# Setting OJS 
RUN cp config.TEMPLATE.inc.php config.inc.php \
    && chmod ug+rw config.inc.php 

# Setting Apache 
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
COPY default.htaccess /var/www/html/.htaccess
RUN a2enmod rewrite	# expires 

# A workarround for the permissions issue: https://github.com/docker-library/php/issues/222
# RUN sed -ri 's/^www-data:x:82:82:/www-data:x:1000:50:/' /etc/passwd
# An alternative: Use CMS instead of RUN
# CMD ["chown", "www-data:www-data", "/var/www"]
# A different workarround: Change alias (www-data) for user ID (33).
# RUN chown 33:33 /var/www
# Other choice:
RUN usermod -u 1000 www-data
RUN chown www-data:www-data /var/www

# DEBUG:
RUN ls -liash /var/www/html

RUN service apache2 restart 
