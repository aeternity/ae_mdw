GIT_DESCR = $(shell git describe --always)
# build output folder
OUTPUTFOLDER = dist
# docker image
DOCKER_REGISTRY = 166568770115.dkr.ecr.eu-central-1.amazonaws.com/aeternity
DOCKER_IMAGE = aeternal-frontend
DOCKER_TAG = $(shell git describe --always)
K8S_NAMESPACE=mainnet
NODE_URL=https://testnet.aeternal.io
NODE_WS=wss://testnet.aeternal.io/websocket
NETWORK_NAME=TEST NET
ENABLE_FAUCET=true

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs

clean:
	@echo remove $(OUTPUTFOLDER) folder
	@rm -rf dist
	@echo done

build:
	@echo build release
	npm install && npm run build
	@echo done

docker-build:
	@echo build image
	docker build -t $(DOCKER_IMAGE) --build-arg ENABLE_FAUCET=$(ENABLE_FAUCET) --build-arg NODE_URL=$(NODE_URL) --build-arg NODE_WS=$(NODE_WS) --build-arg NETWORK_NAME='$(NETWORK_NAME)' -f Dockerfile .
	@echo done

docker-push:
	@echo push image
	docker tag $(DOCKER_IMAGE) $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(K8S_NAMESPACE)-$(DOCKER_TAG)
	aws ecr get-login --no-include-email --region eu-central-1 --profile aeternity-sdk | sh
	docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(K8S_NAMESPACE)-$(DOCKER_TAG)
	@echo done

deploy-k8s:
	@echo deploy k8s
	kubectl -n $(K8S_NAMESPACE) patch deployment $(DOCKER_IMAGE) --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"$(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(K8S_NAMESPACE)-$(DOCKER_TAG)"}]'
	@echo deploy k8s done
