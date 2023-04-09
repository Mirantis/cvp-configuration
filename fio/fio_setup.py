import os
import sys
from typing import Dict, Final, List

import connection as conn
import openstack
from openstack.exceptions import ResourceFailure


compute = conn.cloud.compute
network = conn.cloud.network
volume = conn.cloud.volume

CLIENTS_COUNT: Final[int] = conn.FIO_CLIENTS_COUNT
CLIENT_NAME_MASK: Final[str] = conn.FIO_CLIENT_NAME_MASK
UBUNTU_IMAGE_NAME: Final[str] = conn.UBUNTU_IMAGE_NAME

VOL_NAME_MASK: Final[str] = conn.FIO_VOL_NAME_MASK
VOL_SIZE: Final[int] = conn.FIO_VOL_SIZE
VOL_TYPE: Final[str] = conn.FIO_VOL_TYPE
VOL_MOUNTPOINT: Final[str] = conn.FIO_VOL_MOUNTPOINT

FLAVOR_NAME: Final[str] = conn.FIO_FLAVOR_NAME
FLAVOR_RAM: Final[int] = conn.FIO_FLAVOR_RAM
FLAVOR_CPUS: Final[int] = conn.FIO_FLAVOR_CPUS
FLAVOR_DISK: Final[int] = conn.FIO_FLAVOR_DISK

NET_NAME: Final[str] = conn.FIO_NET_NAME
ROUTER_NAME: Final[str] = conn.FIO_ROUTER_NAME
FLOATING_NET_NAME = conn.FLOATING_NET_NAME
SUBNET_NAME = conn.FIO_SUBNET_NAME
SUBNET_RANGE = conn.FIO_SUBNET_RANGE
MTU_SIZE = conn.MTU_SIZE
NET_IPV4 = conn.NET_IPV4

KEYPAIR_NAME: Final[str] = conn.FIO_KEYPAIR_NAME
PRIVATE_KEYPAIR_FILE: Final[str] = conn.PRIVATE_KEYPAIR_FILE

SG_NAME: Final[str] = conn.FIO_SG_NAME
HV_SUFFIX: Final[str] = conn.HV_SUFFIX
CLOUD_NAME: Final[str] = conn.CLOUD_NAME

NODES: Final[List[str]] = []
SKIP_NODES: Final[List[str]] = []


SG_ALLOW_ALL_RULES: Final[List[Dict]] = [
    {
        'remote_ip_prefix': '0.0.0.0/0',
        'protocol': 'icmp',
        'port_range_max': None,
        'port_range_min': None,
        'ethertype': 'IPv4'
    },
    {
        'remote_ip_prefix': '0.0.0.0/0',
        'protocol': 'tcp',
        'port_range_max': 65535,
        'port_range_min': 1,
        'ethertype': 'IPv4'
    },
    {
        'remote_ip_prefix': '0.0.0.0/0',
        'protocol': 'udp',
        'port_range_max': 65535,
        'port_range_min': 1,
        'ethertype': 'IPv4'
    }
]


def create_server(
        name, image_id, flavor_id, networks,
        key_name, security_groups, availability_zone
) -> openstack.connection.Connection:
    srv = compute.create_server(
        name=name, image_id=image_id, flavor_id=flavor_id, networks=networks,
        key_name=key_name, security_groups=security_groups,
        availability_zone=availability_zone)
    return srv


if __name__ == "__main__":
    # Check if any fio servers already exist on the cloud
    servers = compute.servers(details=False, name=CLIENT_NAME_MASK)
    srvrs = list(servers)
    if srvrs:
        names = [s.name for s in srvrs]
        print("The following servers already exist in the cloud:")
        print(*names, sep='\n')
        sys.exit(0)

    # Create fio sg if needed
    sg = network.find_security_group(SG_NAME)
    if not sg:
        sg = network.create_security_group(name=SG_NAME)
        # Add 'allow-all' kind of rules to the security group
        pairs = [
            (r, d) for r in SG_ALLOW_ALL_RULES for d in ('ingress', 'egress')]
        for (rule, direction) in pairs:
            network.create_security_group_rule(
                security_group_id=sg.id, direction=direction, **rule)

    # Create fio keypair if needed
    kp = compute.find_keypair(KEYPAIR_NAME)
    if not kp:
        kp = compute.create_keypair(name=KEYPAIR_NAME)
        with open(PRIVATE_KEYPAIR_FILE, 'w') as f:
            f.write("{}".format(kp.private_key))

        os.chmod(PRIVATE_KEYPAIR_FILE, 0o400)

    # Create fio flavor if needed
    flavor = compute.find_flavor(FLAVOR_NAME)
    if not flavor:
        flavor = compute.create_flavor(
            name=FLAVOR_NAME, ram=FLAVOR_RAM,
            vcpus=FLAVOR_CPUS, disk=FLAVOR_DISK)

    # Set image property to enable virtio-net multique in created servers
    img = compute.find_image(UBUNTU_IMAGE_NAME)
    compute.set_image_metadata(img.id, hw_vif_multiqueue_enabled='true')

    # Create fio router if needed
    fip_net = network.find_network(FLOATING_NET_NAME)
    router = network.find_router(ROUTER_NAME)
    if not router:
        router = network.create_router(
            name=ROUTER_NAME, external_gateway_info={'network_id': fip_net.id})

    # Create fio net/subnet if needed
    fio_net = network.find_network(NET_NAME)
    if not fio_net:
        fio_net = network.create_network(
            name=NET_NAME,
            availability_zone_hints=['nova'],
            # mtu=MTU_SIZE,
            shared=False,
            port_security_enabled=True)
        fio_subnet = network.create_subnet(
            name=SUBNET_NAME,
            network_id=fio_net.id,
            cidr=SUBNET_RANGE,
            ip_version=NET_IPV4)
        # Add fio net to fio router
        fio_net_port = network.add_interface_to_router(
            router.id, subnet_id=fio_subnet.id)

    # Get list of running computes with enabled 'nova-compute' service
    cmp_services = compute.services(binary='nova-compute')
    computes = [s for s in cmp_services if
                s.host in NODES and
                s.host not in SKIP_NODES and
                s.state == 'up' and s.status == 'enabled']

    # Prepare list of hypervisors to be used for running fio servers
    hypervisors = []
    computes_num = len(computes)
    for i in range(CLIENTS_COUNT):
        hypervisors.append(
            ".".join([computes[i % computes_num].host, HV_SUFFIX]))

    # Create <CLIENTS_COUNT> clients, attached to fio private network
    vms = []
    for i in range(CLIENTS_COUNT):
        name = f"{CLIENT_NAME_MASK}{i}"
        az = f"::{hypervisors[i]}"
        flavor_id = flavor.id
        vm = create_server(
            name=name,
            image_id=img.id,
            flavor_id=flavor_id,
            networks=[{'uuid': fio_net.id}],
            key_name=KEYPAIR_NAME,
            security_groups=[{'name': SG_NAME}],
            availability_zone=az)
        try:
            vm = compute.wait_for_server(vm, wait=180)
            node = hypervisors[i].split('.')[0]
            print(f"Fio client VM '{vm.name}' is created on '{node}' node")
        # Stop and exit if any of the servers creation failed (for any reason)
        except ResourceFailure as e:
            print(
                f"Fio client VM '{vm.name}' creation failed with '{e.message}'"
                " error.")
            conn.delete_server(vm)
            sys.exit(0)
        vms.append(vm)

        # Create a volume of the given type
        vol_name = f"{VOL_NAME_MASK}{i}"
        vol = volume.create_volume(
            name=vol_name, size=VOL_SIZE, volume_type=VOL_TYPE)
        try:
            vol = volume.wait_for_status(vol, status='available')
            print(f"Volume '{vol.name}' is created")
        # Delete a volume if its creation failed and switch to next
        # fio client VM
        except ResourceFailure as e:
            print(
                f"Volume '{vol.name}' creation failed with '{e.message}' "
                "error.")
            conn.delete_volume(vol)
            continue

        # Attach the volume to the fio client
        compute.create_volume_attachment(vm, volume=vol)
        try:
            vol = volume.wait_for_status(vol, status='in-use')
            print(f"Volume '{vol.name}' is attached to '{vm.name}' fio client")
        # Delete a volume if attachment failed and switch to next
        # fio client VM
        except ResourceFailure as e:
            print(
                f"Volume '{vol.name}' attachment failed with '{e.message}' "
                "error.")
            conn.delete_volume(vol)
            continue
