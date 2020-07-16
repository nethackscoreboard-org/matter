FROM httpd:2.4-alpine
COPY ./docker/apache/nhs.conf /usr/local/apache2/conf.d/nhs.conf
COPY ./docker/apache/httpd.conf /usr/local/apache2/conf/httpd.conf
COPY ./docker/apache/entrypoint.sh /usr/bin/entrypoint
RUN chmod +x /usr/bin/entrypoint
RUN ln -sf /proc/1/fd/1 /var/log/access.log
RUN ln -sf /proc/1/fd/2 /var/log/error.log
EXPOSE 80   
ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["httpd-foreground"]