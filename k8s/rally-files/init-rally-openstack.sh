#!/bin/bash
cd /artifacts

# Create openstack env
rally env create --from-sysenv --name openstack
rally env check
