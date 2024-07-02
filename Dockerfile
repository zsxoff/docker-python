# syntax=docker/dockerfile:1

ARG PYTHON_VERSION=3.11.9
ARG PYTHON_DISTRIB=slim-bookworm

FROM python:${PYTHON_VERSION}-${PYTHON_DISTRIB} AS base

# Install system packages
RUN set -eux; \
    # Uncomment lines below and replace mirrors if needed:
    # rm -rf /etc/apt/sources.list; \
    # rm -rf /etc/apt/sources.list.d; \
    # echo "deb <mirror> <distrib> main" > /etc/apt/sources.list; \
    # echo "deb <mirror> <distrib>-updates main contrib" >> /etc/apt/sources.list; \
    # echo "deb <mirror> <distrib>-backports main contrib" >> /etc/apt/sources.list; \
    # echo "deb <mirror> <distrib>-security main contrib" >> /etc/apt/sources.list; \
    DEBIAN_FRONTEND=noninteractive apt-get -y update; \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
    curl=7.* \
    tini=0.19.* \
    ; \
    DEBIAN_FRONTEND=noninteractive apt-get -y clean; rm -rf /var/lib/apt/lists/*

# Create non-root user
ARG \
    APP_LOGIN=nonroot \
    APP_GROUP=nonroot \
    APP_UID=10001 \
    APP_GID=10001

ENV \
    APP_LOGIN=${APP_LOGIN} \
    APP_GROUP=${APP_GROUP} \
    APP_UID=${APP_UID} \
    APP_GID=${APP_GID}

RUN set -eux; \
    groupadd --gid ${APP_GID} ${APP_GROUP} \
    ; \
    useradd \
    --no-log-init \
    --create-home \
    --home /home/${APP_LOGIN} \
    --base-dir /home/${APP_LOGIN} \
    --uid ${APP_UID} \
    --gid ${APP_GID} \
    --comment "" \
    --shell /bin/bash \
    ${APP_LOGIN}

# Set timezone
ARG \
    TZ=UTC

ENV \
    TZ=${TZ}

RUN set -eux; \
    cp --remove-destination /usr/share/zoneinfo/${TZ} /etc/localtime ; echo ${TZ} > /etc/timezone

# Set locale
ARG \
    LANG=C.UTF-8\
    LC_ALL=C.UTF-8

ENV \
    LANG=${LANG}\
    LC_ALL=${LC_ALL}

# Set terminal
ARG \
    TERM=xterm

ENV \
    TERM=${TERM}

# Set Python options
ARG \
    # Keeps Python from generating .pyc files in the container
    PYTHONDONTWRITEBYTECODE=1 \
    # Dump the Python traceback
    PYTHONFAULTHANDLER=1 \
    # Allows you to set a fixed value for the hash seed secret
    PYTHONHASHSEED=random \
    # Turns off buffering for easier container logging
    PYTHONUNBUFFERED=1

ENV \
    PYTHONDONTWRITEBYTECODE=${PYTHONDONTWRITEBYTECODE} \
    PYTHONFAULTHANDLER=${PYTHONFAULTHANDLER} \
    PYTHONHASHSEED=${PYTHONHASHSEED} \
    PYTHONUNBUFFERED=${PYTHONUNBUFFERED}

# Set pip options
ARG \
    # Network connection timeout
    PIP_DEFAULT_TIMEOUT=120 \
    # Don't periodically check PyPI to determine whether a new version of pip is available for download
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    # Disable the cache
    PIP_NO_CACHE_DIR=1 \
    # Action if pip is run as a root user ('warn' or 'ignore')
    PIP_ROOT_USER_ACTION=ignore

ENV \
    PIP_DEFAULT_TIMEOUT=${PIP_DEFAULT_TIMEOUT} \
    PIP_DISABLE_PIP_VERSION_CHECK=${PIP_DISABLE_PIP_VERSION_CHECK} \
    PIP_NO_CACHE_DIR=${PIP_NO_CACHE_DIR} \
    PIP_ROOT_USER_ACTION=${PIP_ROOT_USER_ACTION}

# Set entrypoint
ENTRYPOINT ["tini", "--"]

FROM base AS app

# Install requirements as root user
RUN \
    --mount=type=bind,source=requirements.txt,target=requirements.txt,readonly \
    pip install --no-cache-dir --upgrade -r requirements.txt

# Copy application
WORKDIR /app
RUN chown -R nonroot:nonroot /app

USER nonroot
COPY --chown=nonroot:nonroot ./src ./src

CMD ["python", "-m", "src.main"]
