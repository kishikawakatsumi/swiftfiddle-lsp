FROM swift:5.4-focal as build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get install -y --no-install-recommends rsync \
    && rm -r /var/lib/apt/lists/*

WORKDIR /build
COPY ./Package.* ./
RUN swift package resolve
COPY . .
RUN swift build -c release \
    && (cd ./Resources/ProjectTemplate && swift build -c debug) \
    && (cd Resources/formatter && swift build --product swift-format -c release)

WORKDIR /staging
RUN cp "$(swift build --package-path /build -c release --show-bin-path)/Run" ./ \
    && rsync -a --delete --include=".build" --exclude=".DS_Store" --exclude="repositories" \
    --exclude="ModuleCache" --exclude=".git" --exclude=".github" \
    --exclude="*.build" --exclude="*.product" --exclude="*.bundle" \
    /build/Resources/ ./Resources/

FROM swift:5.4-focal

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get install -y --no-install-recommends rsync \
    && rm -r /var/lib/apt/lists/*
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

WORKDIR /app
COPY --from=build --chown=vapor:vapor /staging /app

USER vapor:vapor
EXPOSE $PORT

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0"]
