FROM xrally/xrally-openstack:0.10.1

SHELL ["/bin/bash", "-xec"]

USER root

RUN apt-get update; apt-get install -y iputils-ping curl wget

WORKDIR /var/lib/

RUN mkdir -p cvp-configuration

RUN git clone https://github.com/openstack/tempest && \
    pushd tempest; git checkout 17.2.0; \
    sed -i 's/length=15/length=32/g' /var/lib/tempest/tempest/lib/common/utils/data_utils.py; \
    pip install -r requirements.txt; \
    popd;

RUN git clone https://github.com/openstack/telemetry-tempest-plugin && \
    pushd telemetry-tempest-plugin; git checkout 7a4bff728fbd8629ec211669264ab645aa921e2b; pip install -r requirements.txt; \
    popd;

RUN git clone https://gerrit.mcp.mirantis.com/packaging/sources/heat-tempest-plugin && \
    pushd heat-tempest-plugin; git checkout mcp/ocata; pip install -r requirements.txt; \
    popd;

RUN pip install --force-reinstall python-cinderclient==3.2.0 python-glanceclient==2.11

RUN sed -i 's/uuid4())/uuid4()).replace("-","")/g' /usr/local/lib/python2.7/dist-packages/rally/plugins/openstack/scenarios/keystone/utils.py
RUN sed -i 's/uuid4())/uuid4()).replace("-","")/g' /usr/local/lib/python2.7/dist-packages/rally/plugins/openstack/context/keystone/users.py

COPY rally/ /var/lib/cvp-configuration/rally
COPY tempest/ /var/lib/cvp-configuration/tempest
COPY cleanup.sh  /var/lib/cvp-configuration/cleanup.sh
COPY configure.sh /var/lib/cvp-configuration/configure.sh

WORKDIR /home/rally

ENTRYPOINT ["/bin/bash"]
