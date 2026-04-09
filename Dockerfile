# Build the manager binary
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.7

ARG VERSION
ARG RELEASE=1

### Required OpenShift Labels
LABEL name="MTO Dependencies Operator" \
      maintainer="hello@stakater.com" \
      vendor="StakaterAB" \
      version="${VERSION}" \
      release="${RELEASE}"  \
      summary="Multi-tenancy support for Openshift cluster" \
      description="It enables cluster administrators to host multiple tenants on a single Openshift cluster"

ENV HOME=/opt/helm \
    USER_NAME=helm \
    USER_UID=1001

RUN echo "${USER_NAME}:x:${USER_UID}:0:${USER_NAME} user:${HOME}:/sbin/nologin" >> /etc/passwd


RUN mkdir -p ${HOME} \
 && curl -sSLo ${HOME}/helm-operator https://github.com/operator-framework/operator-sdk/releases/download/v1.42.0/helm-operator_linux_amd64 \
 && chmod +x ${HOME}/helm-operator \
 && mv ${HOME}/helm-operator /usr/local/bin/helm-operator

COPY watches.yaml ${HOME}/watches.yaml
COPY helm-charts  ${HOME}/helm-charts
COPY LICENSE /licenses/

WORKDIR ${HOME}
USER ${USER_UID}
ENTRYPOINT ["/usr/local/bin/helm-operator", "run", "--watches-file=./watches.yaml"]
