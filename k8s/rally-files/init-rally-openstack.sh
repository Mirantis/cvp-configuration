#!/bin/bash
cd /artifacts

# create an openstack env from the public endpoints since Heat API is available only via public ep
export OS_ENDPOINT_TYPE=public
export OS_INTERFACE=public

# Create openstack env
rally env create --from-sysenv --name openstack
rally env check
