SHELL := /bin/bash
.DEFAULT_GOAL := help

ROOT_PATH := $(abspath $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
BIN_PATH := $(ROOT_PATH)/.local/bin
KUBECONFIG_PATH ?= $(ROOT_PATH)/.local/kubeconfig
TASK_PATH := $(ROOT_PATH)/tasks
KEY_PATH := $(ROOT_PATH)/.local/.ssh
KEY_NAME := $(KEY_PATH)/id_rsa

POOL_NAME ?= ubuntu
POOL_PATH ?= $(shell pwd)/volume_pool

terraform := $(BIN_PATH)/terraform
gh := $(BIN_PATH)/gh
xpanes := $(BIN_PATH)/xpanes
kubectl := $(BIN_PATH)/kubectl --kubeconfig $(KUBECONFIG_PATH)/config

ENV_VARS ?= $(ROOT_PATH)/envvars.env
ifneq (,$(wildcard $(ENV_VARS)))
include $(ENV_VARS)
export $(shell sed 's/=.*//' $(ENV_VARS))
endif

KUBE_VERSION ?= 1.17.5

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
	@grep --no-filename -E '^[a-zA-Z1-9_/-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: .dep/terraform .dep/keygen .dep/xpanes .dep/libvirt/provider ## Install Dependencies

.PHONY: .dep/terraform
.dep/terraform: ## Install local terraform binary
ifeq (,$(wildcard $(terraform)))
	@echo "Attempting to install terraform - $(TF_VERSION)"
	@mkdir -p $(BIN_PATH)
	@wget -O /tmp/terraform.zip https://releases.hashicorp.com/terraform/$(TF_VERSION)/terraform_$(TF_VERSION)_$(OS)_$(ARCH).zip
	@unzip -d $(BIN_PATH) /tmp/terraform.zip && rm /tmp/terraform.zip
endif

.PHONY: .dep/libvirt/provider
.dep/libvirt/provider: ## Grab the libvirt terraform provider
#ifeq "$(wildcard $(TF_PROVIDER_PATH))" ""
ifeq (,$(wildcard $(TF_PROVIDER_PATH)))
	@echo "Attempting to grab the libvirt provider"
	@mkdir -p $(ROOT_PATH)/terraform.d/plugins/$(OS)_$(ARCH)
	$(ROOT_PATH)/init.sh
endif

.PHONY: .dep/keygen
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

.PHONY: libvirt/domain/remove
libvirt/clean: ## Removes any dangling libvirt domains and subnets
	virsh destroy k8s-master || true
	virsh undefine k8s-master || true
	virsh destroy k8s-worker-1 || true
	virsh undefine k8s-worker-1 || true
	virsh destroy k8s-worker-2 || true
	virsh undefine k8s-worker-2 || true
	virsh net-destroy kube_ext || true
	virsh net-undefine kube_ext || true
	virsh net-destroy kube_node || true
	virsh net-undefine kube_node || true
	virsh pool-destroy ${POOL_NAME} || true
	virsh pool-undefine ${POOL_NAME} || true

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
	IP=$(shell $(terraform) output master_ip); ssh -o StrictHostKeyChecking=no -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-worker1
ssh-worker1: ## connect to worker node 1
	IP=$(shell $(terraform) output worker_1_ip); ssh -o StrictHostKeyChecking=no -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-worker2
ssh-worker2: ## connect to worker node 2
	IP=$(shell $(terraform) output worker_2_ip); ssh -o StrictHostKeyChecking=no -i $(KEY_NAME) ubuntu@$${IP}

.PHONY: ssh-all
ssh-all: ## Use xpanes/tmux to connect to all nodes at once (synced input)
	$(xpanes) -c "ssh -i $(KEY_NAME) -o StrictHostKeyChecking=no {}" \
	  ubuntu@$(shell $(terraform) output master_ip) \
	  ubuntu@$(shell $(terraform) output worker_1_ip) \
      ubuntu@$(shell $(terraform) output worker_2_ip)

.PHONY: ssh-all-desync
ssh-all-desync: ## Use xpanes/tmux to connect to all nodes at once
	$(xpanes) -d -c "ssh -i $(KEY_NAME) -o StrictHostKeyChecking=no {}" \
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

.PHONY: .kube/get/configfile
.kube/get/configfile: ## Pull deployed kube config file from master
ifeq (,$(wildcard $(KUBECONFIG_PATH)/config))
	@rm -rf $(KUBECONFIG_PATH)
	@mkdir -p $(KUBECONFIG_PATH)
	@IP=$(shell $(terraform) output master_ip); \
	  scp -o StrictHostKeyChecking=no -i $(KEY_NAME) ubuntu@$${IP}:.kube/config $(KUBECONFIG_PATH)/config
endif

.PHONY: .dep/kubectl
.dep/kubectl: ## install kubectl for this project
ifeq (,$(wildcard $(BIN_PATH)/kubectl))
	@mkdir -p $(BIN_PATH)
	@curl --retry 3 --retry-delay 5 --fail -sSL -o $(BIN_PATH)/kubectl https://storage.googleapis.com/kubernetes-release/release/v$(KUBE_VERSION)/bin/$(OS)/$(ARCH)/kubectl
	@chmod +x $(BIN_PATH)/kubectl
	@echo "Installed: $(BIN_PATH)/kubectl"
endif

.PHONY: kube/deploy/metallb
kube/deploy/metallb: .dep/kubectl .kube/get/configfile ## Deploy metallb on the cluster
	@$(kubectl) apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
	@$(kubectl) apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
	@$(kubectl) apply -f $(TASK_PATH)/metallb-config.yaml
	@$(kubectl) create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" || true

.PHONY: kube/deploy/metricsserver
kube/deploy/metricsserver: .dep/kubectl .kube/get/configfile## Deploy metrics server
	@$(kubectl) apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml

.PHONY: kube/delete/metallb
kube/delete/metallb: ## Delete metallb deployment
	@$(kubectl) delete -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
	@$(kubectl) delete -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml

.PHONY: kube/export/config
kube/export/config: ## Displays the correct export command to point kubeconfig to this cluster
	@echo 'export KUBECONFIG=$$(pwd)/.local/kubeconfig/config'

.PHONY: kube/clean
kube/clean: ## Remove old kube config and kubectl files
	@rm -rf $(BIN_PATH)/kubectl
	@rm -rf $(KUBECONFIG_PATH)/config