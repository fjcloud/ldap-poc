FROM registry.access.redhat.com/ubi9/ubi-minimal

RUN microdnf -y install openldap-clients && \
    microdnf clean all

CMD ["sleep", "infinity"] 