FROM golang:1.23-alpine AS build

ENV \
  STRONGBOX_VERSION=2.0.0-RC4 \
  KUSTOMIZE_VERSION=v5.4.1

ENV HELM_VERSION=v3.16.2

RUN os=$(go env GOOS) && arch=$(go env GOARCH) \
      && apk --no-cache add curl \
      && curl -Ls https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_${os}_${arch}.tar.gz \
           | tar xz -C /usr/local/bin/ \
      && chmod +x /usr/local/bin/kustomize \
      && curl -Ls https://github.com/uw-labs/strongbox/releases/download/v${STRONGBOX_VERSION}/strongbox_${STRONGBOX_VERSION}_${os}_${arch} \
           > /usr/local/bin/strongbox \
      && chmod +x /usr/local/bin/strongbox \
      && curl -O https://get.helm.sh/helm-${HELM_VERSION}-${os}-${arch}.tar.gz \
      && tar -xf helm-${HELM_VERSION}-${os}-${arch}.tar.gz \
      && cp ${os}-${arch}/helm /usr/local/bin/helm \
      && chmod +x /usr/local/bin/helm

ADD . /app
WORKDIR /app

RUN go test -v -cover ./... \
      && go build -ldflags='-s -w' -o /argocd-voodoobox-plugin .

# final stage
# argocd requires that sidecar container is running as user 999
FROM alpine:3.20

USER root

ENV ARGOCD_USER_ID=999

RUN adduser -S -H -u $ARGOCD_USER_ID argocd \
      && apk --no-cache add git openssh-client git-lfs

COPY --from=build \
  /usr/local/bin/kustomize \
  /usr/local/bin/strongbox \
  /usr/local/bin/helm \
  /argocd-voodoobox-plugin \
  /usr/local/bin/

ENV USER=argocd
USER $ARGOCD_USER_ID
