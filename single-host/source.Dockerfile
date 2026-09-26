# syntax=docker/dockerfile:1

# The api, controller and runner images, built from the agentiik source at AGENTIIK_VERSION rather
# than pulled: compose.build.yaml uses it. The last three stages are the release's own,
# build/api.Dockerfile, build/controller.Dockerfile and build/runner.Dockerfile, which package static
# binaries the release builds beforehand; the first stage builds those binaries here instead, as
# each program's static_test.go builds them.

# The source, with its .git, so that go build records the tag as the version: agk-runner join sends
# it to the API, and each program's --version prints it.
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS build
ARG AGENTIIK_VERSION
ARG TARGETARCH
RUN apk add --no-cache git
ADD --keep-git-dir=true https://github.com/agentiik/agentiik.git#${AGENTIIK_VERSION} /src
WORKDIR /src
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    for cmd in agentiik-api agentiik-controller agk-runner agk-helper; do \
      CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -trimpath -ldflags='-s -w' -o /out/$cmd ./cmd/$cmd || exit 1; \
    done

# The certificates the programs verify the bus and the database with, and the directories the API
# and the controller write in, owned by the user they run as.
FROM alpine:3.21 AS certificates
RUN mkdir -p /var/lib/agentiik/objects && mkdir -m 700 /var/lib/agentiik/bus

FROM scratch AS api
COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/agentiik-api /agentiik-api
COPY --from=certificates --chown=65532:65532 /var/lib/agentiik /var/lib/agentiik
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/agentiik-api"]
CMD ["serve"]

FROM scratch AS controller
COPY --from=certificates /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /out/agentiik-controller /agentiik-controller
COPY --from=certificates --chown=65532:65532 /var/lib/agentiik/objects /var/lib/agentiik/objects
USER 65532:65532
ENTRYPOINT ["/agentiik-controller"]

# The agent holds CAP_CHOWN, CAP_FOWNER and CAP_DAC_OVERRIDE as file capabilities, and the image
# names its account agentiik at 65532, which join gives runner.env and the key to.
FROM --platform=$BUILDPLATFORM alpine:3.21 AS prepare
RUN apk add --no-cache libcap-setcap
COPY --from=build /out/agk-runner /out/usr/local/bin/agk-runner
RUN setcap cap_chown,cap_fowner,cap_dac_override=ep /out/usr/local/bin/agk-runner
RUN mkdir -p /out/etc && mkdir -m 1777 /out/tmp && \
    printf 'root:x:0:0:root:/:/sbin/nologin\nagentiik:x:65532:65532:Agentiik runner:/var/lib/agentiik:/sbin/nologin\n' > /out/etc/passwd && \
    printf 'root:x:0:\nagentiik:x:65532:\n' > /out/etc/group

FROM scratch AS runner
COPY --from=prepare /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=prepare /out/ /
COPY --from=build /out/agk-helper /usr/local/lib/agentiik/agk-helper
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/agk-runner"]
CMD ["serve"]
