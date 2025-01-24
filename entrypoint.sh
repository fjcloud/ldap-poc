#!/bin/bash
set -e

# Generate password hashes
LDAP_ADMIN_PASSWORD_HASH=$(slappasswd -s "${LDAP_ADMIN_PASSWORD}")
LDAP_CONFIG_PASSWORD_HASH=$(slappasswd -s "${LDAP_CONFIG_PASSWORD}")

# Initialize new LDAP database if it doesn't exist
if [ ! -f "${LDAP_DATA_DIR}/DB_CONFIG" ]; then
    echo "Initializing new LDAP database..."
    
    # Create data directory and set permissions
    mkdir -p "${LDAP_DATA_DIR}"
    chgrp -R 0 "${LDAP_DATA_DIR}"
    chmod -R g=u "${LDAP_DATA_DIR}"
    
    # Create a basic DB_CONFIG file
    cat > "${LDAP_DATA_DIR}/DB_CONFIG" << EOF
# One 0.25 GB memory map
set_cachesize 0 268435456 1

# Transaction Log settings
set_lg_regionmax 262144
set_lg_bsize 2097152
EOF

    # Create temporary slapd.conf
    cat > /tmp/slapd.conf << EOF
include /etc/openldap/schema/core.schema
include /etc/openldap/schema/cosine.schema
include /etc/openldap/schema/inetorgperson.schema
include /etc/openldap/schema/nis.schema

pidfile /var/run/openldap/slapd.pid
argsfile /var/run/openldap/slapd.args

database config
rootdn "cn=config"
rootpw ${LDAP_CONFIG_PASSWORD_HASH}

database mdb
maxsize 1073741824
suffix "${LDAP_BASE_DN}"
rootdn "cn=admin,${LDAP_BASE_DN}"
rootpw ${LDAP_ADMIN_PASSWORD_HASH}
directory ${LDAP_DATA_DIR}
index objectClass eq
index cn,uid eq
index uidNumber,gidNumber eq
index member,memberUid eq

access to attrs=userPassword,shadowLastChange
    by self write
    by anonymous auth
    by * none

access to *
    by self write
    by users read
    by * none
EOF

    # Convert slapd.conf to slapd.d format
    rm -rf "${LDAP_CONFIG_DIR}"/*
    slaptest -f /tmp/slapd.conf -F "${LDAP_CONFIG_DIR}" -u
    rm /tmp/slapd.conf

    # Initialize the database
    mkdir -p /var/run/openldap
    slapadd -F "${LDAP_CONFIG_DIR}" -b "${LDAP_BASE_DN}" << EOF
dn: ${LDAP_BASE_DN}
objectClass: dcObject
objectClass: organization
dc: example
o: Example Inc.

dn: ou=people,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: people

dn: ou=groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: groups
EOF

    # Set correct permissions
    chgrp -R 0 "${LDAP_DATA_DIR}" "${LDAP_CONFIG_DIR}" /var/run/openldap
    chmod -R g=u "${LDAP_DATA_DIR}" "${LDAP_CONFIG_DIR}" /var/run/openldap
fi

# Start slapd in the foreground
exec slapd -h "ldap:/// ldapi:///" -u ${LDAP_USER} -g ${LDAP_GROUP} -F "${LDAP_CONFIG_DIR}" -d ${LDAP_LOG_LEVEL:-256}