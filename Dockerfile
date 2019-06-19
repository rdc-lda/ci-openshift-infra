FROM alpine:3.9

RUN apk update
RUN apk -Uuv add bash ca-certificates openssl git openssh && \
    rm /var/cache/apk/*

# Install aws-cli
RUN apk -Uuv add groff less python py-pip && \
    pip install awscli && \
    apk --purge -v del py-pip && \
    rm /var/cache/apk/*

# Install JQ
RUN apk -Uuv add jq && \
    rm /var/cache/apk/*

# Add the libs
ADD src/func.bash /usr/share/misc/func.bash
ADD src/aws-func.bash /usr/share/misc/aws-func.bash

# Add the main scripts
ADD src/init-infra.bash /usr/bin/init-infra
ADD src/sempl.bash /usr/bin/sempl
RUN chmod a+x /usr/bin/init-infra /usr/bin/sempl

# AWS Cloud resources
ADD src/aws-create.bash /usr/bin/aws-create
ADD src/aws-create-openshift.bash /usr/bin/aws-create-openshift
# ADD src/aws-create-middleware.bash /usr/bin/aws-create-middleware
# ADD src/aws-create-backends.bash /usr/bin/aws-create-backends
RUN chmod a+x /usr/bin/aws-*
ADD templates/openshift-cloudformation.yml.sempl /usr/share/misc/openshift-cloudformation.yml.sempl

# Google Cloud resources
# ADD src/gce-create.bash /usr/bin/gce-create
# ADD src/gce-create-openshift.bash /usr/bin/gce-create-openshift
# ADD src/gce-create-middleware.bash /usr/bin/gce-create-middleware
# ADD src/gce-create-backends.bash /usr/bin/gce-create-backends
# RUN chmod a+x /usr/bin/gce-*

# Azure Cloud resources
# ADD src/azure-create.bash /usr/bin/azure-create
# ADD src/azure-create-openshift.bash /usr/bin/azure-create-openshift
# ADD src/azure-create-middleware.bash /usr/bin/azure-create-middleware
# ADD src/azure-create-backends.bash /usr/bin/azure-create-backends
# RUN chmod a+x /usr/bin/azure-*