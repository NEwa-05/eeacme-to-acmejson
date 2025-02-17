#! /bin/bash

## get traefik oss acme.json
kubectl -n traefik exec -it $(kubectl get po -n traefik --no-headers -o custom-columns=":metadata.name") -- cat /data/acme.json > data/acme.json

## prepare to update file
for i in $(ls data/acme/${RESOLVERNAME}); do
  yq -iPo json ".le.Certificates += $(jq '[. | {domain: .Domain, certificate: .Content, key: .Key, Store: .Store}]' data/acme/${RESOLVERNAME}/$i)" data/acme.json
done

## update acme.json file
kubectl cp data/acme.json traefik/$(kubectl get po -n traefik --no-headers -o custom-columns=":metadata.name"):data/acme.json

## rollout with new file
kubectl rollout restart -n traefik deployment/traefik
