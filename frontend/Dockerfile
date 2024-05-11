# syntax=docker/dockerfile:1.3
#--------------------------------------------
# Dev Stage - Assembles and Builds Frontend
#--------------------------------------------
FROM --platform=$BUILDPLATFORM node:18-alpine as dev

ARG APP_SHELL_VERSION=next
ARG ENVIRONMENT=dev

RUN mkdir -p /app
WORKDIR /app

COPY /frontend/${ENVIRONMENT:-dev}/spa-assemble-config.json .
COPY /frontend/${ENVIRONMENT:-dev}/spa-build-config.json .

ARG CACHE_BUST
RUN npx --legacy-peer-deps openmrs@${APP_SHELL_VERSION:-next} assemble --manifest --mode config --config spa-assemble-config.json --target ./spa
RUN npx --legacy-peer-deps openmrs@${APP_SHELL_VERSION:-next} build --build-config spa-build-config.json --target ./spa
RUN if [ ! -f ./spa/index.html ]; then echo 'Build failed. Please check the logs above for details. This may have happened because of an update to a library that OpenMRS depends on.'; exit 1; fi

COPY /frontend/${ENVIRONMENT:-dev}/custom-config.json ./spa/custom-config.json
COPY /frontend/${ENVIRONMENT:-dev}/assets/logo.png ./spa/logo.png
COPY /frontend/${ENVIRONMENT:-dev}/assets/header-logo.png ./spa/header-logo.png
COPY /frontend/${ENVIRONMENT:-dev}/assets/favicon.ico ./spa/favicon.ico
COPY /frontend/${ENVIRONMENT:-dev}/assets/favicon-32x32.webp ./spa/favicon-32x32.webp

#--------------------------------------------
# Runtime Stage - Published Image
#--------------------------------------------
FROM nginx:1.25-alpine

RUN apk update && \
    apk upgrade && \
    # add more utils for sponge and envsubst
    apk add --no-cache moreutils

# clear any default files installed by nginx
RUN rm -rf /usr/share/nginx/html/*

COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

COPY nginx.conf /etc/nginx/nginx.conf

COPY --from=dev /app/spa /usr/share/nginx/html
COPY config-core_demo.json /usr/share/nginx/html

CMD ["/usr/local/bin/startup.sh"]
