import argparse
import os
import re
import sys

import openstack


# Send logs to both, a log file and stdout
openstack.enable_logging(debug=False, path='openstack.log', stream=sys.stdout)

# Connect to cloud
TEST_CLOUD = os.getenv('OS_TEST_CLOUD', 'os-cloud')
cloud = openstack.connect(cloud=TEST_CLOUD)
log = cloud.log

# Get cloud config (clouds.yaml vars)
config_obj = openstack.config.loader.OpenStackConfig()
cloud_config = config_obj.get_one(cloud=TEST_CLOUD)

compute = cloud.compute
identity = cloud.identity
image = cloud.image
network = cloud.network
orchestration = cloud.orchestration
volume = cloud.volume
load_balancer = cloud.load_balancer

# Check if Object Storage is present on the cloud, else skip
object_store_present = any(service.type == 'object-store' for service
                           in list(identity.services()))
if object_store_present:
    object_store = cloud.object_store

mask = "cvp|s_rally|rally_|tempest-|tempest_|spt|fio"
full_mask = f"^(?!.*(manual|-static-)).*({mask}).*$"
mask_pattern = re.compile(full_mask, re.IGNORECASE)
stack_mask = "api-[0-9]+-[a-z]+"
stack_pattern = re.compile(stack_mask, re.IGNORECASE)


def get_resource_value(resource_key, default):
    try:
        return cloud_config.config['custom_vars'][resource_key]
    except KeyError:
        return default


def _filter_test_resources(resources, attribute, pattern=mask_pattern):
    filtered_resources = {}
    for item in resources:
        # If there is no attribute in object, use just empty string as value
        value = getattr(item, attribute, '')
        # If the attribute value is None, use empty string instead, to be
        # able to run regex search
        if value is None:
            value = ''
        found = pattern.match(value)
        if found:
            filtered_resources[item.id] = getattr(item, attribute)
    return filtered_resources


def _log_resources_count(count, resource, pattern=mask):
    log.info(f"{count} {resource} containing '{pattern}' are found.")


def _log_resource_delete(id_, name, type_):
    log.info(f"... deleting {name} (id={id_}) {type_}")


def _force_delete_load_balancer(id_):
    log.info(f"... ... force deleting {id_} load balancer")
    lb_ep = load_balancer.get_endpoint()
    lb_uri = f"{lb_ep}/lbaas/loadbalancers/{id_}"
    headers = {'X-Auth-Token': cloud.session.get_token(),
               'Content-Type': 'application/json'}
    params = {'cascade': 'true', 'force': 'true'}
    cloud.session.request(url=lb_uri, method='DELETE',
                          headers=headers, params=params)


def cleanup_users():
    users = identity.users()
    users_to_delete = _filter_test_resources(users, 'name')
    _log_resources_count(len(users_to_delete), 'user(s)')
    if args.dry_run:
        return
    for id_ in users_to_delete:
        _log_resource_delete(id_, users_to_delete[id_], 'user')
        identity.delete_user(id_)


def cleanup_roles():
    roles = identity.roles()
    roles_to_delete = _filter_test_resources(roles, 'name')
    _log_resources_count(len(roles_to_delete), 'role(s)')
    if args.dry_run:
        return
    for id_ in roles_to_delete:
        _log_resource_delete(id_, roles_to_delete[id_], 'role')
        identity.delete_role(id_)


def cleanup_projects():
    projects = identity.projects()
    projects_to_delete = _filter_test_resources(projects, 'name')
    _log_resources_count(len(projects_to_delete), 'project(s)')
    if args.dry_run:
        return
    for id_ in projects_to_delete:
        _log_resource_delete(id_, projects_to_delete[id_], 'project')
        identity.delete_project(id_)


def cleanup_regions():
    regions = identity.regions()
    regions_to_delete = _filter_test_resources(regions, 'id')
    _log_resources_count(len(regions_to_delete), 'region(s)')
    if args.dry_run:
        return
    for id_ in regions_to_delete:
        _log_resource_delete(id_, id_, 'region')
        identity.delete_region(id_)


def cleanup_services():
    services = identity.services()
    services_to_delete = _filter_test_resources(services, 'name')
    _log_resources_count(len(services_to_delete), 'service(s)')
    if args.dry_run:
        return
    for id_ in services_to_delete:
        _log_resource_delete(id_, services_to_delete[id_], 'service')
        identity.delete_service(id_)


def cleanup_stacks(stacks_alt=False):
    stacks = orchestration.stacks()
    stacks_to_delete = _filter_test_resources(stacks, 'name')
    _log_resources_count(len(stacks_to_delete), 'stack(s)')

    # Use additional pattern for searching/deleting test Heat resources,
    # if enabled
    if stacks_alt:
        stacks_alt_to_delete = _filter_test_resources(
            stacks, 'name', stack_pattern)
        _log_resources_count(len(stacks_alt_to_delete), 'stack(s)', stack_mask)
        stacks_to_delete.update(stacks_alt_to_delete)

    if args.dry_run:
        return

    for id_ in stacks_to_delete:
        _log_resource_delete(id_, stacks_to_delete[id_], 'stack')
        stack_obj = orchestration.get_stack(id_)
        orchestration.delete_stack(id_)
        orchestration.wait_for_delete(stack_obj)


def cleanup_flavors():
    flavors = compute.flavors()
    flavors_to_delete = _filter_test_resources(flavors, 'name')
    _log_resources_count(len(flavors_to_delete), 'flavor(s)')
    if args.dry_run:
        return
    for id_ in flavors_to_delete:
        _log_resource_delete(id_, flavors_to_delete[id_], 'flavor')
        compute.delete_flavor(id_)


def cleanup_images():
    images = image.images()
    images_to_delete = _filter_test_resources(images, 'name')
    _log_resources_count(len(images_to_delete), 'image(s)')
    if args.dry_run:
        return
    for id_ in images_to_delete:
        _log_resource_delete(id_, images_to_delete[id_], 'image')
        image.delete_image(id_)


def cleanup_keypairs():
    keypairs = compute.keypairs()
    keypairs_to_delete = _filter_test_resources(keypairs, 'name')
    _log_resources_count(len(keypairs_to_delete), 'keypair(s)')
    if args.dry_run:
        return
    for id_ in keypairs_to_delete:
        _log_resource_delete(id_, keypairs_to_delete[id_], 'keypair')
        compute.delete_keypair(id_)


def cleanup_servers():
    servers = compute.servers(all_projects=True)
    servers_to_delete = _filter_test_resources(servers, 'name')
    _log_resources_count(len(servers_to_delete), 'server(s)')
    if args.dry_run:
        return
    for id_ in servers_to_delete:
        if args.servers_active:
            log.info(
                f"... resetting {servers_to_delete[id_]} (id={id_}) server "
                "state to 'active'")
            compute.reset_server_state(id_, 'active')
        _log_resource_delete(id_, servers_to_delete[id_], 'server')
        compute.delete_server(id_)
        srv_obj = compute.get_server(id_)
        compute.wait_for_delete(srv_obj)


def cleanup_snapshots():
    snapshots = volume.snapshots(all_projects=True)
    snapshots_to_delete = _filter_test_resources(snapshots, 'name')
    _log_resources_count(len(snapshots_to_delete), 'snapshot(s)')
    if args.dry_run:
        return
    for id_ in snapshots_to_delete:
        snapshot_obj = volume.get_snapshot(id_)
        volume.reset_snapshot(id_, 'available')
        _log_resource_delete(id_, snapshots_to_delete[id_], 'snapshot')
        volume.delete_snapshot(id_, force=True)
        volume.wait_for_delete(snapshot_obj)


def cleanup_volumes():
    volumes = volume.volumes(all_projects=True)
    volumes_to_delete = _filter_test_resources(volumes, 'name')
    _log_resources_count(len(volumes_to_delete), 'volume(s)')
    if args.dry_run:
        return
    for id_ in volumes_to_delete:
        volume.reset_volume_status(id_, 'available', 'detached', 'None')
        _log_resource_delete(id_, volumes_to_delete[id_], 'volume')
        volume.delete_volume(id_)
        vol_obj = volume.get_volume(id_)
        volume.wait_for_delete(vol_obj)


def cleanup_volume_groups():
    groups = volume.groups()
    groups_to_delete = _filter_test_resources(groups, 'name')
    _log_resources_count(len(groups_to_delete), 'volume group(s)')
    if args.dry_run:
        return
    for id_ in groups_to_delete:
        _log_resource_delete(id_, groups_to_delete[id_], 'volume group')
        volume.delete_group(id_)


def cleanup_volume_backups():
    backups = volume.backups(all_tenants=True)
    backups_to_delete = _filter_test_resources(backups, 'name')
    _log_resources_count(len(backups_to_delete), 'volume backup(s)')
    if args.dry_run:
        return
    for id_ in backups_to_delete:
        backup_obj = volume.get_backup(id_)
        _log_resource_delete(id_, backups_to_delete[id_], 'volume backup')
        volume.delete_backup(id_)
        volume.wait_for_delete(backup_obj)


def cleanup_volume_group_types():
    group_types = volume.group_types()
    group_types_to_delete = _filter_test_resources(group_types, 'name')
    _log_resources_count(len(group_types_to_delete), 'volume group type(s)')
    if args.dry_run:
        return
    for id_ in group_types_to_delete:
        _log_resource_delete(
            id_, group_types_to_delete[id_], 'volume group type')
        volume.delete_group_type(id_)


def cleanup_volume_types():
    volume_types = volume.types()
    volume_types_to_delete = _filter_test_resources(volume_types, 'name')
    _log_resources_count(len(volume_types_to_delete), 'volume type(s)')
    if args.dry_run:
        return
    for id_ in volume_types_to_delete:
        _log_resource_delete(id_, volume_types_to_delete[id_], 'volume type')
        volume.delete_type(id_)


def cleanup_sec_groups():
    sec_groups = network.security_groups()
    sec_groups_to_delete = _filter_test_resources(sec_groups, 'name')
    _log_resources_count(len(sec_groups_to_delete), 'security group(s)')
    if args.dry_run:
        return
    for id_ in sec_groups_to_delete:
        _log_resource_delete(id_, sec_groups_to_delete[id_], 'security group')
        network.delete_security_group(id_)


def cleanup_containers():
    containers = object_store.containers()
    containers_to_delete = _filter_test_resources(containers, 'name')
    _log_resources_count(len(containers_to_delete), 'container(s)')
    if args.dry_run:
        return
    for id_ in containers_to_delete:
        _log_resource_delete(id_, containers_to_delete[id_], 'container')
        object_store.delete_container(id_)


def cleanup_routers():
    routers = network.routers()
    routers_to_delete = _filter_test_resources(routers, 'name')
    _log_resources_count(len(routers_to_delete), 'router(s)')
    if args.dry_run:
        return
    for id_ in routers_to_delete:
        _log_resource_delete(id_, routers_to_delete[id_], 'router')

        # Unset external gateway and remove ports from router
        log.info("... ... removing external gateway from the router")
        network.update_router(id_, external_gateway_info={})
        ports = network.ports(device_id=id_)
        for p in ports:
            if p.device_owner != 'network:router_ha_interface':
                log.info(f"... ... removing port {p.id} from the router")
                network.remove_interface_from_router(id_, port_id=p.id)

        network.delete_router(id_)


def cleanup_networks():
    nets = network.networks()
    nets_to_delete = _filter_test_resources(nets, 'name')
    _log_resources_count(len(nets_to_delete), 'network(s)')
    if args.dry_run:
        return
    for id_ in nets_to_delete:
        _log_resource_delete(id_, nets_to_delete[id_], 'network')

        ports = network.ports(network_id=id_)
        for p in ports:
            log.info(
                f"... ... removing port {p.id} from the network")
            network.delete_port(p.id)
        subnets = network.subnets(network_id=id_)
        for s in subnets:
            log.info(
                f"... ... removing subnet {s.id} from the network")
            network.delete_subnet(s.id)

        network.delete_network(id_)


def cleanup_load_balancers():
    lbs = load_balancer.load_balancers()
    lbs_to_delete = _filter_test_resources(lbs, 'name')
    _log_resources_count(len(lbs_to_delete), 'load_balancer(s)')
    if args.dry_run:
        return
    for id_ in lbs_to_delete:
        _log_resource_delete(id_, lbs_to_delete[id_], 'load_balancer')
        try:
            load_balancer.delete_load_balancer(id_, cascade=True)
        except openstack.exceptions.ConflictException:
            # force delete the LB in case it is in some PENDING_* state
            _force_delete_load_balancer(id_)
        except Exception as e:
            log.info(f"... ... could not delete {id_} load balancer: {e}")


def cleanup_floating_ips():
    projects = identity.projects()
    list_projects_to_delete = list(_filter_test_resources(projects, 'name'))
    floating_ips = network.ips()
    fips_to_delete = {}
    for ip in floating_ips:
        # filter only non-associated IPs, only inside target projects
        if (ip.status == 'DOWN') and (ip.fixed_ip_address is None):
            if ip.project_id in list_projects_to_delete:
                fips_to_delete[ip.id] = ip.floating_ip_address
    _log_resources_count(len(fips_to_delete), 'floating ip(s)')
    if args.dry_run:
        return
    for id_ in fips_to_delete:
        _log_resource_delete(id_, fips_to_delete[id_], 'floating ip')
        network.delete_ip(id_)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='OpenStack test resources cleanup script')
    parser.add_argument(
        '-t', dest='dry_run', action='store_true',
        help='Dry run mode, no cleanup is done')
    parser.add_argument(
        '-P', dest='projects', action='store_true',
        help='Force cleanup of projects')
    parser.add_argument(
        '-S', dest='servers_active', action='store_true',
        help='Set servers to ACTIVE before deletion (reqiured by bare metal)')
    parser.add_argument(
        '-f', dest='stacks_alt', action='store_true',
        help='Use additional mask for stack cleanup')

    args = parser.parse_args()

    if args.dry_run:
        log.info("Running in dry-run mode")
    if args.servers_active:
        log.info("Servers will be set to ACTIVE before cleanup")
    if args.projects:
        log.info("Project cleanup is enabled")
    if args.stacks_alt:
        log.info(
            f"Stacks will be cleaned up using additional '{stack_mask}' mask")

    cleanup_stacks(stacks_alt=args.stacks_alt)
    cleanup_load_balancers()
    cleanup_servers()
    cleanup_flavors()
    try:  # Skip if cinder-backup service is not enabled
        cleanup_volume_backups()
    except openstack.exceptions.ResourceNotFound:
        pass
    cleanup_snapshots()
    cleanup_volumes()
    cleanup_volume_groups()
    cleanup_volume_group_types()
    cleanup_volume_types()
    cleanup_images()
    cleanup_sec_groups()
    cleanup_keypairs()
    cleanup_users()
    cleanup_roles()
    cleanup_services()
    cleanup_regions()
    cleanup_routers()
    cleanup_networks()
    if object_store_present:
        cleanup_containers()
    cleanup_floating_ips()

    if args.projects:
        cleanup_projects()

    msg = "Cleanup is FINISHED"
    log.info(f"\n{'=' * len(msg)}\n{msg}")
