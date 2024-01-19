#!/bin/bash

echo "Preparing certs"
openssl genrsa -out image_key.pem 1024
openssl rsa -pubout -in image_key.pem -out image_key.pem.pub
openssl req -new -key image_key.pem -out image_req.crt -config image_crt.cnf
openssl x509 -req -days 180 -in image_req.crt -signkey image_key.pem -out image_cert.crt
​
echo "Save secret to Barbican storage"
openstack secret store --name cvp.images --algorithm RSA --expiration $(date +"%Y-%m-%d" -d "180 days") --secret-type certificate --payload-content-type "application/octet-stream" --payload-content-encoding base64 --payload "$(base64 image_cert.crt)"
​
echo "Exporting ID from 'Secret href' property"
export s_uuid=$(openstack secret list --name cvp.images -c "Secret href" -f value | rev | cut -d'/' -f1 | rev)
echo "Exported '$s_uuid'"
​
echo "Converting images to Raw"
qemu-img convert -f qcow2 -O raw -p cvp.ubuntu.2004 /var/tmp/cvp.ubuntu.2004.raw
qemu-img convert -f qcow2 -O raw -p cvp.ubuntu.1604 /var/tmp/cvp.ubuntu.1604.raw
qemu-img convert -f qcow2 -O raw -p cvp.cirros.61 /var/tmp/cvp.cirros.61.raw
qemu-img convert -f qcow2 -O raw -p cvp.cirros.62 /var/tmp/cvp.cirros.62.raw
​
echo "Signing images"
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.cirros.61.raw.signature /var/tmp/cvp.cirros.61.raw
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.cirros.62.raw.signature /var/tmp/cvp.cirros.62.raw
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.ubuntu.1604.raw.signature /var/tmp/cvp.ubuntu.1604.raw
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.ubuntu.2004.raw.signature /var/tmp/cvp.ubuntu.2004.raw

echo "Generating base64 equivalents"
base64 -w 0 cvp.cirros.61.raw.signature >cvp.cirros.61.raw.signature.b64
base64 -w 0 cvp.cirros.62.raw.signature >cvp.cirros.62.raw.signature.b64
base64 -w 0 cvp.ubuntu.1604.raw.signature >cvp.ubuntu.1604.raw.signature.b64
base64 -w 0 cvp.ubuntu.2004.raw.signature >cvp.ubuntu.2004.raw.signature.b64

echo "Exporting vars"
export cirros61_sign=$(cat cvp.cirros.61.raw.signature.b64)
export cirros62_sign=$(cat cvp.cirros.62.raw.signature.b64)
export ubuntu1604_sign=$(cat cvp.ubuntu.1604.raw.signature.b64)
export ubuntu2004_sign=$(cat cvp.ubuntu.2004.raw.signature.b64)
​
echo "Uploading 'cvp.cirros.61.raw.signed''"
glance image-create --name cvp.cirros.61.raw.signed --container-format bare --disk-format raw --property img_signature="$cirros61_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.cirros.61.raw
echo "Uploading 'cvp.cirros.62.raw.signed''"
glance image-create --name cvp.cirros.62.raw.signed --container-format bare --disk-format raw --property img_signature="$cirros62_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.cirros.62.raw
echo "Uploading 'cvp.ubuntu.1604.raw.signed''"
glance image-create --name cvp.ubuntu.1604.raw.signed --container-format bare --disk-format raw --property img_signature="$ubuntu1604_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.ubuntu.1604.raw
echo "Uploading 'cvp.ubuntu.2004.raw.signed''"
glance image-create --name cvp.ubuntu.2004.raw.signed --container-format bare --disk-format raw --property img_signature="$ubuntu2004_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.ubuntu.2004.raw
