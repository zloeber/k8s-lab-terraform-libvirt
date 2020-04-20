SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT_PATH := $(abspath $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
BIN_PATH := $(ROOT_PATH)/.local/bin
KEY_PATH := $(ROOT_PATH)/.local/.ssh
KEY_NAME := $(KEY_PATH)/id_rsa

POOL_NAME ?= cka_lab_images
POOL_PATH ?= $(shell pwd)/$(POOL_NAME)

terraform := $(BIN_PATH)/terraform
gh := $(BIN_PATH)/gh
xpanes := $(BIN_PATH)/xpanes

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
	@grep -E '^[a-zA-Z1-9_%/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: libvirt/pool/create .dep/keygen .dep/xpanes libvirt/provider ## Install terraform dependencies
ifeq (,$(wildcard $(terraform)))
	@echo "Attempting to install terraform - $(TF_VERSION)"
	@mkdir -p $(BIN_PATH)
	@wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/$(TF_VERSION)/terraform_$(TF_VERSION)_$(OS)_$(ARCH).zip
	@unzip -d $(BIN_PATH) /tmp/terraform.zip && rm /tmp/terraform.zip
endif

.PHONY: libvirt/provider
libvirt/provider: ## Grab the libvirt terraform provider
ifeq "$(wildcard $(TF_PROVIDER_PATH))" ""
	@echo "Attempting to grab the libvirt provider"
	@mkdir -p $(ROOT_PATH)/terraform.d/plugins/$(OS)_$(ARCH)
	$(ROOT_PATH)/init.sh
endif

.PHONY: dep/keygen
.dep/keygen: ## Generate an ssh key for this deployment
ifeq (,$(wildcard $(KEY_NAME)))
	@mkdir -p $(KEY_PATH)
	ssh-keygen -t rsa -b 4096 -N '' -f $(KEY_NAME) -q
endif

.PHONY: .dep/xpanes
.dep/xpanes: ## xpanes for tmux
ifeq (,$(wildcard $(BIN_PATH)/xpanes))
	wget https://raw.githubusercontent.com/greymd/tmux-xpanes/v4.1.1/bin/xpanes -O $(BIN_PATH)/xpanes
	chmod +x $(BIN_PATH)/xpanes
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

.PHONY: ssh-master
ssh-master: ## connect to the master node
	IP=$(shell $(terraform) output master_ip); ssh -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-worker1
ssh-worker1: ## connect to worker node 1
	IP=$(shell $(terraform) output worker_1_ip); ssh -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-worker2
ssh-worker2: ## connect to worker node 2
	IP=$(shell $(terraform) output worker_2_ip); ssh -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-all
ssh-all: ## Use xpanes/tmux to connect to all nodes at once!
	$(xpanes) -c "ssh -i $(KEY_NAME) -o StrictHostKeyChecking=no {}" \
	  ubuntu@$(shell $(terraform) output master_ip) \
          ubuntu@$(shell $(terraform) output worker_1_ip) \
          ubuntu@$(shell $(terraform) output worker_2_ip)

.PHONY: show
show: ## Show deployment information
	@echo "OS: $(OS)"
	@echo "ARCH: $(ARCH)"
	@echo "POOL_NAME: $(POOL_NAME)"
	@echo "POOL_PATH: $(POOL_PATH)"
	@echo "TF_PROVIDER_PATH: $(TF_PROVIDER_PATH)"
	@echo "MASTER NODE IP: $(shell $(terraform) output master_ip)"
	@echo "WORKER 1 NODE IP: $(shell $(terraform) output worker_1_ip)"
	@echo "WORKER 2 NODE IP: $(shell $(terraform) output worker_2_ip)"
