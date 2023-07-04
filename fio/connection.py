import os
from typing import Any, Final, Union

import openstack


# openstack.enable_logging(True, path='openstack.log')

TEST_CLOUD: Final[str] = os.getenv('OS_TEST_CLOUD', 'target')

cloud = openstack.connect(cloud=TEST_CLOUD)
config = openstack.config.loader.OpenStackConfig()
cloud_config = config.get_one(cloud=TEST_CLOUD)


def get_resource_value(
    resource_key: str, default: Union[int, str]
) -> Union[int, str]:
    try:
        return cloud_config.config['custom_vars'][resource_key]
    except KeyError:
        return default


CLOUD_NAME: Final[Any] = get_resource_value('cloud_name', '')

UBUNTU_IMAGE_NAME: Final[Any] = get_resource_value(
    'ubuntu_image_name', 'Ubuntu-18.04')
FIO_SG_NAME: Final[Any] = get_resource_value('sg_name', 'fio-sg')
FIO_KEYPAIR_NAME: Final[str] = "-".join(
    [get_resource_value('keypair_name', 'fio-key'), CLOUD_NAME])
PRIVATE_KEYPAIR_FILE: Final[str] = "{}/{}.pem".format(
    get_resource_value('keypair_file_location', '.'),
    FIO_KEYPAIR_NAME)

FIO_NET_NAME: Final[Any] = get_resource_value('fixed_net_name', 'fio-net')
FIO_SUBNET_NAME: Final[Any] = get_resource_value(
    'fixed_subnet_name', 'fio-subnet')
FIO_SUBNET_RANGE: Final[Any] = get_resource_value(
    'fixed_subnet_range', '192.168.200.0/24')
NET_IPV4: Final[Any] = get_resource_value('net_ipv4', '4')
FIO_ROUTER_NAME: Final[Any] = get_resource_value(
    'fio_router_name', 'fio-router')
FLOATING_NET_NAME: Final[Any] = get_resource_value(
    'floating_net_name', 'public')
MTU_SIZE: Final[Any] = get_resource_value('mtu_size', 9000)

FIO_FLAVOR_NAME: Final[Any] = get_resource_value('fio_flavor_name', 'fio')
FIO_FLAVOR_RAM: Final[Any] = get_resource_value('fio_flavor_ram', 2048)
FIO_FLAVOR_CPUS: Final[Any] = get_resource_value('fio_flavor_cpus', 10)
FIO_FLAVOR_DISK: Final[Any] = get_resource_value('fio_flavor_disk', 20)
FIO_CLIENTS_COUNT: Final[int] = int(
    get_resource_value('fio_clients_count', 10))
FIO_VOL_NAME_MASK: Final[Any] = get_resource_value(
    'fio_vol_name_mask', 'fio-vol')
FIO_VOL_SIZE: Final[Any] = get_resource_value('fio_vol_size', 110)
FIO_VOL_TYPE: Final[Any] = get_resource_value(
    'fio_vol_type', 'volumes-nvme')
FIO_VOL_MOUNTPOINT: Final[Any] = get_resource_value(
    'fio_vol_mountpoint', '/dev/vdc')
FIO_CLIENT_NAME_MASK: Final[Any] = get_resource_value(
    'fio_client_name_mask', 'fio-vm')
FIO_AA_SERVER_GROUP_NAME: Final[Any] = get_resource_value(
    'fio_aa_group_name', 'fio-anti-affinity-group')

HV_SUFFIX: Final[Any] = get_resource_value('hv_suffix', '')
CONCURRENCY: Final[int] = int(get_resource_value('concurrency', 5))


def delete_server(srv: openstack.compute.v2.server.Server) -> None:
    cloud.compute.delete_server(srv)
    cloud.compute.wait_for_delete(srv)


def delete_volume(vol: openstack.block_storage.v3.volume.Volume) -> None:
    cloud.volume.delete_volume(vol)
    cloud.volume.wait_for_delete(vol)


def detach_volume(
    srv: openstack.compute.v2.server.Server,
    vol: openstack.block_storage.v3.volume.Volume
) -> None:
    cloud.compute.delete_volume_attachment(srv, vol)
    cloud.volume.wait_for_status(vol, status='available')


if __name__ == "__main__":
    print(UBUNTU_IMAGE_NAME)
    print(FIO_SG_NAME)
    print(FIO_KEYPAIR_NAME)
    print(PRIVATE_KEYPAIR_FILE)

    print(FIO_NET_NAME)
    print(FIO_SUBNET_NAME)
    print(FIO_SUBNET_RANGE)
    print(NET_IPV4)
    print(FIO_ROUTER_NAME)
    print(FLOATING_NET_NAME)
    print(MTU_SIZE)

    print(FIO_FLAVOR_NAME)
    print(FIO_FLAVOR_RAM)
    print(FIO_FLAVOR_CPUS)
    print(FIO_FLAVOR_DISK)
    print(FIO_CLIENTS_COUNT)
    print(FIO_CLIENT_NAME_MASK)
    print(FIO_AA_SERVER_GROUP_NAME)
    print(FIO_VOL_NAME_MASK)
    print(FIO_VOL_SIZE)
    print(FIO_VOL_TYPE)
    print(FIO_VOL_MOUNTPOINT)

    print(HV_SUFFIX)
    print(CLOUD_NAME)
    print(CONCURRENCY)
