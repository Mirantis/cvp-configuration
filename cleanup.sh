#!/bin/bash
export OS_INTERFACE='admin'
mask='rally_\|tempest_\|tempest-'
dry_run=false
clean_projects=false
make_servers_active=false

function show_help {
    printf "Resource cleaning script\nMask is: %s\n\t-h, -?\tShow this help\n\t-t\tDry run mode, no cleaning done\n\t-P\tForce cleaning of projects\n" ${mask}
}

OPTIND=1 # Reset in case getopts has been used previously in the shell.
while getopts "h?:tP" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    t)  dry_run=true
        printf "Running in dry-run mode\n"
        ;;
    S)  make_servers_active=true
        printf "Servers will be set to ACTIVE before deletion\n"
        ;;
    P)  clean_projects=true
        printf "Project cleanning enabled\n"
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

### Execute collected commands and flush the temp file
function _clean_and_flush {
    if [ "$dry_run" = true ] ; then
        return 0
    fi
    if [ -s ${cmds} ]; then
        echo "Processing $(cat ${cmds} | wc -l) commands"
        cat ${cmds} | openstack
        truncate -s 0 ${cmds}
    fi
}

### Users
function _clean_users {
    users=( $(openstack user list -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#users[@]} users containing '${mask}' found"
    printf "%s\n" ${users[@]} | xargs -I{} echo user delete {} >>${cmds}
    _clean_and_flush
}

### Roles
function _clean_roles {
    roles=( $(openstack role list -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#roles[@]} roles containing '${mask}' found"
    printf "%s\n" ${roles[@]} | xargs -I{} echo role delete {} >>${cmds}
    _clean_and_flush
}

### Projects
function _clean_projects {
    projects=( $(openstack project list -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#projects[@]} projects containing '${mask}' found"
    printf "%s\n" ${projects[@]} | xargs -I{} echo project delete {} >>${cmds}
    _clean_and_flush
}

### Servers
function _clean_servers {
    servers=( $(openstack server list --name ${mask} -c ID -f value) )
    echo "-> ${#servers[@]} servers containing '${mask}' found"
    if [ "$make_servers_active" = true ]; then
        printf "%s\n" ${servers[@]} | xargs -I{} echo server set --state active {} >>${cmds}
    fi
    printf "%s\n" ${servers[@]} | xargs -I{} echo server delete {} >>${cmds}
    _clean_and_flush
}

### Reset snapshot state and delete
function _clean_snapshots {
    snapshots=( $(openstack volume snapshot list --all -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#snapshots[@]} snapshots containing '${mask}' found"
    printf "%s\n" ${snapshots[@]} | xargs -I{} echo volume snapshot set --state available {} >>${cmds}
    printf "%s\n" ${snapshots[@]} | xargs -I{} echo volume snapshot delete {} >>${cmds}
    _clean_and_flush
}

function _clean_volumes {
    volumes=( $(openstack volume list --all -c ID -c Name -c Type -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#volumes[@]} volumes containing '${mask}' found"
    printf "%s\n" ${volumes[@]} | xargs -I{} echo volume set --state available {} >>${cmds}
    printf "%s\n" ${volumes[@]} | xargs -I{} echo volume delete {} >>${cmds}
    _clean_and_flush
}

### Volume types
function _clean_volume_types {
    vtypes=( $(openstack volume type list -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#vtypes[@]} volume types containing '${mask}' found"
    printf "%s\n" ${vtypes[@]} | xargs -I{} echo volume type delete {} >>${cmds}
    _clean_and_flush
}

### Images
function _clean_images {
    images=( $(openstack image list -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#images[@]} images containing '${mask}' found"
    printf "%s\n" ${images[@]} | xargs -I{} echo image delete {} >>${cmds}
    _clean_and_flush
}

### Sec groups
function _clean_sec_groups {
# openstack project list -c ID -c Name -f value | grep rally | cut -d' ' -f1 | xargs -I{} /bin/bash -c "openstack security group list | grep {}"
    projects=( $(openstack project list -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    sgroups=( $(printf "%s\n" ${projects[@]} | xargs -I{} /bin/bash -c "openstack security group list -c ID -c Project -f value | grep {} | cut -d' ' -f1") )
    echo "-> ${#sgroups[@]} security groups for project containing '${mask}' found"
    printf "%s\n" ${sgroups[@]} | xargs -I{} echo security group delete {} >>${cmds}
    _clean_and_flush
}

### Keypairs
function _clean_keypairs {
    keypairs=( $(openstack keypair list -c Name -f value | grep ${mask}) )
    echo "-> ${#keypairs[@]} keypairs containing '${mask}' found"
    printf "%s\n" ${keypairs[@]} | xargs -I{} echo keypair delete {} >>${cmds}
    _clean_and_flush
}

### Routers and Networks
function _clean_routers_and_networks {
    routers=( $(openstack router list -c ID -c Name -f value | grep ${mask} | cut -d ' ' -f1) )
    if [ ${#routers[@]} -eq 0 ]; then
        echo "-> No routers containing '${mask}' found"
    else
        echo "-> ${#routers[@]} routers containing '${mask}' found"
        echo "...unsetting gateways"
        printf "%s\n" ${routers[@]} | xargs -I{} echo router unset --external-gateway {} | openstack
        for router in ${routers[@]}; do
            r_ports=( $(openstack port list --router ${router} -f value -c ID) )
            if [ ${#r_ports[@]} -eq 0 ]; then
                echo "...no ports to unplug for ${router}"
            else
                for r_port in ${r_ports[@]}; do
                    echo "...removing port '${r_port}' from router '${router}'"
                    openstack router remove port ${router} ${r_port}
                done
            fi
        done
        printf "%s\n" ${routers[@]} | xargs -I{} echo router delete {} >>${cmds}
    fi

    networks=( $(openstack network list | grep "${mask}" | cut -d' ' -f2) )
    if [ ${#networks[@]} -eq 0 ]; then
        echo "-> No networks containing '${mask}' found"
    else
        ports=()
        subnets=()
        for((idx=0;idx<${#networks[@]};idx++)) do
            ports+=( $(openstack port list --network ${networks[idx]} -c ID -f value) )
            subnets+=( $(openstack subnet list --network ${networks[idx]} -c ID -f value) )
            echo "-> $((${idx}+1)) of ${#networks[@]}, total ${#ports[@]} ports, ${#subnets[@]} subnets"
        done
        printf "%s\n" ${ports[@]} | xargs -I{} echo port delete {} >>${cmds}
        printf "%s\n" ${subnets[@]} | xargs -I{} echo subnet delete {} >>${cmds}
        echo network delete ${networks[@]} >>${cmds}
        echo "-> ${#routers[@]} routers, ${#ports[@]} ports, ${#subnets[@]} subnets, ${#networks[@]} networks"
    fi
    _clean_and_flush
}

### Regions
function _clean_regions {
    regions=( $(openstack region list -c Region -f value | grep ${mask}) )
    echo "-> ${#regions[@]} regions containing '${mask}' found"
    printf "%s\n" ${regions[@]} | xargs -I{} echo region delete {} >>${cmds}
    _clean_and_flush
}

### Stacks
function _clean_stacks {
    # By default openstack denies use of global_index for everyone.
    # In case you want to have handy cleanup, consider updating policy.json here:
    # root@ctl0x:~# cat -n /etc/heat/policy.json | grep global_index
    # 48      "stacks:global_index": "rule:deny_everybody",
    # 73      "software_configs:global_index": "rule:deny_everybody",
    # After this you will be able to use --all option

    stacks=( $(openstack stack list --deleted --nested --hidden -c ID -c Name -f value | grep ${mask} | cut -d' ' -f1) )
    echo "-> ${#stacks[@]} stacks containing '${mask}' found"
    printf "%s\n" ${stacks[@]} | xargs -I{} echo stack check {} >>${cmds}
    printf "%s\n" ${stacks[@]} | xargs -I{} echo stack delete -y {} >>${cmds}
    _clean_and_flush
}

### Containers
function _clean_containers {
    containers=( $(openstack container list --all -c ID -c Name -f value | grep ${mask}) )
    echo "-> ${#containers[@]} containers containing '${mask}' found"
    printf "%s\n" ${containers[@]} | xargs -I{} echo container delete {} >>${cmds}
    _clean_and_flush
}

###################
### Main
###################
# temp file for commands
cmds=$(mktemp)
trap "rm -f ${cmds}" EXIT
echo "Using tempfile: '${cmds}'"

# Consider cleaning contrail resources carefully
# ...and only after that - clean projects

_clean_stacks
_clean_servers

_clean_users
_clean_roles
_clean_snapshots
_clean_volumes
_clean_volume_types
_clean_images
_clean_sec_groups
_clean_keypairs
_clean_routers_and_networks
_clean_regions
_clean_containers

# project cleaning disabled by default
# Coz cleaning Contrail with no projects is a hard task
if [ "$clean_projects" = true ]; then
    _clean_projects
fi

# remove temp file
rm ${cmds}
