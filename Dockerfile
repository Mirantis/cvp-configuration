FROM docker-dev-virtual.docker.mirantis.net/mirantis/cicd/ci-tempest:pike

RUN apt-get update && apt-get install --yes sudo python python-pip vim git-core build-essential libssl-dev libffi-dev python-dev

ARG RALLY_VERSION="0.10.1"

SHELL ["/bin/bash", "-xec"]

USER root

WORKDIR /var/lib/

RUN pip install --constraint /var/lib/openstack_requirements/upper-constraints.txt rally==$RALLY_VERSION

RUN mkdir -p cvp-configuration

COPY . /var/lib/cvp-configuration/
RUN mkdir /home/rally

RUN mkdir .rally && \
    echo "connection = \"sqlite:////home/rally/.rally/rally.db\"" > .rally/rally.conf &&\
    rally db recreate

WORKDIR /home/rally

ENTRYPOINT ["/bin/bash"]
