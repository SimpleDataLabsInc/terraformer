NAME                 := terraformer
IMAGE_REPOSITORY     := gcr.io/prophecy-deployments/$(NAME)
IMAGE_REPOSITORY_DEV := $(IMAGE_REPOSITORY)/dev
REPO_ROOT            := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
VERSION              := $(shell cat "$(REPO_ROOT)/VERSION")
EFFECTIVE_VERSION    := $(shell $(REPO_ROOT)/hack/get-version.sh)

PROVIDER := all
IMAGE_REPOSITORY_PROVIDER := $(IMAGE_REPOSITORY)
ifneq ($(PROVIDER),all)
	IMAGE_REPOSITORY_PROVIDER := $(IMAGE_REPOSITORY)-$(PROVIDER)
endif

# default IMAGE_TAG if unset (overwritten in release test)
ifeq ($(IMAGE_TAG),)
	override IMAGE_TAG = $(EFFECTIVE_VERSION)
endif

LD_FLAGS             := "-w -X github.com/SimpleDataLabsInc/$(NAME)/pkg/version.gitVersion=$(IMAGE_TAG) -X github.com/SimpleDataLabsInc/$(NAME)/pkg/version.provider=$(PROVIDER)"

#########################################
# Rules for local development scenarios #
#########################################

COMMAND       := apply
ZAP_DEVEL     := true
ZAP_LOG_LEVEL := debug

.PHONY: run
run:
	# running `go run ./cmd/terraformer $(COMMAND)`
	go run -ldflags $(LD_FLAGS) -mod=vendor \
		./cmd/terraformer $(COMMAND) \
		--zap-devel=$(ZAP_DEVEL) \
		--zap-log-level=$(ZAP_LOG_LEVEL) \
		--configuration-configmap-name=example.infra.tf-config \
		--state-configmap-name=example.infra.tf-state \
		--variables-secret-name=example.infra.tf-vars

.PHONY: start
start: dev-kubeconfig docker-dev-image
	@docker run -it -v $(shell go env GOCACHE):/root/.cache/go-build \
		-v $(REPO_ROOT):/go/src/github.com/SimpleDataLabsInc/terraformer \
		-e KUBECONFIG=/go/src/github.com/SimpleDataLabsInc/terraformer/dev/kubeconfig.yaml \
		-e NAMESPACE=${NAMESPACE} \
		--name terraformer-dev --rm \
		$(IMAGE_REPOSITORY_DEV):$(VERSION) \
		make run COMMAND=$(COMMAND) ZAP_DEVEL=$(ZAP_DEVEL) ZAP_LOG_LEVEL=$(ZAP_LOG_LEVEL)

.PHONY: start-dev-container
start-dev-container: dev-kubeconfig docker-dev-image
	# starting dev container
	@docker run -it -v $(shell go env GOCACHE):/root/.cache/go-build \
		-v $(REPO_ROOT):/go/src/github.com/SimpleDataLabsInc/terraformer \
		-v $(REPO_ROOT)/bin/container:/go/src/github.com/SimpleDataLabsInc/terraformer/bin \
		-e KUBEBUILDER_ASSETS=/go/src/github.com/SimpleDataLabsInc/terraformer/bin/kubebuilder/bin \
		-e KUBECONFIG=/go/src/github.com/SimpleDataLabsInc/terraformer/dev/kubeconfig.yaml \
		-e NAMESPACE=${NAMESPACE} \
		--name terraformer-dev --rm \
		$(IMAGE_REPOSITORY_DEV):$(VERSION) \
		bash

.PHONY: docker-dev-image
docker-dev-image:
	@DOCKER_BUILDKIT=1 docker build -t $(IMAGE_REPOSITORY_DEV):$(VERSION) --rm --target dev \
		--build-arg BUILDKIT_INLINE_CACHE=1 --build-arg PROVIDER=aws .

.PHONY: dev-kubeconfig
dev-kubeconfig:
	@mkdir -p dev
	@kubectl config view --raw | sed -E 's/127.0.0.1|localhost/host.docker.internal/' > dev/kubeconfig.yaml

#################################################################
# Rules related to binary build, Docker image build and release #
#################################################################

.PHONY: install
install:
	@LD_FLAGS=$(LD_FLAGS) $(REPO_ROOT)/vendor/github.com/gardener/gardener/hack/install.sh ./cmd/terraformer...

.PHONY: build
build: docker-images bundle-clean

.PHONY: release
release: build docker-login docker-push-all

.PHONY: docker-images
docker-images:
	@$(MAKE) docker-image PROVIDER=aws

.PHONY: docker-image
docker-image:
	# building docker image with tag $(IMAGE_REPOSITORY_PROVIDER):$(IMAGE_TAG)
	@DOCKER_BUILDKIT=1 docker build -t $(IMAGE_REPOSITORY_PROVIDER):$(IMAGE_TAG) --rm --target terraformer \
		--build-arg BUILDKIT_INLINE_CACHE=1 --build-arg PROVIDER=$(PROVIDER) -- .

.PHONY: docker-login
docker-login:
	@gcloud auth activate-service-account --key-file .kube-secrets/gcr/gcr-readwrite.json

.PHONY: docker-push-all
docker-push-all:
	@$(MAKE) docker-push PROVIDER=aws

.PHONY: docker-push
docker-push:
	@if ! docker images $(IMAGE_REPOSITORY_PROVIDER) | awk '{ print $$2 }' | grep -q -F $(IMAGE_TAG); then echo "$(IMAGE_REPOSITORY_PROVIDER) version $(IMAGE_TAG) is not yet built. Please run 'make docker-images'"; false; fi
	@gcloud docker -- push $(IMAGE_REPOSITORY_PROVIDER):$(IMAGE_TAG)

.PHONY: bundle-clean
bundle-clean:
	@rm -f terraform-provider*
	@rm -f terraform
	@rm -f terraform*.zip
	@rm -rf bin/