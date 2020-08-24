#!/bin/sh


openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=bicycle.contoso.com/O=Contoso Bicycle"
openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
export APP_GATEWAY_LISTENER_CERTIFICATE=$(cat appgw.pfx | base64 -w 0)

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-contoso-com-tls.crt -keyout traefik-ingress-internal-aks-ingress-contoso-com-tls.key -subj "/CN=*.aks-ingress.contoso.com/O=Contoso Aks Ingress"
export AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64=$(cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt | base64 -w 0)

echo Secret APP_GATEWAY_LISTENER_CERTIFICATE_BASE64
echo $APP_GATEWAY_LISTENER_CERTIFICATE
echo \n
echo AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64
echo $AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64
