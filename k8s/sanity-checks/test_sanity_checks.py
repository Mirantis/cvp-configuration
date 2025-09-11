import pytest

from si_tests import settings
from si_tests.clients import k8s as k8s_client
from si_tests.fixtures.kubectl import kcm_manager


@pytest.fixture
def ready_child_cluster(request, kcm_manager):
    namespace, name = request.param
    return namespace, name


def pytest_generate_tests(metafunc):
    if "ready_child_cluster" in metafunc.fixturenames:
        clds = get_ready_cluster_deployments(kcm_manager())
        metafunc.parametrize("ready_child_cluster",
                             range(len(clds)), indirect=True)


def get_ready_cluster_deployments(kcm_manager):
    ready_clds = []
    clds = kcm_manager.list_all_clusterdeployments()

    for cld in clds:
        conditions = cld.data.get("status", {}).get("conditions", [])
        for cond in conditions:
            if cond["type"] == "Ready" and cond["status"] == "True":
                ready_clds.append((cld.namespace, cld.name))
                break
    return ready_clds


def check_cluster_deployment_exists(kcm_manager, namespace, name) -> bool:
    clds = kcm_manager.list_all_clusterdeployments()
    return any(cld.namespace == namespace and cld.name == name for cld in clds)


@pytest.mark.sanity
def test_k0rdent_mgmt_object_readiness(kcm_manager):
    assert kcm_manager.mgmt.ready == True,\
        f"Management 'kcm' object is not ready"


@pytest.mark.sanity
def test_cluster_deployments_are_ready(kcm_manager):
    not_ready_clds = []
    clds = kcm_manager.list_all_clusterdeployments()
    for cld in clds:
        conditions = cld.data.get("status", {}).get("conditions", [])
        for cond in conditions:
            if cond["type"] == "Ready" and cond["status"] != "True":
                not_ready_clds.append((cld.namespace, cld.name))
                break
    assert not_ready_clds == [],\
        f"There are some cluster deployments not ready: {not_ready_clds}"


@pytest.mark.sanity
def test_provider_templates_are_valid(kcm_manager):
    k8s = k8s_client.K8sCluster(kubeconfig=settings.KUBECONFIG_PATH)
    provider_templates = k8s.k0rdent_provider_templates.list_raw().items
    invalid_res = []
    for pt in provider_templates:
        if not pt.status['valid']:
            invalid_res.append({"name": pt.metadata.name,
                                "valid": pt.status['valid']})
    assert not invalid_res, f"Invalid provider templates found: {invalid_res}"


@pytest.mark.sanity
def test_cluster_templates_are_valid(kcm_manager):
    k8s = k8s_client.K8sCluster(kubeconfig=settings.KUBECONFIG_PATH)
    cluster_templates = k8s.k0rdent_cluster_templates.list_raw().items
    invalid_res = []
    for ct in cluster_templates:
        if not ct.status['valid']:
            invalid_res.append({"name": ct.metadata.name,
                                "valid": ct.status['valid']})
    assert not invalid_res, f"Invalid cluster templates found: {invalid_res}"


@pytest.mark.sanity
def test_service_templates_are_valid(kcm_manager):
    k8s = k8s_client.K8sCluster(kubeconfig=settings.KUBECONFIG_PATH)
    service_templates = k8s.k0rdent_service_templates.list_raw().items
    invalid_res = []
    for st in service_templates:
        if not st.status['valid']:
            invalid_res.append({"name": st.metadata.name,
                                "valid": st.status['valid']})
    assert not invalid_res, f"Invalid service templates found: {invalid_res}"


@pytest.mark.sanity
def test_k0rdent_mgmt_pods_readiness(
        kcm_manager, namespaces=None, allowed_phases=None):
    """Check k0rdent mgmt cluster pods readiness"""
    if namespaces is None:
        namespaces = ["kcm-system", "projectsveltos"]
    if allowed_phases is None:
        allowed_phases = ("Running", "Succeeded")

    for ns in namespaces:
        pods = kcm_manager.api.pods.list(namespace=ns)
        assert pods, f"No pods found in namespace '{ns}'"

        for pod in pods:
            phase = pod.data["status"]["phase"]
            assert phase in allowed_phases, (
                f"Pod '{pod.name}' in namespace '{ns}' is in phase '{phase}', "
                f"expected one of {allowed_phases}"
            )


@pytest.mark.sanity
def test_k0rdent_mgmt_nodes_readiness(kcm_manager):
    """Check k0rdent mgmt cluster nodes readiness"""
    nodes = kcm_manager.api.nodes.list()
    assert nodes, "No nodes found in the cluster"

    for node in nodes:
        conditions = node.data["status"]["conditions"]
        ready_condition = next((c for c in conditions if c["type"] == "Ready"),
                               None)
        assert ready_condition is not None,\
            f"Node '{node.name}' has no Ready condition"
        assert ready_condition["status"] == "True",\
            f"Node '{node.name}' is not Ready"


@pytest.mark.sanity_targeted
def test_check_target_child_cluster_readiness(kcm_manager):
    """Check the target child cluster readiness"""
    ns = kcm_manager.get_namespace(settings.TARGET_NAMESPACE)
    cld = ns.get_cluster_deployment(settings.TARGET_CLD)
    if not check_cluster_deployment_exists(
            kcm_manager, settings.TARGET_NAMESPACE, settings.TARGET_CLD):
        pytest.skip(f"Target cluster deployment '{cld.name}' is not found in "
                    f"namespace '{settings.TARGET_NAMESPACE}'. Please check "
                    f"TARGET_NAMESPACE and TARGET_CLD env vars.")
    cld.check.check_cluster_readiness(timeout=600)
    cld.check.check_k8s_pods()
    cld.check.check_k8s_nodes()


@pytest.mark.sanity
def test_check_all_child_clusters_readiness(kcm_manager, subtests):
    ready_clds = get_ready_cluster_deployments(kcm_manager)
    assert ready_clds, "No ready child clusters found"

    for namespace, cld_name in ready_clds:
        label = f"{cld_name} ({namespace})"
        with subtests.test(cluster=label):
            ns = kcm_manager.get_namespace(namespace)
            cld = ns.get_cluster_deployment(cld_name)

            cld.check.check_cluster_readiness(timeout=600)
            cld.check.check_k8s_pods()
            cld.check.check_k8s_nodes()
