#!/bin/bash
# startup.sh — install ODBC Driver 18 for SQL Server then launch gunicorn.
# App Service Linux Python images don't ship with the Microsoft ODBC driver.
# This script runs as root inside the container, so apt-get works fine.
set -e

if [ ! -e /opt/microsoft/msodbcsql18 ]; then
    echo "[startup] Installing ODBC Driver 18 for SQL Server..."

    apt-get update -qq
    apt-get install -y -qq --no-install-recommends curl gnupg apt-transport-https

    curl -sSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg

    # Auto-detect Ubuntu vs Debian and pick the right repo
    . /etc/os-release
    if [ "$ID" = "ubuntu" ]; then
        REPO="https://packages.microsoft.com/ubuntu/${VERSION_ID}/prod"
        CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    else
        REPO="https://packages.microsoft.com/debian/${VERSION_ID}/prod"
        CODENAME="${VERSION_CODENAME}"
    fi

    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] \
${REPO} ${CODENAME} main" > /etc/apt/sources.list.d/mssql-release.list

    apt-get update -qq
    ACCEPT_EULA=Y apt-get install -y -qq msodbcsql18 unixodbc-dev
    pip install --quiet pyodbc

    echo "[startup] ODBC Driver 18 installed."
fi

exec gunicorn --bind=0.0.0.0:8000 --timeout=120 wsgi:app
