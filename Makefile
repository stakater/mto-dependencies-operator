DETECTED_OS := $(shell uname -s)
OS := $(patsubst Darwin,darwin,$(patsubst Linux,linux,$(DETECTED_OS)))
# Simplified mapping for common scenarios
map_os = $(patsubst Darwin,darwin,$(patsubst Linux,linux,$(1)))
map_arch = $(patsubst x86_64,amd64,$(patsubst aarch64,arm64,$(1)))
DETECTED_ARCH := $(shell uname -m)

# Use the mapping function for OS and architecture
ARCH := $(call map_arch,$(DETECTED_ARCH))

ifeq ($(OS),darwin)
  SED := gsed
  SHELL := /bin/zsh
  ifeq (, $(shell command -v $(SED) 2>/dev/null))
    $(error gsed not found. Please install with: brew install gnu-sed)
  endif
else
  SED := sed
  SHELL := /bin/bash
endif

# VERSION defines the project version for the bundle.
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=0.0.3)
# - use environment variables to overwrite this value (e.g export VERSION=0.0.3)
VERSION ?= 0.0.6
OPERATOR_NAME ?= mto-dependencies-operator
CATALOG_DIR_PATH ?= catalog
DOCKER_REPO_BASE ?= ghcr.io/stakater

OPERATOR_NAMESPACE ?= $(OPERATOR_NAME)-system

MAJOR:=$(shell awk -F. '{print $$1}' <<< $(VERSION))
MINOR:=$(shell awk -F. '{print $$2}' <<< $(VERSION))
# CHANNELS := release-$(MAJOR).$(MINOR)
CHANNELS := alpha

# CHANNELS define the bundle channels used in the bundle.
# Add a new line here if you would like to change its default config. (E.g CHANNELS = "candidate,fast,stable")
# To re-generate a bundle for other specific channels without changing the standard setup, you can:
# - use the CHANNELS as arg of the bundle target (e.g make bundle CHANNELS=candidate,fast,stable)
# - use environment variables to overwrite this value (e.g export CHANNELS="candidate,fast,stable")
ifneq ($(origin CHANNELS), undefined)
BUNDLE_CHANNELS := --channels=$(CHANNELS)
endif

# DEFAULT_CHANNEL defines the default channel used in the bundle.
# Add a new line here if you would like to change its default config. (E.g DEFAULT_CHANNEL = "stable")
# To re-generate a bundle for any other default channel without changing the default setup, you can:
# - use the DEFAULT_CHANNEL as arg of the bundle target (e.g make bundle DEFAULT_CHANNEL=stable)
# - use environment variables to overwrite this value (e.g export DEFAULT_CHANNEL="stable")
DEFAULT_CHANNEL=$(CHANNELS)
ifneq ($(origin DEFAULT_CHANNEL), undefined)
BUNDLE_DEFAULT_CHANNEL := --default-channel=$(DEFAULT_CHANNEL)
endif
BUNDLE_METADATA_OPTS ?= $(BUNDLE_CHANNELS) $(BUNDLE_DEFAULT_CHANNEL)

# IMAGE_TAG_BASE defines the docker.io namespace and part of the image name for remote images.
# This variable is used to construct full image tags for bundle and catalog images.
#
# For example, running 'make bundle-build bundle-push catalog-build catalog-push' will build and push both
# stakater.com/mto-dependencies-operator-bundle:$VERSION and stakater.com/mto-dependencies-operator-catalog:$VERSION.
IMAGE_TAG_BASE ?= $(DOCKER_REPO_BASE)/$(OPERATOR_NAME)
OPERATOR_HUB_IMAGE_TAG_BASE ?= registry.connect.redhat.com/stakater/$(OPERATOR_NAME)


# BUNDLE_IMG defines the image:tag used for the bundle.
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMG=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMG ?= $(IMAGE_TAG_BASE)-bundle:v$(VERSION)$(GIT_TAG)

# BUNDLE_GEN_FLAGS are the flags passed to the operator-sdk generate bundle command
BUNDLE_GEN_FLAGS ?= -q --overwrite --version $(VERSION) $(BUNDLE_METADATA_OPTS)

# USE_IMAGE_DIGESTS defines if images are resolved via tags or digests
# You can enable this value if you would like to use SHA Based Digests
# To enable set flag to true
USE_IMAGE_DIGESTS ?= true
ifeq ($(USE_IMAGE_DIGESTS), true)
	BUNDLE_GEN_FLAGS += --use-image-digests
endif


# Set the Operator SDK version to use. By default, what is installed on the system is used.
# This is useful for CI or a project to utilize a specific version of the operator-sdk toolkit.
OPERATOR_SDK_VERSION ?= v1.41.1

# Container tool to use for building and pushing images
CONTAINER_TOOL ?= docker

# Image URL to use all building/pushing image targets
IMG ?= $(IMAGE_TAG_BASE):v$(VERSION)$(GIT_TAG)

# Image URL to use all building/pushing image targets
IMAGE_DIGEST ?= sha256:657f0e273f646c87aad81d9468c5b2fb593aab00397a4c9350568525652b52da
OPERATOR_HUB_IMG ?= $(OPERATOR_HUB_IMAGE_TAG_BASE)@$(IMAGE_DIGEST)

.PHONY: all
all: docker-build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Testing

.PHONY: lint
lint: ## Lint all helm charts by templating them
	@echo "Linting helm charts..."
	@for chart in helm-charts/*/; do \
		chart_name=$$(basename $$chart); \
		echo "✓ Linting $$chart_name chart..."; \
		helm template $$chart_name $$chart > /dev/null || exit 1; \
		helm lint $$chart || exit 1; \
	done
	@echo "✓ All helm charts linted successfully!"

.PHONY: test
test: 
	echo "NO UNIT TESTS; SKIPPING ..."

.PHONY: manifests
manifests:
	echo "NO MANIFESTS TO GENERATE; SKIPPING ..."

.PHONY: build
build: lint
	echo "NO BUILD STEP; SKIPPING ..."

.PHONY: test-e2e
test-e2e: ## Run end-to-end tests
	./tests/run_tests.sh

.PHONY: test-integration-parallel
test-integration-parallel: ## Run integration tests in parallel
	./tests/run_tests.sh --parallel

.PHONY: test-dex
test-dex: ## Run only Dex integration test
	./tests/run_tests.sh dex

.PHONY: test-prometheus
test-prometheus: ## Run only Prometheus integration test
	./tests/run_tests.sh prometheus

.PHONY: test-kube-state-metrics
test-kube-state-metrics: ## Run only KubeStateMetrics integration test
	./tests/run_tests.sh kube_state_metrics

.PHONY: test-postgres
test-postgres: ## Run only Postgres integration test
	./tests/run_tests.sh postgres

.PHONY: test-opencost
test-opencost: ## Run only OpenCost integration test
	./tests/run_tests.sh opencost

##@ Build

.PHONY: run
run: helm-operator ## Run against the configured Kubernetes cluster in ~/.kube/config
	$(HELM_OPERATOR) run

.PHONY: docker-build
docker-build: ## Build docker image with the manager.
	$(CONTAINER_TOOL) build -t ${IMG} . --build-arg VERSION=${VERSION} --build-arg RELEASE=${RELEASE}

.PHONY: docker-push
docker-push: ## Push docker image with the manager.
	$(CONTAINER_TOOL) push ${IMG}

# PLATFORMS defines the target platforms for  the manager image be build to provide support to multiple
# architectures. (i.e. make docker-buildx IMG=myregistry/mypoperator:0.0.1). To use this option you need to:
# - able to use docker buildx . More info: https://docs.docker.com/build/buildx/
# - have enable BuildKit, More info: https://docs.docker.com/develop/develop-images/build_enhancements/
# - be able to push the image for your registry (i.e. if you do not inform a valid value via IMG=<myregistry/image:<tag>> than the export will fail)
# To properly provided solutions that supports more than one platform you should use this option.
PLATFORMS ?= linux/arm64,linux/amd64,linux/s390x,linux/ppc64le
.PHONY: docker-buildx
docker-buildx: ## Build and push docker image for the manager for cross-platform support
	- $(CONTAINER_TOOL) buildx create --name project-v3-builder
	$(CONTAINER_TOOL) buildx use project-v3-builder
	- $(CONTAINER_TOOL) buildx build --push --platform=$(PLATFORMS) --tag ${IMG} -f Dockerfile .
	- $(CONTAINER_TOOL) buildx rm project-v3-builder

.PHONY: build-installer
build-installer: kustomize ## Generate a consolidated YAML with CRDs and deployment.
	mkdir -p dist
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default > dist/install.yaml

##@ Deployment

.PHONY: install
install: kustomize ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

.PHONY: uninstall
uninstall: kustomize ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

.PHONY: cluster
cluster: ## Setup Kind cluster with specified action (default: cluster). Usage: make cluster ACTION=<action>
	curl -sSL https://raw.githubusercontent.com/stakater/.github/refs/heads/main/.github/scripts/setup-kind-cluster.sh | \
	TEST_CLUSTER_NAME=$(TEST_CLUSTER_NAME) \
	IMG=$(IMG) \
	CONTAINER_TOOL=$(CONTAINER_TOOL) \
	KIND_VERSION=$(KIND_VERSION) \
	LOCALBIN=$(LOCALBIN) \
	OPERATOR_NAMESPACE=$(OPERATOR_NAMESPACE) \
	PULL_SECRET_NAME=saap-dockerconfigjson \
	GHCR_USERNAME=$(GHCR_USERNAME) \
	GHCR_TOKEN=$(GHCR_TOKEN) \
	bash -s all


.PHONY: deploy
deploy: cluster kustomize ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

.PHONY: undeploy
undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/default | kubectl delete -f -

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

# Test cluster name for kind
TEST_CLUSTER_NAME ?= e2e-test-cluster

.PHONY: kind
KIND = $(shell pwd)/bin/kind
kind: ## Download kind locally if necessary.
ifeq (,$(wildcard $(KIND)))
ifeq (,$(shell which kind 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(KIND)) ;\
	curl -sSLo $(KIND) https://github.com/kubernetes-sigs/kind/releases/download/v0.30.0/kind-$(OS)-$(ARCH) ;\
	chmod +x $(KIND) ;\
	}
else
KIND = $(shell which kind)
endif
endif

.PHONY: kustomize
KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
ifeq (,$(wildcard $(KUSTOMIZE)))
ifeq (,$(shell which kustomize 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(KUSTOMIZE)) ;\
	curl -sSLo - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v5.6.0/kustomize_v5.6.0_$(OS)_$(ARCH).tar.gz | \
	tar xzf - -C bin/ ;\
	}
else
KUSTOMIZE = $(shell which kustomize)
endif
endif

LOCALBIN = $(shell pwd)/bin/

.PHONY: helm-operator
HELM_OPERATOR = $(shell pwd)/bin/helm-operator
helm-operator: ## Download helm-operator locally if necessary, preferring the $(pwd)/bin path over global if both exist.
ifeq (,$(wildcard $(HELM_OPERATOR)))
ifeq (,$(shell which helm-operator 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(HELM_OPERATOR)) ;\
	curl -sSLo $(HELM_OPERATOR) https://github.com/operator-framework/operator-sdk/releases/download/v1.42.0/helm-operator_$(OS)_$(ARCH) ;\
	chmod +x $(HELM_OPERATOR) ;\
	}
else
HELM_OPERATOR = $(shell which helm-operator)
endif
endif

.PHONY: operator-sdk
OPERATOR_SDK ?= $(LOCALBIN)/operator-sdk
operator-sdk: ## Download operator-sdk locally if necessary.
ifeq (,$(wildcard $(OPERATOR_SDK)))
ifeq (, $(shell which operator-sdk 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPERATOR_SDK)) ;\
	curl -sSLo $(OPERATOR_SDK) https://github.com/operator-framework/operator-sdk/releases/download/$(OPERATOR_SDK_VERSION)/operator-sdk_$(OS)_$(ARCH) ;\
	chmod +x $(OPERATOR_SDK) ;\
	}
else
OPERATOR_SDK = $(shell which operator-sdk)
endif
endif

CSV_FILE_PATH ?= ./bundle/manifests/$(OPERATOR_NAME).clusterserviceversion.yaml
CSV_NAME ?= $(OPERATOR_NAME).v$(VERSION)
OLM_SKIP_RANGE_ANNOTATION ?= olm.skipRange: <$(VERSION)
ANNOTATIONS_FILE_PATH ?= ./bundle/metadata/annotations.yaml
SUPPORTED_OPENSHIFT_VERSION_ANNOTATION ?= com.redhat.openshift.versions: 'v4.12'

.PHONY: bundle
bundle: kustomize operator-sdk ## Generate bundle manifests and metadata, then validate generated files.
	$(OPERATOR_SDK) generate kustomize manifests -q
	cd config/manager && $(KUSTOMIZE) edit set image controller=$(OPERATOR_HUB_IMG)
	$(KUSTOMIZE) build config/manifests | $(OPERATOR_SDK) generate bundle $(BUNDLE_GEN_FLAGS)
	$(SED) -i '/name: $(CSV_NAME)/i\    $(OLM_SKIP_RANGE_ANNOTATION)' $(CSV_FILE_PATH)
	printf "\n  $(SUPPORTED_OPENSHIFT_VERSION_ANNOTATION)\n" >> $(ANNOTATIONS_FILE_PATH)
	$(OPERATOR_SDK) bundle validate ./bundle

.PHONY: bundle-build
bundle-build: ## Build the bundle image.
	$(CONTAINER_TOOL) build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

.PHONY: bundle-push
bundle-push: ## Push the bundle image.
	$(MAKE) docker-push IMG=$(BUNDLE_IMG)

.PHONY: opm
OPM = $(LOCALBIN)/opm
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM)))
ifeq (,$(shell which opm 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v1.55.0/$(OS)-$(ARCH)-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which opm)
endif
endif

.PHONY: yq
YQ_VERSION := v4.13.0
YQ_BIN := $(LOCALBIN)/yq
yq:
ifeq (,$(wildcard $(YQ_BIN)))
ifeq (,$(shell which yq 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(YQ_BIN)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(YQ_BIN) https://github.com/mikefarah/yq/releases/download/$(YQ_VERSION)/yq_$${OS}-$${ARCH} ;\
	chmod +x $(YQ_BIN) ;\
	}
else
YQ_BIN = $(shell which yq)
endif
endif


# A comma-separated list of bundle images (e.g. make catalog-build BUNDLE_IMGS=example.com/operator-bundle:v0.1.0,example.com/operator-bundle:v0.2.0).
# These images MUST exist in a registry and be pull-able.
BUNDLE_IMGS ?= $(BUNDLE_IMG)

# The image tag given to the resulting catalog image (e.g. make catalog-build CATALOG_IMG=example.com/operator-catalog:v0.2.0).
CATALOG_IMG ?= $(IMAGE_TAG_BASE)-catalog:v$(VERSION)$(GIT_TAG)

# Set CATALOG_BASE_IMG to an existing catalog image tag to add $BUNDLE_IMGS to that image.
ifneq ($(origin CATALOG_BASE_IMG), undefined)
FROM_INDEX_OPT := --from-index $(CATALOG_BASE_IMG)
endif

# Render bundle to the catalog index.
.PHONY: catalog-render
catalog-render: opm yq ## Render bundle to catalog index.
	curl -sSL https://raw.githubusercontent.com/stakater/.github/refs/heads/main/.github/scripts/generate-catalog-index.sh | bash -s -- "$(DOCKER_REPO_BASE)" "$(OPERATOR_NAME)" "$(CATALOG_DIR_PATH)" "$(VERSION)" "$(GIT_TAG)"

# Build a catalog image by adding bundle images to an empty catalog using the operator package manager tool, 'opm'.
# This recipe invokes 'opm' in 'semver' bundle add mode. For more information on add modes, see:
# https://github.com/operator-framework/community-operators/blob/7f1438c/docs/packaging-operator.md#updating-your-existing-operator
.PHONY: catalog-build
catalog-build: opm ## Build a catalog image.
	$(OPM) index add --container-tool $(CONTAINER_TOOL) --mode semver --tag $(CATALOG_IMG) --bundles $(BUNDLE_IMGS) $(FROM_INDEX_OPT)

# Push the catalog image.
.PHONY: catalog-push
catalog-push: ## Push a catalog image.
	$(MAKE) docker-push IMG=$(CATALOG_IMG)

HELM_MK_URL ?= https://raw.githubusercontent.com/stakater/.github/refs/heads/main/.github/makefiles/helm.mk
HELM_MK := makefiles/helm.mk

define download-file
	@if [ -f "$(2)" ]; then \
		echo "$(2) already exists; skipping download"; \
	else \
		echo "Downloading $(1) -> $(2)"; \
		mkdir -p $(dir $(2)); \
		curl -H 'Cache-Control: no-cache' -fsSL $(CURL_OPTS) "$(1)" -o "$(2)" || { echo "Failed to download $(1)"; exit 1; }; \
	fi
endef

.PHONY: download-helm-mk
download-helm-mk: ## Download remote makefile into makefiles/helm.mk (only if missing)
	$(call download-file,$(HELM_MK_URL),$(HELM_MK))

HELM_CHART_NAME ?= mto-dependencies-operator

#Pipeline will override this variable accordingly
HELM_REGISTRY ?= ghcr.io/stakater/charts

.PHONY: helm-release
helm-release: manifests kustomize download-helm-mk ## Download remote helm.mk and run its helm-package target
	@echo "Invoking downloaded helm makefile: $(HELM_MK)"
	$(MAKE) -f $(HELM_MK) helm-release \
		VERSION=$(VERSION) \
		GIT_TAG=$(GIT_TAG) \
		GIT_TOKEN=$(GHCR_TOKEN) \
		GIT_USER=$(GHCR_USERNAME) \
		KUSTOMIZE=$(KUSTOMIZE) \
		HELM_CHART_NAME=$(HELM_CHART_NAME) \
		HELM_REGISTRY=$(HELM_REGISTRY) \
		IMG=$(IMG) \

.PHONY: update-operator-hub-image-digest
update-operator-hub-image-digest: ## Update image digest
	$(SED) -i "s/^IMAGE_DIGEST ?=.*/IMAGE_DIGEST ?= $(IMAGE_DIGEST)/" Makefile
