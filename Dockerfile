FROM registry.access.redhat.com/ubi9/ubi:latest AS base


ARG USER_ID=1001
ARG GROUP_ID=1001
ENV USER_NAME=default

ENV HOME="/app"
ENV PATH="/app/.local/bin:${PATH}"

ENV container=oci

USER root

# Check for package update
RUN dnf -y update-minimal --security --sec-severity=Important --sec-severity=Critical && \
    # Install git, nano, gcc, gcc++
    dnf install git nano gcc gcc-c++ -y; \
    # clear cache
    dnf clean all

WORKDIR ${HOME}

# Create user and set permissions
RUN groupadd -g ${GROUP_ID} ${USER_NAME} && \
    useradd -u ${USER_ID} -r -g ${USER_NAME} -d ${HOME} -s /sbin/nologin ${USER_NAME} && \
    chown -R ${USER_NAME}:${USER_NAME} ${HOME} && \
    chmod -R 0750 ${HOME}

# Install rustup and rust
ENV CARGO_HOME=${HOME}
ENV RUSTUP_HOME=${HOME}
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN . $CARGO_HOME/env && rustup default stable

#-----------------------------

# Dev target
FROM base AS dev
COPY .devcontainer/devtools.sh /tmp/devtools.sh
# Install extra dev tools as root, then run as default user
RUN  /tmp/devtools.sh 
USER ${USER_NAME}

# DEPLOYMENT EXAMPLE:
#-----------------------------

# Prod target
FROM base

## Move to app folder, copy project into container
WORKDIR ${HOME}
## REPLACE: replace this COPY statement with project specific files/folders
COPY . . 

#Check home
RUN chown -R default:default ${HOME} && \
    chmod -R 0750 ${HOME}

## Install project requirements, build project
RUN . $CARGO_HOME/env && cargo build --release



## Expose port and run app
EXPOSE 8080
USER ${USER_NAME}
CMD [ "/app/cargo", "run" ]