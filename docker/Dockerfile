FROM nginx:alpine

RUN apk add --update \
    curl \
    bash \
    python \
    python-dev \
    py-pip \
    nginx-mod-http-headers-more \
    build-base \
    && rm -rf /var/cache/apk/* \
    && mkdir /etc/nginx/ssl-certs/ \
    && rm -f /etc/nginx/conf.d/default.conf

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/ecs-wl-ssl-gateway.py /bin/ecs-wl-ssl-gateway
COPY docker/config/sites-ssl-config-stg.yml /etc/nginx/sites-ssl-config-stg.yml
COPY docker/config/sites-ssl-config-sbx.yml /etc/nginx/sites-ssl-config-sbx.yml
COPY docker/config/sites-ssl-config-prd.yml /etc/nginx/sites-ssl-config-prd.yml
COPY docker/requirements.txt /root/requirements.txt
COPY docker/start.sh /root/start.sh

RUN chmod +x /root/start.sh \
    && chmod +x /bin/ecs-wl-ssl-gateway \
    && pip install --upgrade pip \
    && pip install virtualenv \
    && pip install -r /root/requirements.txt \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

CMD ["/root/start.sh"]
