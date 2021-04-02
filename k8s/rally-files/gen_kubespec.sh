#!/bin/bash
# files
ca_crt=$(pwd)/ca.crt
client_crt=$(pwd)/client.crt
client_key=$(pwd)/client.key

function show_help() {
   printf "\ngen_kubespec.sh <kubeconfig.yaml>\n"
   exit 1
}

# Check for a config file
if [[ -z ${1+x} ]]; then
   show_help
   printf "\nERROR: No kubeconfig.yaml specified\n"
   exit 1
fi

# Check if file exists
if [[ ! -f $1 ]]; then
   show_help
   printf "\nERROR: Supplied kubeconfig file not exists at '$1'\n"
   exit 1
fi

# extract data as variables
declare $(sed -e 's/:[^:\/\/,:443,:6443]/=/g;s/ *=/=/g;s/-/_/g' $1 | grep 'certificate\|key\|server' | tr -d ' ')
echo "# Declared variable: server=$server"

### Uncomment if separate files needed
printf "# Creating 'ca.crt', 'client.crt' and 'client.key'\n"
echo "# '${ca_crt}'"
echo $certificate_authority_data | base64 -d >${ca_crt}
echo "# '${client_crt}'"
echo $client_certificate_data | base64 -d >${client_crt}
echo "# '${client_key}'"
echo $client_key_data | base64 -d >${client_key}

printf "Generating 'kubespec.yaml'\n"
cat << EOF >kubespec_generated.yaml
---
existing@kubernetes:
    server: $server
    certificate-authority: ${ca_crt}
    client-certificate: ${client_crt}
    client-key: ${client_key}
    tls_insecure: True
EOF
