# eeacme-to-acmejson

Test to migrate Traefik EE amce certs to Traefik acme.json

## Requirements
- [jq](https://github.com/jqlang/jq)
- [yq](https://github.com/mikefarah/yq)

## Deploy traefikee

### Create Namespace

```bash
kubectl create ns traefikee
```

### Set License

```bash
kubectl create secret generic $CLUSTERNAME-license --from-literal=license="${TRAEFIKEE_LICENSE}" -n traefikee
```

### Set static configuration

```bash
kubectl create configmap $CLUSTERNAME-static-config --from-file ee/static.yaml -o yaml --dry-run=client -n traefikee | kubectl apply -f -
```

### Deploy ee from local helm chart

```bash
helm upgrade --install traefikee traefik/traefikee --values ee/values.yaml --namespace traefikee --set cluster=${CLUSTERNAME} --set controller.staticConfig.configMap.name=${CLUSTERNAME}-static-config
```

### Set DNS

```bash
curl --location --request POST "https://cf.infra.traefiklabs.tech/dns/env-on-demand" \
--header "X-TraefikLabs-User: ${CLUSTERNAME}" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ${DNS_BEARER}" \
--data-raw "{
    \"Value\": \"$(kubectl get svc/${CLUSTERNAME}-proxy-svc -n traefikee --no-headers | awk {'print $4'})\"
}"
```

### Generate teectl configuration

```bash
kubectl exec -n traefikee $CLUSTERNAME-controller-0 -- /traefikee generate credentials --kubernetes.kubeconfig="${KUBECONFIG}"  --cluster="$CLUSTERNAME" > ee/config.yaml
```

### Import configuration within teectl

```bash
teectl cluster import --file=ee/config.yaml --force
```

### Select cluster configuration to use

```bash
teectl cluster use --name=$CLUSTERNAME
```

### Add Dashboard ingress

```bash
envsubst < ee/ingress.yaml | kubectl apply -f -
```

## Deploy whoami

### Create whoami Namespace

```bash
kubectl create ns whoami
```

### deploy whoami app

```bash
envsubst < whoami/whoami.yaml | kubectl apply -f -
```

## Backup cert from TraefikEE

### set a valid folder to store data

```bash
mkdir data && cd data
```

### backup TraefikEE deployment

```bash
teectl backup
```

### extract cert folder and back to root of the repo

```bash
tax -xf traefikee-backup.tar acme && rm acme/${RESOLVERNAME}/account.json && cd ..
```

## Deploy traefik OSS

### deploy Traefik

```bash
helm upgrade --install traefik traefik/traefik --create-namespace --namespace traefik --values oss/values.yaml
```

### Execute migration script

```bash
bash eeacme2acmejson.sh
```

### validate acme.json file on the running container

```bash
kubectl -n traefik exec -it $(k get po -n traefik --no-headers -o custom-columns=":metadata.name") -- cat /data/acme.json
```

### update DNS entry

```bash
curl --location --request POST "https://cf.infra.traefiklabs.tech/dns/env-on-demand" \
--header "X-TraefikLabs-User: ${CLUSTERNAME}" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer ${DNS_BEARER}" \
--data-raw "{
    \"Value\": \"$(kubectl get svc/traefik -n traefik --no-headers | awk {'print $4'})\"
}"
```
