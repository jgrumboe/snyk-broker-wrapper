# Multistage build
FROM binxio/gcp-get-secret

# "real" stage
FROM snyk/broker:jira

# get gcp-get-secret to access GCP Secrets Manager
USER 0
COPY --from=0 /gcp-get-secret /usr/local/bin/

# add entrypoint
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENV BROKER_TOKEN_SECRET not_set
ENV JIRA_PASSWORD_SECRET not_set

USER node
CMD ["/entrypoint.sh"]