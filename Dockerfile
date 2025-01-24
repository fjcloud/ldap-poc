FROM registry.access.redhat.com/ubi9/ubi:latest

# Set labels
LABEL maintainer="Your Name <your@email.com>" \
      name="openldap" \
      version="2.4" \
      description="OpenLDAP server based on UBI9"

# Set environment variables
ENV LDAP_USER=ldap \
    LDAP_GROUP=ldap \
    LDAP_DATA_DIR=/var/lib/ldap \
    LDAP_CONFIG_DIR=/etc/openldap/slapd.d \
    LDAP_DOMAIN=example.org \
    LDAP_BASE_DN="dc=example,dc=org" \
    LDAP_ADMIN_PASSWORD=admin \
    LDAP_CONFIG_PASSWORD=config

# Install required packages
RUN dnf -y install \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm && \
    dnf -y install \
        2to3 \
        openldap \
        openldap-servers \
        openldap-clients \
        openssl \
        shadow-utils && \
    dnf clean all

# Create LDAP user and group
RUN groupadd -r ${LDAP_GROUP} && \
    useradd -r -g ${LDAP_GROUP} -d ${LDAP_DATA_DIR} ${LDAP_USER}

# Create necessary directories and set permissions
RUN mkdir -p ${LDAP_DATA_DIR} ${LDAP_CONFIG_DIR} && \
    chown -R ${LDAP_USER}:${LDAP_GROUP} ${LDAP_DATA_DIR} ${LDAP_CONFIG_DIR} && \
    chmod 700 ${LDAP_DATA_DIR} ${LDAP_CONFIG_DIR}

# Copy configuration files and scripts
COPY slapd.conf /etc/openldap/
COPY *.ldif /etc/openldap/slapd.d/
COPY entrypoint.sh /usr/local/bin/

# Set script permissions
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose LDAP ports
EXPOSE 389 636

# Set working directory
WORKDIR ${LDAP_DATA_DIR}

# Switch to LDAP user
USER ${LDAP_USER}

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]