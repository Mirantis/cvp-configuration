# Openstack resources

Network and image must be created prior to run this template
    network: cvp.net.1
    image: cvp.ubuntu.1604

To auto create them, run cvp resource creation script from ../scripts
Path is relative to this folder: <repo>/autoscale
    bash ../scripts/repare.sh -w ($pwd)

# Source the rc file
    . cvprc

# Create stack
    openstack stack create -t simple.yaml -e environment.yaml simple-scale

# Check that 2 servers created and copy one of the server IDs
    openstack server list

# Check that alarm is created
    openstack alarm list

# Check that 'cpu' metric is coming in
    openstack metric resource show --type instance <server_uuid>

# Finally, wait for several minutes for the metrics to collect and check averages
    gnocchi measures show --resource-id <server_uuid> --aggregation rate:mean cpu

# And check that signals coming in:
    openstack stack event list simple-scale

# And check that there is 5 VMs running after ~10 min
   openstack server list
