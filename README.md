## Deployment of glauth on ROSA

```shell
oc apply -f https://raw.githubusercontent.com/fjcloud/openldap/main/glauth-deploy-all.yaml
```

## Create IDP config

```shell
rosa create idp -c your_cluster -t ldap \
  --url "ldap://$(oc get svc ldap-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):1389/dc=example,dc=org?uid?sub?(objectClass=*)" \
  --insecure true \
  --bind-dn "cn=serviceuser,dc=example,dc=org" \
  --bind-password dogood
```
