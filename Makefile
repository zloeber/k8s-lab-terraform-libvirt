SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT_PATH := $(abspath $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
BIN_PATH := $(ROOT_PATH)/.local/bin
KEY_PATH := $(ROOT_PATH)/.local/.ssh
KEY_NAME := $(KEY_PATH)/id_rsa

GIT_SITE := github.com
GIT_DESCRIPTION := A k8s lab using terraform/libvirt/qemu
GIT_REPO := zloeber/cka-lab-libvirt

POOL_NAME ?= cka_lab_images
POOL_PATH ?= $(shell pwd)/$(POOL_NAME)

terraform := $(BIN_PATH)/terraform
gh := $(BIN_PATH)/gh

# Generic shared variables
ifeq ($(shell uname -m),x86_64)
ARCH ?= "amd64"
endif
ifeq ($(shell uname -m),i686)
ARCH ?= "386"
endif
ifeq ($(shell uname -m),aarch64)
ARCH ?= "arm"
endif
ifeq ($(OS),Windows_NT)
OS := Windows
else
OS := $(shell sh -c 'uname -s 2>/dev/null || echo not' | tr '[:upper:]' '[:lower:]')
endif

TF_PROVIDER_PATH := $(ROOT_PATH)/terraform.d/plugins/$(OS)_$(ARCH)/terraform-provider-libvirt
TF_VERSION ?= 0.12.23

.PHONY: help
help: ## Help
	@echo 'Commands:'
	@grep -E '^[a-zA-Z_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

## Some helper scripts to bootstrap the project
.PHONY: .github/deps
.github/deps: ## Install github cli tool
	@[ -n "/tmp" ] && [ -n "gh" ] && rm -rf "/tmp/gh"
	@mkdir -p /tmp/gh $(BIN_PATH)
	@curl --retry 3 --retry-delay 5 --fail -sSL -o - https://github.com/cli/cli/releases/download/v0.6.4/gh_0.6.4_linux_amd64.tar.gz | tar -zx -C '/tmp/gh'
	@find /tmp/gh -type f -name 'gh*' | xargs -I {} cp -f {} $(gh)
	@chmod +x $(gh)
	@[ -n "/tmp" ] && [ -n "gh" ] && rm -rf "/tmp/gh"
	@echo "Installed: $(gh)"

.PHONY: .github/bootstrap
.github/bootstrap: .github/deps ## Create github repo if it doesn't exist
	git init || true
	git add --all .
	git commit -m 'initial commit'
	$(gh) repo create --repo $(GIT_REPO) --description "$(GIT_DESCRIPTION)" || true
	git remote rm origin || true
	git remote add origin git@$(GIT_SITE):$(GIT_REPO).git
	git push origin master || true

.PHONY: deps
deps: libvirt/pool/create keygen ## Install terraform dependencies
ifeq (,$(wildcard $(terraform)))
	@echo "Attempting to install terraform - $(TF_VERSION)"
	@mkdir -p $(BIN_PATH)
	@wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/$(TF_VERSION)/terraform_$(TF_VERSION)_$(OS)_$(ARCH).zip
	@unzip -d $(BIN_PATH) /tmp/terraform.zip && rm /tmp/terraform.zip
endif
ifeq (,$(wildcard $(TF_PROVIDER_PATH)))
	@echo "Attempting to grab the libvirt provider"
	@mkdir -p $(ROOT_PATH)/terraform.d/plugins/$(OS)_$(ARCH)
	$(ROOT_PATH)/init.sh
endif

.PHONY: keygen
keygen: ## Generate an ssh key for this deployment
ifeq (,$(wildcard $(KEY_NAME)))
	@mkdir -p $(KEY_PATH)
	ssh-keygen -t rsa -b 4096 -N '' -f $(KEY_NAME) -q
endif

.PHONY: docs
docs: ## Update module documentation with terraform-docs
	terraform-docs markdown ./ > DOCS.MD

.PHONY: validate
validate: ## Run terraform-validate against module
	terraform-validator .

.PHONY: libvirt/pool/create
libvirt/pool/create: ## Create storage pool locally
	## libvirt based setup of local image pool to localize running images to this location
	virsh pool-list --all
	virsh pool-define-as $(POOL_NAME) dir - - - - $(POOL_PATH) || true
	mkdir -p $(POOL_PATH)
	virsh pool-start $(POOL_NAME) || true
	virsh pool-autostart $(POOL_NAME) || true
	virsh pool-info $(POOL_NAME) || true

.PHONY: libvirt/pool/remove
libvirt/pool/remove: ## Removes local storage pool
	virsh pool-destroy ${POOL_NAME} || true
	virsh pool-undefine ${POOL_NAME} || true

.PHONY: libvirt/domain/remove
libvirt/domain/remove: ## Removes any dangling libvirt domains
	virsh destroy k8s-master || true
	virsh undefine k8s-master || true
	virsh destroy k8s-worker-1 || true
	virsh undefine k8s-worker-1 || true
	virsh destroy k8s-worker-2 || true
	virsh undefine k8s-worker-2 || true

.PHONY: clean
clean: ## Clean local cached terreform elements
	rm -rf ./.terraform
	rm terraform.tfstate*

.PHONY: init
init: ## Initialize terraform
	$(terraform) init

.PHONY: plan
plan: ## Plan deployment
	$(terraform) plan

.PHONY: apply
apply: ## Apply deployment
	$(terraform) apply

.PHONY: destroy
destroy: ## Plan deployment
	$(terraform) destroy

## Access deployed nodes
.PHONY: ssh-master
ssh-master: ## connect to the master node
	IP=$(shell $(terraform) output master_ip); ssh -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-worker-1
ssh-worker-1: ## connect to the master node
	IP=$(shell $(terraform) output worker_2_ip); ssh -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-worker-2
ssh-worker-2: ## connect to the master node
	IP=$(shell $(terraform) output worker_2_ip); ssh -i $(KEY_NAME) ubuntu@$${IP}

## Other stuff
.PHONY: show
show: ## Show deployment information
	@echo "OS: $(OS)"
	@echo "ARCH: $(ARCH)"
	@echo "POOL_NAME: $(POOL_NAME)"
	@echo "POOL_PATH: $(POOL_PATH)"
	@echo "MASTER NODE IP: $(shell $(terraform) output master_ip)"