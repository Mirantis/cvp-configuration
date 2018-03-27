

    import testtools
    @test.attr(type='full')
    @test.services('compute', 'network')
    @testtools.skipUnless(CONF.compute_feature_enabled.live_migration,
                          'Live migration must be enabled in tempest.conf')
    def test_live_migrate_to_all_nodes(self):
        # collect all active hosts in all az
        if not CONF.compute_feature_enabled.live_migration:
            raise cls.skipException(
                "Live migration is disabled")
        available_zone = \
            self.os_adm.availability_zone_client.list_availability_zones(
                detail=True)['availabilityZoneInfo']
        hosts = []
        for zone in available_zone:
            if zone['zoneState']['available']:
                for host in zone['hosts']:
                    if 'nova-compute' in zone['hosts'][host] and \
                        zone['hosts'][host]['nova-compute']['available']:
                        hosts.append({'zone': zone['zoneName'],
                                      'host_name': host})

        # ensure we have at least as many compute hosts as we expect
        if len(hosts) < CONF.compute.min_compute_nodes:
            raise exceptions.InvalidConfiguration(
                "Host list %s is shorter than min_compute_nodes. "
                "Did a compute worker not boot correctly?" % hosts)

        # Create 1 VM
        servers = []
        first_last_host = hosts[0]
        inst = self.create_server(
            availability_zone='%(zone)s:%(host_name)s' % hosts[0],
            wait_until='ACTIVE')
        server = self.servers_client.show_server(inst['id'])['server']
        # ensure server is located on the requested host
        self.assertEqual(hosts[0]['host_name'], server['OS-EXT-SRV-ATTR:host'])
        hosts.remove(first_last_host)
        hosts.append(first_last_host)

        # Live migrate to every host
        for host in hosts[:CONF.compute.min_compute_nodes]:
            self.servers_client.live_migrate_server(server_id=inst["id"],host=host['host_name'],block_migration=CONF.compute_feature_enabled.block_migration_for_live_migration,disk_over_commit=False)
            waiters.wait_for_server_status(self.servers_client, inst["id"], 'ACTIVE')
            server = self.servers_client.show_server(inst['id'])['server']
            # ensure server is located on the requested host
            self.assertEqual(host['host_name'], server['OS-EXT-SRV-ATTR:host'])


from tempest.lib.common.utils import test_utils
class TestServerSshAllComputes(manager.NetworkScenarioTest):
    credentials = ['primary', 'admin']


    @classmethod
    def setup_clients(cls):
        super(TestServerSshAllComputes, cls).setup_clients()
        # Use admin client by default
        cls.manager = cls.admin_manager
        # this is needed so that we can use the availability_zone:host
        # scheduler hint, which is admin_only by default
        cls.servers_client = cls.admin_manager.servers_client

    @test.attr(type='full')
    @test.services('compute', 'network')
    def test_ssh_to_all_nodes(self):
        available_zone = \
            self.os_adm.availability_zone_client.list_availability_zones(
                detail=True)['availabilityZoneInfo']
        hosts = []
        for zone in available_zone:
            if zone['zoneState']['available']:
                for host in zone['hosts']:
                    if 'nova-compute' in zone['hosts'][host] and \
                        zone['hosts'][host]['nova-compute']['available']:
                        hosts.append({'zone': zone['zoneName'],
                                      'host_name': host})

        # ensure we have at least as many compute hosts as we expect
        if len(hosts) < CONF.compute.min_compute_nodes:
            raise exceptions.InvalidConfiguration(
                "Host list %s is shorter than min_compute_nodes. "
                "Did a compute worker not boot correctly?" % hosts)

        servers = []

        # prepare key pair and sec group
        keypair = self.os_adm.keypairs_client.create_keypair(name="tempest-live")
        secgroup = self._create_security_group(security_groups_client=self.os_adm.security_groups_client, security_group_rules_client=self.os_adm.security_group_rules_client, tenant_id=self.os_adm.security_groups_client.tenant_id)

        # create 1 compute for each node, up to the min_compute_nodes
        # threshold (so that things don't get crazy if you have 1000
        # compute nodes but set min to 3).

        for host in hosts[:CONF.compute.min_compute_nodes]:
            inst = self.create_server(
                availability_zone='%(zone)s:%(host_name)s' % host,
                key_name=keypair['keypair']['name'])
            server = self.os_adm.servers_client.show_server(inst['id'])['server']
            # TODO we may create server with sec group instead of adding it
            self.os_adm.servers_client.add_security_group(server['id'],
                                                 name=secgroup['name'])
            
            # ensure server is located on the requested host
            self.assertEqual(host['host_name'], server['OS-EXT-SRV-ATTR:host'])
            # TODO maybe check validate = True?
            if CONF.network.public_network_id:
                # Check VM via ssh
                floating_ip = self.os_adm.compute_floating_ips_client.create_floating_ip(pool=CONF.network.floating_network_name)['floating_ip']
                self.addCleanup(test_utils.call_and_ignore_notfound_exc,
                        self.os_adm.compute_floating_ips_client.delete_floating_ip,
                        floating_ip['id'])
                self.os_adm.compute_floating_ips_client.associate_floating_ip_to_server(floating_ip['ip'], inst['id'])

                #   TODO maybe add this
                #    "Failed to find floating IP '%s' in server addresses: %s" %
                #   (floating_ip['ip'], server['addresses']))

                # check that we can SSH to the server
                self.linux_client = self.get_remote_client(
                    floating_ip['ip'], private_key=keypair['keypair']['private_key'])

            servers.append(server)

        # make sure we really have the number of servers we think we should
        self.assertEqual(
            len(servers), CONF.compute.min_compute_nodes,
            "Incorrect number of servers built %s" % servers)

        # ensure that every server ended up on a different host
        host_ids = [x['hostId'] for x in servers]
        self.assertEqual(
            len(set(host_ids)), len(servers),
            "Incorrect number of distinct host_ids scheduled to %s" % servers)
        self.os_adm.keypairs_client.delete_keypair(keypair['keypair']['name'])
