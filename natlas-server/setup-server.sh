#!/bin/bash

export LC_ALL="C.UTF-8"
export LANG="C.UTF-8"

if [[ "$EUID" -ne 0 ]]; then
  echo "[!] This script needs elevated permissions to run."
  exit 2
fi

echo "[+] Updating apt repositories"
apt-get update

if [ ! id natlas >/dev/null 2>&1 ]; then
    echo "[+] Creating natlas user: useradd -M -N -r -s /bin/false -d /opt/natlas natlas"
    useradd -M -N -r -s /bin/false -d /opt/natlas natlas
    if [ ! id natlas >/dev/null 2>&1 ]; then
        echo "[!] Failed to create natlas user"
    else
        echo "[+] Successfully created natlas user"
    fi
else
    echo "[+] Found natlas user"
fi

ELASTIC=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9200/_nodes)
if [ $ELASTIC != "200" ]
then
    ELASTICMSG="[!] Elasticsearch not found on localhost:9200: Make sure you connect natlas to an elasticsearch instance."
    echo $ELASTICMSG
else
    echo "[+] Elasticsearch found: http://localhost:9200/_nodes"
fi

if ! which python3 >/dev/null; then
    echo "[+] Installing python3: apt-get -y install python3.6"
    apt-get -y install python3.6
    if ! which python3 >/dev/null; then
        echo "[!] Failed to install python3" && exit 1
    else
        echo "[+] Successfully installed python3: `which python3`"
    fi
else
    echo "[+] Found python3: `which python3`"
fi

if ! which pip3 >/dev/null; then
    echo "[+] Installing pip3: apt-get -y install python3-pip"
    apt-get -y install python3-pip
    if ! which pip3 >/dev/null; then
        echo "[!] Failed to install pip3" && exit 2
    else
        echo "[+] Successfully installed python3: `which pip3`"
    fi
else
    echo "[+] Found pip3: `which pip3`"
fi

if ! which virtualenv >/dev/null; then
    echo "[!] Installing virtualenv: pip3 install virtualenv"
    pip3 install virtualenv
    if ! which virtualenv >/dev/null; then
        echo "[!] Failed to install virtualenv" && exit 3
    else
        echo "[+] Successfully installed virtualenv: `which virtualenv`"
    fi
else
    echo "[+] Found virtualenv: `which virtualenv`"
fi

if [ ! -d venv ]; then
    echo "[+] Creating new python3 virtualenv named venv"
    virtualenv -p /usr/bin/python3 venv
    if [ ! -d venv ]; then
        echo "[!] Failed to create virtualenv named venv" && exit 4
    else
        echo "[+] Successfully created virtualenv named venv"
    fi
else
    echo "[+] Found virtualenv named venv"
fi

if [ ! -e venv/bin/activate ]; then
    echo "[!] No venv activate script found: venv/bin/activate" && exit 5
else
    echo "[+] Entering virtual environment"
    source venv/bin/activate
    echo "[+] Installing/updating natlas-server python dependencies"
    pip3 install -r requirements.txt --log pip.log -q
    echo "[+] Initializing/upgrading metadata database"
    echo "FLASK_APP=natlas-server.py" >> .env
    flask db upgrade
    echo "[+] Exiting virtual environment"
    deactivate
fi


echo "[+] Setup Complete"
echo "------------------"
if [ ! -z ${ELASTICMSG+x} ]; then
    echo $ELASTICMSG
fi
echo "[+] An example systemd script can be found in deployment/natlas-server.service"
echo "[+] An example nginx config can be found in deployment/nginx"
echo "[+] We highly recommend you use nginx to proxy connections to the flask application."