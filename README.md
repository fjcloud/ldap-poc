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

## Deploy ldapsearch pod

```shell
oc new-app https://github.com/fjcloud/ldap-poc.git --strategy docker --name ldapsearch
```

## LDAP query

```shell
oc rsh deployment/ldapsearch ldapsearch -H ldap://$(oc get svc ldap-external -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'):1389 \
-x -D "cn=serviceuser,dc=example,dc=org" -w dogood \
-b "dc=example,dc=org" \
-s sub "(&(objectClass=*)(uid=testuser))"
```
