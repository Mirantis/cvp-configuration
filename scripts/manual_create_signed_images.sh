#!/bin/bash
# Preparing secretp
openssl genrsa -out image_key.pem 1024
openssl rsa -pubout -in image_key.pem -out image_key.pem.pub
openssl req -new -key image_key.pem -out image_req.crt
openssl x509 -req -days 180 -in image_req.crt -signkey image_key.pem -out image_cert.crt
​
# Save secret to Barbican storage
openstack secret store --name cvp.images --algorithm RSA --expiration 2023-06-15 --secret-type certificate --payload-content-type "application/octet-stream" --payload-content-encoding base64 --payload "$(base64 image_cert.crt)"
​
# save ID from "Secret href" property
export s_uuid=1149deef-13b1-4ace-8aef-613466ef6fe7
​
# To Raw
qemu-img convert -f qcow2 -O raw -p cvp.ubuntu.2004 /var/tmp/cvp.ubuntu.2004.raw
qemu-img convert -f qcow2 -O raw -p cvp.ubuntu.1604 /var/tmp/cvp.ubuntu.1604.raw
qemu-img convert -f qcow2 -O raw -p cvp.cirros.51 /var/tmp/cvp.cirros.51.raw
qemu-img convert -f qcow2 -O raw -p cvp.cirros.52 /var/tmp/cvp.cirros.52.raw
​
# Sign images
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.cirros.51.raw.signature /var/tmp/cvp.cirros.51.raw
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.cirros.52.raw.signature /var/tmp/cvp.cirros.52.raw
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.ubuntu.1604.raw.signature /var/tmp/cvp.ubuntu.1604.raw
openssl dgst -sha256 -sign image_key.pem -sigopt rsa_padding_mode:pss -out cvp.ubuntu.2004.raw.signature /var/tmp/cvp.ubuntu.2004.raw

base64 -w 0 cvp.cirros.51.raw.signature >cvp.cirros.51.raw.signature.b64
base64 -w 0 cvp.cirros.52.raw.signature >cvp.cirros.52.raw.signature.b64
base64 -w 0 cvp.ubuntu.1604.raw.signature >cvp.ubuntu.1604.raw.signature.b64
base64 -w 0 cvp.ubuntu.2004.raw.signature >cvp.ubuntu.2004.raw.signature.b64

export cirros51_sign=$(cat cvp.cirros.51.raw.signature.b64)
export cirros52_sign=$(cat cvp.cirros.52.raw.signature.b64)
export ubuntu1604_sign=$(cat cvp.ubuntu.1604.raw.signature.b64)
export ubuntu2004_sign=$(cat cvp.ubuntu.2004.raw.signature.b64)
​
# Upload
glance image-create --name cvp.cirros.51.raw.signed --container-format bare --disk-format raw --property img_signature="$cirros51_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.cirros.51.raw
glance image-create --name cvp.cirros.52.raw.signed --container-format bare --disk-format raw --property img_signature="$cirros52_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.cirros.52.raw
glance image-create --name cvp.ubuntu.1604.raw.signed --container-format bare --disk-format raw --property img_signature="$ubuntu1604_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.ubuntu.1604.raw
glance image-create --name cvp.ubuntu.2004.raw.signed --container-format bare --disk-format raw --property img_signature="$ubuntu2004_sign" --property img_signature_certificate_uuid="$s_uuid" --property img_signature_hash_method='SHA-256' --property img_signature_key_type='RSA-PSS' < /var/tmp/cvp.ubuntu.2004.raw
