import multiprocessing as mp

import connection as conn
from openstack.exceptions import ResourceFailure
from typing import Final


compute = conn.cloud.compute
network = conn.cloud.network
volume = conn.cloud.volume

CLIENT_NAME_MASK: Final[str] = conn.FIO_CLIENT_NAME_MASK
AA_SERVER_GROUP_NAME: Final[str] = conn.FIO_AA_SERVER_GROUP_NAME
FLAVOR_NAME: Final[str] = conn.FIO_FLAVOR_NAME
KEYPAIR_NAME: Final[str] = conn.FIO_KEYPAIR_NAME
SG_NAME: Final[str] = conn.FIO_SG_NAME

ROUTER_NAME: Final[str] = conn.FIO_ROUTER_NAME
NET_NAME: Final[str] = conn.FIO_NET_NAME
CONCURRENCY: Final[int] = conn.CONCURRENCY


def delete_fio_client(vm_id: str) -> None:
    vm = compute.get_server(vm_id)
    attachments = compute.volume_attachments(vm)
    # Delete fio volume attachment (and any other attachments
    # that the VM could have)
    # Delete the volume and the server
    for att in attachments:
        vol_id = att.volume_id
        vol = volume.get_volume(vol_id)
        try:
            conn.detach_volume(att, vm, vol)
            print(
                f"'{vol.id}' volume has been detached from fio '{vm.name}'"
                " server.")
            conn.delete_volume(vol)
            print(f"'{vol.id}' volume has been deleted.")
        except ResourceFailure as e:
            print(
                f"Cleanup of '{vm.id}' with volume '{vol.id}' attached "
                f"failed with '{e.message}' error.")
            conn.delete_volume(vol)
    conn.delete_server(vm)
    print(f"'{vm.name}' server has been deleted.")


if __name__ == "__main__":
    # Find fio VMs
    vms = list(compute.servers(name=CLIENT_NAME_MASK, details=False))

    # Delete fio VMs in parallel in batches of CONCURRENCY size
    with mp.Pool(processes=CONCURRENCY) as pool:
        results = [pool.apply_async(delete_fio_client, (vm.id,)) for vm in vms]
        # Waits for batch of fio VMs to be deleted
        _ = [r.get() for r in results]

    # Remove ports from fio router (including external GW)
    router = network.find_router(ROUTER_NAME)
    if router:
        network.update_router(router.id, external_gateway_info={})
        print("External GW port has been deleted from fio router.")
        router_ports = network.ports(device_id=router.id)
        for p in router_ports:
            if p.device_owner != "network:router_ha_interface":
                network.remove_interface_from_router(router.id, port_id=p.id)
                print(f"'{p.id}' port has been deleted from fio router.")

    # Delete fio network topology
    net = network.find_network(NET_NAME)
    if net:
        network.delete_network(net.id)
        print(f"fio '{net.id}' network has been deleted.")
    if router:
        network.delete_router(router.id)
        print(f"fio '{router.id}' router has been deleted.")

    # Delete fio flavor
    flavor = compute.find_flavor(FLAVOR_NAME)
    if flavor:
        compute.delete_flavor(flavor.id)
        print(f"fio '{flavor.id}' flavor has been deleted.")

    # # Delete fio keypair
    kp = compute.find_keypair(KEYPAIR_NAME)
    if kp:
        compute.delete_keypair(kp)
        print(f"fio '{kp.id}' keypair has been deleted.")

    # Delete fio security group
    sg = network.find_security_group(SG_NAME)
    if sg:
        network.delete_security_group(sg)
        print(f"fio '{sg.id}' security group has been deleted.")

    # Delete fio server group
    server_group = conn.find_server_group(AA_SERVER_GROUP_NAME)
    if server_group:
        compute.delete_server_group(server_group)
        print(f"fio '{server_group.name}' server group has been deleted.")
