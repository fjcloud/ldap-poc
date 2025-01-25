#!/bin/bash
set -e

echo "Starting OpenLDAP initialization..."

# Parse domain components from LDAP_BASE_DN
DC1=$(echo ${LDAP_BASE_DN} | cut -d',' -f1 | cut -d'=' -f2)
DC2=$(echo ${LDAP_BASE_DN} | cut -d',' -f2 | cut -d'=' -f2)

# Generate password hashes
LDAP_ADMIN_PASSWORD_HASH=$(slappasswd -s "${LDAP_ADMIN_PASSWORD}")
LDAP_CONFIG_PASSWORD_HASH=$(slappasswd -s "${LDAP_CONFIG_PASSWORD}")

init_db() {
    echo "Initializing new LDAP database..."
    
    # Create directories if they don't exist
    mkdir -p "${LDAP_DATA_DIR}"
    mkdir -p "${LDAP_CONFIG_DIR}"
    mkdir -p /var/run/openldap
    
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

modulepath /usr/lib64/openldap

database config
rootdn "cn=config"
rootpw ${LDAP_CONFIG_PASSWORD_HASH}

database mdb
maxsize 1073741824
suffix "${LDAP_BASE_DN}"
rootdn "cn=admin,${LDAP_BASE_DN}"
rootpw ${LDAP_ADMIN_PASSWORD_HASH}
directory "${LDAP_DATA_DIR}"
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

    echo "Converting slapd.conf to slapd.d format..."
    rm -rf "${LDAP_CONFIG_DIR}"/*
    slaptest -f /tmp/slapd.conf -F "${LDAP_CONFIG_DIR}" -u || return 1
    rm /tmp/slapd.conf

    # Create initial cn=config.ldif
    cat > "${LDAP_CONFIG_DIR}/cn=config.ldif" << EOF
dn: cn=config
objectClass: olcGlobal
cn: config
olcPidFile: /var/run/openldap/slapd.pid
olcArgsFile: /var/run/openldap/slapd.args

dn: cn=schema,cn=config
objectClass: olcSchemaConfig
cn: schema

dn: olcDatabase={0}config,cn=config
objectClass: olcDatabaseConfig
olcDatabase: {0}config
olcRootDN: cn=config
olcRootPW: ${LDAP_CONFIG_PASSWORD_HASH}

dn: olcDatabase={1}mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: {1}mdb
olcDbDirectory: ${LDAP_DATA_DIR}
olcSuffix: ${LDAP_BASE_DN}
olcRootDN: cn=admin,${LDAP_BASE_DN}
olcRootPW: ${LDAP_ADMIN_PASSWORD_HASH}
olcDbIndex: objectClass eq
olcDbIndex: cn,uid eq
olcDbIndex: uidNumber,gidNumber eq
olcDbIndex: member,memberUid eq
EOF

    echo "Starting temporary slapd instance..."
    slapd -h "ldap://localhost:1389/ ldapi:///" -F "${LDAP_CONFIG_DIR}" -d 1 || return 1

    echo "Waiting for slapd to start..."
    for i in {1..30}; do
        if ldapsearch -Y EXTERNAL -H ldapi:/// -b "cn=config" >/dev/null 2>&1; then
            break
        fi
        if [ "$i" -eq 30 ]; then
            echo "Timeout waiting for slapd to start"
            return 1
        fi
        sleep 1
    done

    echo "Adding initial entries..."
    ldapadd -Y EXTERNAL -H ldapi:/// << EOF || return 1
dn: ${LDAP_BASE_DN}
objectClass: dcObject
objectClass: organization
dc: ${DC1}
o: Example Inc.

dn: ou=people,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: people

dn: ou=groups,${LDAP_BASE_DN}
objectClass: organizationalUnit
ou: groups
EOF

    echo "Stopping temporary slapd instance..."
    if [ -f /var/run/openldap/slapd.pid ]; then
        kill "$(cat /var/run/openldap/slapd.pid)"
        sleep 2
    fi
    
    return 0
}

# Initialize if needed
if [ ! -f "${LDAP_DATA_DIR}/DB_CONFIG" ]; then
    init_db || exit 1
fi

echo "Starting OpenLDAP server..."
# Start slapd in the foreground with more verbose logging
exec slapd -h "ldap://0.0.0.0:1389/ ldapi:///" -F "${LDAP_CONFIG_DIR}" -d 1