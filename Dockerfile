FROM xrally/xrally-openstack:0.10.1

SHELL ["/bin/bash", "-xec"]

USER root

RUN apt-get update; apt-get install -y inetutils-ping curl wget

WORKDIR /var/lib/

RUN mkdir -p cvp-configuration

RUN git clone https://github.com/openstack/tempest && \
    pushd tempest; git checkout 17.2.0; pip install -r requirements.txt; \
    popd;

RUN git clone https://github.com/openstack/telemetry-tempest-plugin && \
    pushd telemetry-tempest-plugin; git checkout 7a4bff728fbd8629ec211669264ab645aa921e2b; pip install -r requirements.txt; \
    popd;

RUN git clone https://github.com/openstack/heat-tempest-plugin && \
    pushd heat-tempest-plugin; git checkout 12b770e923060f5ef41358c37390a25be56634f0; pip install -r requirements.txt; \
    popd;

COPY rally/ /var/lib/cvp-configuration/rally
COPY tempest/ /var/lib/cvp-configuration/tempest
COPY cleanup.sh  /var/lib/cvp-configuration/cleanup.sh
COPY configure.sh /var/lib/cvp-configuration/configure.sh

WORKDIR /home/rally

ENTRYPOINT ["/bin/bash"]
