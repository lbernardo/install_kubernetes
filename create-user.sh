#!/usr/bin/env bash

echo "Username"
read username

openssl genrsa -out ${username}.key 2048

openssl req -new -key ${username}.key -out ${username}.csr -subj "/CN=${username}"

openssl x509 -req -in ${username}.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out ${username}.crt -days 5000

mkdir -p /etc/k8s/certs && mv ${username}.crt ${username}.key /etc/k8s/certs

kubectl config set-credentials ${username} \
  --client-certificate=/etc/k8s/certs/${username}.crt \
  --client-key=/etc/k8s/certs/${username}.key

kubectl config set-context ${username}-context \
  --cluster=kubernetes --user=${username}

