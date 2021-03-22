#!/bin/bash
function get_name() {
  while [[ $pod_name = "none" ]]; do
    name=$(kubectl get pods -n openstack --no-headers -o custom-columns=":metadata.name" | grep openstack-tempest-run-tests || echo none)
    if [[ ${name} != "none" ]]; then
      echo $name
      break
    else
      echo "# Pod not found, waiting"
      sleep 5
    fi
  done
}

pod_name="none"
pod_name=$(get_name)
watch -n 1 "kubectl logs ${pod_name} -c tempest-run-tests -n openstack | tail -40"
