# Build the manager binary
FROM quay.io/operator-framework/helm-operator:v1.42

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

ENV HOME=/opt/helm
COPY watches.yaml ${HOME}/watches.yaml
COPY helm-charts  ${HOME}/helm-charts

COPY LICENSE /licenses/

WORKDIR ${HOME}
