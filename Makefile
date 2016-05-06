NAME := $(shell jq -r .docker_name package.json)
TAG := $(shell jq -r .version package.json)

image:
	docker build -t ${NAME}:${TAG} .
	docker tag -f ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}


image-no-cache:
	docker build --rm=true --no-cache -t ${NAME}:${TAG} .

tests:
	npm test

push: image tests
	docker push ${REGISTRY}/${NAME}:${TAG}
	docker push ${NAME}:${TAG}
	docker rmi ${REGISTRY}/${NAME}:${TAG}
	docker rmi ${NAME}:${TAG}
