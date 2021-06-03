#!/bin/bash
###
# install.sh
# Author: Valmor Secco
# Company: Three Pixels Sistemas
# Description: Basic shellscript to install docker and docker-compose.
###
MYSELF=$(realpath "$0")

PKG_PATH=/home/.tpx
PKG_LOGS=$PKG_PATH/logs
PKG_JSON=$PKG_PATH/tpx-package.json

LOGFILE=$PKG_LOGS/tpx-pkg-docker.log

COUNT_EXEC=$(cat $MYSELF | grep -c "tryExec")
COUNT_EXEC=$(($COUNT_EXEC - 3))
COUNT_EXEC_FAIL=0
COUNT_EXEC_OK=0
COUNT_EXEC_ALL=0
COUNT_EXEC_PRC=0

YES="-y"
SILENT=1

if [ $COUNT_EXEC -lt 0 ]; then
  COUNT_EXEC=0
fi

for var in "$@"
do
  if [ $var == "--verbose" ]; then
    SILENT=0
    YES=""
  fi
done

###
# function tryCoun
###
tryCount() {
  COUNT_EXEC_ALL=$(($COUNT_EXEC_ALL + 1))
  COUNT_EXEC_PRC=$(awk "BEGIN {print ($COUNT_EXEC_ALL/$COUNT_EXEC * 100)}")
  COUNT_EXEC_PRC_INT=$(echo "$COUNT_EXEC_PRC/1" | bc)
  echo -ne "<percent>$COUNT_EXEC_PRC_INT%</percent> \r"
  echo -ne "<percent>$COUNT_EXEC_PRC_INT%</percent> \r" >> $LOGFILE
}

###
# function tryEcho
###
tryEcho() {
  local DESCRIPTION="${1}"
  local MAIN="${2:-0}"
  local RESULT="${3}"
  if [ $MAIN -eq 0 ]; then
    if [ $RESULT == "..." ]; then
      echo -ne "=> $DESCRIPTION $RESULT \r"
      echo -ne "=> $DESCRIPTION $RESULT \r" >> $LOGFILE
    else
      echo "=> $DESCRIPTION $RESULT"
      echo "=> $DESCRIPTION $RESULT" >> $LOGFILE
    fi    
  else
    if [ $RESULT == "..." ]; then
      echo "$DESCRIPTION"
      echo "$DESCRIPTION" >> $LOGFILE
    else 
      printf "\n\n"
      printf "\n\n" >> $LOGFILE
    fi
  fi
}

###
# function tryExec
# Parameters:
# $1 => Command to execute
# $2 => Description for command
# $3 => Main execute {0 | 1}
###
tryExec() {
  local COMMAND="execVerbose"
  local DESCRIPTION="${2}"
  local MAIN="${3:-0}"

  if [ $MAIN -eq 0 ] && [ $SILENT -eq 1 ]; then
    COMMAND="execSilent"
  fi

  tryEcho "$DESCRIPTION" "$MAIN" "..."
  $COMMAND "$1"

  if [ $? -eq 0 ]; then
    tryCount
    tryEcho "$DESCRIPTION" "$MAIN" "(OK)"
  else
    tryCount
    tryEcho "$DESCRIPTION" "$MAIN" "(FAIL)"
  fi
}

###
# function tryFxec
# Parameters:
# $1 => Command to execute
# $2 => Description for command
# $3 => Main execute {0 | 1}
###
tryFxec() {
  local COMMAND="execVerbose"
  local DESCRIPTION="${2}"
  local MAIN="${3:-0}"
  local RESPONSE=0

  if [ $MAIN -eq 0 ] && [ $SILENT -eq 1 ]; then
    COMMAND="execSilent"
  fi

  tryEcho "$DESCRIPTION" "$MAIN" "..."
  $COMMAND "$1"

  if [ $? -eq 0 ]; then
    tryCount
    tryEcho "$DESCRIPTION" "$MAIN" "(OK)"
  else
    tryCount
    tryEcho "$DESCRIPTION" "$MAIN" "(FAIL)"
  fi
}

###
# function execSilent
# Parameters:
# $1 => Command to execute
###
execSilent() {
  $1 &> /dev/null
  if [ $? -ne 0 ]; then
    exit 0
  fi
}

###
# function execVerbose
# Parameters:
# $1 => Command to execute
###
execVerbose() {
  $1
  if [ $? -ne 0 ]; then
    exit 0
  fi
}

###
# function dockerInstall
###
dockerInstall() {
  local DOCKER_REPO="https://download.docker.com/linux/centos/docker-ce.repo"

  # Try remove docker
  tryExec "yum remove -q $YES docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine" "Try remove docker"

  # Try install yum-utils
  tryExec "yum install -q $YES yum-utils" "Try install yum-utils"

  # Try add repository
  tryExec "yum-config-manager --add-repo $DOCKER_REPO" "Try add repository"

  # Try install docker-ce, docker-ce-cli, containerd.io
  tryExec "yum install -q $YES docker-ce docker-ce-cli containerd.io" "Try install docker-ce, docker-ce-cli, containerd.io"
}

###
# function dockerComposeInstall
###
dockerComposeInstall() {
  local DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)"
  local DOCKER_COMPOSE_BIN=/usr/local/bin/docker-compose

  # Try download docker-compose
  if [ ! -f "$DOCKER_COMPOSE_BIN" ]; then
    tryExec "curl -L $DOCKER_COMPOSE_URL -o $DOCKER_COMPOSE_BIN" "Try download docker-compose"
  else
    tryFxec "echo 1" "Try download docker-compose"
  fi

  # Try permissions docker-compose
  tryExec "chmod +x $DOCKER_COMPOSE_BIN" "Try permissions docker-compose"
}

###
# function dockerStart
###
dockerStart() {
  # Try start docker
  tryExec "systemctl start docker" "Try start docker"

  # Try enable docker
  tryExec "systemctl enable docker" "Try enable docker"
}

###
# function tpxPkg
###
tpxPkg() {
  local DOCKER_VERSION=$(docker -v)
  local DOCKER_COMPOSE_VERSION=$(docker-compose -v)
  local installedDocker='.installed."docker" = "'$DOCKER_VERSION'"'
  local installedDockerCompose='.installed."docker-compose" = "'$DOCKER_COMPOSE_VERSION'"'

  # Add docker to tpx-package.json
  tryExec "echo 1" "Add docker to tpx-package.json"
  jq -c "$installedDocker" $PKG_JSON > ./tmp.$$.json && mv -f tmp.$$.json $PKG_JSON

  # Add docker-compose to tpx-package.json
  tryExec "echo 1" "Add docker-compose to tpx-package.json"
  jq -c "$installedDockerCompose" $PKG_JSON > ./tmp.$$.json && mv -f tmp.$$.json $PKG_JSON
}

###
# function tpxPkgLog
###
tpxPkgLog() {
  local UUID=$(dmidecode -s system-uuid)
  local DOCKER_VERSION=$(docker -v)
  local DOCKER_COMPOSE_VERSION=$(docker-compose -v)
  local installedDocker='.installed."docker" = "'$DOCKER_VERSION'"'
  local installedDockerCompose='.installed."docker-compose" = "'$DOCKER_COMPOSE_VERSION'"'

  # Create .tpx directory
  if [ ! -d "$PKG_PATH" ]; then
    tryExec "mkdir -p $PKG_PATH" "Create .tpx directory"
  else
    tryFxec "echo 1" "Create .tpx directory"
  fi

  # Create tpx-package.json
  if [ ! -f "$PKG_JSON" ]; then
    echo '{ "uuid": "'$UUID'", "installed": {} }' > $PKG_JSON
  fi

  # Create .tpx log directory
  if [ ! -d "$PKG_LOGS" ]; then
    tryExec "mkdir -p $PKG_LOGS" "Create .tpx log directory"
  else
    tryFxec "echo 1" "Create .tpx log directory"
  fi
}

###
# function tpxPkgLog
###
tpxPkgLogHeader() {
  local DATE_NOW=$(date +'%d/%m/%Y %H:%M:%S')
  tryExec "echo 1" "$DATE_NOW"
}

###
# install
###
tryExec "tpxPkgLogHeader" "################################### --------  -------- ###################################" 1
tryExec "tpxPkgLog" "### 1 -> Fix to create log ###" 1
tryExec "dockerInstall" "### 2 -> Docker install ###" 1
tryExec "dockerComposeInstall" "### 3 -> Docker compose intall ###" 1
tryExec "dockerStart" "### 4 -> Docker start ###" 1
tryExec "tpxPkg" "### 5 -> Fix to tpx-package.json ###" 1
exit 0