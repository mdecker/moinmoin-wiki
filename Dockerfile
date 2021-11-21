# VERSION 0.7
# AUTHOR:         Michael Decker <mde.proj@gmail.com>
# DESCRIPTION:    Image with MoinMoin wiki, uwsgi, nginx
# TO_BUILD:       docker build -t moinmoin .
# TO_RUN:         docker run -d -p 80:80 --name my_wiki moinmoin

FROM debian:buster-slim
MAINTAINER Michael Decker <mde.proj@gmail.com>

# Set the version you want of MoinMoin
ENV MM_VERSION 1.9.11
ENV MM_CSUM 02be31d55f39d4fe0c6253df8b49e01b76d095634cbd1b56d185f66e1e0c3cf5

# Install software
RUN apt-get update && apt-get install -qqy --no-install-recommends \
  python2.7 \
  curl \
  nginx \
  uwsgi \
  uwsgi-plugin-python \
  rsyslog \
  busybox

# Download MoinMoin
RUN curl -OkL \
  https://github.com/moinwiki/moin-1.9/releases/download/$MM_VERSION/moin-$MM_VERSION.tar.gz
RUN if [ "$MM_CSUM" != "$(sha256sum moin-$MM_VERSION.tar.gz | awk '{print($1)}')" ];\
  then exit 1; fi;
RUN mkdir moinmoin
RUN tar xf moin-$MM_VERSION.tar.gz -C moinmoin --strip-components=1

# Install MoinMoin
RUN cd moinmoin && python2.7 setup.py install --force --prefix=/usr/local
RUN chown -Rh www-data:www-data /usr/local/share/moin/underlay
USER root

# Copy default data into a new folder, we will use this to add content
# if you start a new container using volumes
RUN cp -r /usr/local/share/moin/data /usr/local/share/moin/bootstrap-data
ADD wikiconfig.py /usr/local/share/moin/bootstrap-data/

RUN chown -R www-data:www-data /usr/local/share/moin/data
ADD logo.png /usr/local/lib/python2.7/dist-packages/MoinMoin/web/static/htdocs/common/

# Configure nginx
ADD nginx.conf /etc/nginx/
ADD moinmoin-nossl.conf /etc/nginx/sites-available/
RUN mkdir -p /var/cache/nginx/cache
RUN rm /etc/nginx/sites-enabled/default
RUN ln -sf /etc/nginx/sites-available/moinmoin-nossl.conf \
        /etc/nginx/sites-enabled/moinmoin.conf

# Cleanup
RUN rm moin-$MM_VERSION.tar.gz
RUN rm -rf /moinmoin
RUN apt-get purge -qqy curl
RUN apt-get autoremove -qqy && apt-get clean
RUN rm -rf /tmp/* /var/lib/apt/lists/*

# Add the start shell script
ADD start.sh /usr/local/bin/

VOLUME /usr/local/share/moin/data

EXPOSE 80

CMD start.sh
