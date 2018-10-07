#!/bin/bash

if [ -z "$ENV" ]
then
    echo "ERROR: The ENV var is not defined."
    exit -1
fi

case "$ENV" in
        stg)
            ecs-wl-ssl-gateway -c /etc/nginx/sites-ssl-config-stg.yml
            ;;
        sbx)
            ecs-wl-ssl-gateway -c /etc/nginx/sites-ssl-config-sbx.yml
            ;;
        prd)
            ecs-wl-ssl-gateway -c /etc/nginx/sites-ssl-config-prd.yml
            ;;
        *)
            echo "Wrong ENV value, The values accepted for ENV var are:(stg|sbx|prd)"
            exit -1
esac

if [ $? -ne 0 ]; then
    echo "FATAL - Bootstrap Aborted due problems on ecs-wl-ssl-gateway."; exit 1;
fi

echo "Starting ecs-wl-ssl-gateway SSL ProxyPass"
exec nginx -g "daemon off;"
