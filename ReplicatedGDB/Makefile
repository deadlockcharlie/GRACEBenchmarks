.PHONY: build deploy delete logs logs-instance port-forward port-forward-all status clean help \
        deploy-multi-dc verify-multi-dc test-cross-dc benchmark-multi-dc

# Variables
IMAGE_NAME := replicatedgdb
IMAGE_TAG := latest
K8S_NAMESPACE := default
PORT := 8080

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-25s %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

build-provider: ## Build the Y.js provider image
	docker build -f ./ProviderDockerfile -t yjs-provider:latest ./

build-all: build build-provider ## Build all images

build-minikube: ## Build the Docker image using minikube's Docker daemon
	eval $$(minikube docker-env) && docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

load-kind: build build-provider ## Build and load images into kind cluster
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG)
	kind load docker-image yjs-provider:latest

deploy: ## Deploy to Kubernetes
	kubectl apply -f k8s/

delete: ## Delete deployment from Kubernetes
	kubectl delete -f k8s/

redeploy: delete deploy ## Delete and redeploy

logs: ## Tail logs from the deployment
	kubectl logs -l app=$(IMAGE_NAME) -f --tail=100

status: ## Check deployment status
	@echo "=== StatefulSet ==="
	@kubectl get statefulset $(IMAGE_NAME)
	@echo "\n=== Pods ==="
	@kubectl get pods -l app=$(IMAGE_NAME)
	@echo "\n=== Services ==="
	@kubectl get svc | grep $(IMAGE_NAME)

describe: ## Describe the StatefulSet
	kubectl describe statefulset $(IMAGE_NAME)

shell: ## Exec into a pod (usage: make shell INSTANCE=0)
	@INSTANCE=$${INSTANCE:-0}; \
	kubectl exec -it $(IMAGE_NAME)-$$INSTANCE -- sh

port-forward: ## Port forward to access locally (usage: make port-forward INSTANCE=0 PORT=8080)
	@INSTANCE=$${INSTANCE:-0}; \
	kubectl port-forward $(IMAGE_NAME)-$$INSTANCE $(PORT):8080

logs-instance: ## Tail logs from specific instance (usage: make logs-instance INSTANCE=0)
	@INSTANCE=$${INSTANCE:-0}; \ (usage: make test-endpoint INSTANCE=0)
	@INSTANCE=$${INSTANCE:-0}; \
	PORT=$$((30000 + $$INSTANCE)); \
	echo "Testing instance $$INSTANCE on port $$PORT..."; \
	curl -s http://localhost:$$PORT/ready && echo "\n✓ Instance $$INSTANCE is ready" || echo "\n✗ Instance $$INSTANCE is not ready"

test-all: ## Test all instance endpoints
	@for i in 0 1 2; do \
		PORT=$$((30000 + $$i)); \
		echo "Testing instance $$i on port $$PORT..."; \
		curl -s http://localhost:$$PORT/ready && echo "✓ Instance $$i is ready" || echo "✗ Instance $$i is not ready"; \
	done

port-forward-all: ## Port forward all instances (requires scripts)
	@bash scripts/port-forward-all.sh

port-forward-labs: ## Port forward all app and Memgraph Lab instances  
	@chmod +x scripts/port-forward-memgraph-lab.sh
	@bash scripts/port-forward-memgraph-lab.sh

scale: ## Scale StatefulSet (usage: make scale REPLICAS=5)
	kubectl scale statefulset $(IMAGE_NAME) --replicas=$(REPLICAS)

restart: ## Restart StatefulSet
	kubectl rollout restart statefulse/ready && echo "\n✓ Service is ready" || echo "\n✗ Service is not ready"

scale: ## Scale deployment (usage: make scale REPLICAS=3)
	kubectl scale deployment $(IMAGE_NAME) --replicas=$(REPLICAS)

restart: ## Restart deployment
	kubectl rollout restart deployment $(IMAGE_NAME)

watch: ## Watch pod status
	kubectl get pods -l app=$(IMAGE_NAME) -w

# Multi-DC targets
deploy-multi-dc: build ## Deploy across 6 data centers
	@bash scripts/deploy-multi-dc.sh

verify-multi-dc: ## Verify multi-DC deployment
	@bash scripts/verify-multi-dc.sh

test-cross-dc: ## Test cross-DC synchronization
	@bash scripts/test-cross-dc.sh

benchmark-multi-dc: ## Benchmark all DCs
	@bash scripts/benchmark-multi-dc.sh

status-multi-dc: ## Check status of all DCs
	@echo "Multi-DC Status (6 Data Centers):"
	@for dc in dc1 dc2 dc3 dc4 dc5 dc6; do \
		echo "\n=== $$dc ==="; \
		kubectl get pods -n $$dc -l app=$(IMAGE_NAME) 2>/dev/null || echo "Not deployed"; \
	done

delete-multi-dc: ## Delete all multi-DC deployments
	@for dc in dc1 dc2 dc3 dc4 dc5 dc6; do \
		kubectl delete namespace $$dc --ignore-not-found=true; \
	done
	@kubectl delete namespace yjs --ignore-not-found=true
	@echo "All DCs deleted"

