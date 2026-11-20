FROM nginxinc/nginx-unprivileged:alpine
USER root
RUN apk --no-cache upgrade
COPY --chown=nginx:nginx index.html /usr/share/nginx/html/index.html
COPY --chown=nginx:nginx nginx.conf /etc/nginx/conf.d/default.conf
USER nginx
EXPOSE 8080