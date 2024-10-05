#!/usr/bin/env bash
# Copyright Vespa.ai. All rights reserved.

set -euo pipefail

usage() {
  echo "Usage: run-tests-on-swarm.sh [OPTIONS]"
  echo
  echo "Run all or a subset of system tests on Docker swarm"
  echo
  echo "Required options:"
  echo "-i, --image          Docker image to use. When using multiple swarm nodes, the image must"
  echo "                     be available from a central repository."
  echo "-n, --nodes          Number of service nodes"
  echo
  echo "Optional options:"
  echo "-c, --configserver   Setup shared configserver available to tests that can use shared configservers."
  echo "-e, --env            Environment variable to pass to Docker in the form VAR=value. Can be repeated."
  echo "-f, --file           Testfile to execute. Relative to tests/ directory. Can be repeated."
  echo "                     If not specified, all test files in tests/ will be discovered."
  echo "-k, --keeprunning    Keep the test containers running. Only use this option when executing"
  echo "                     specific tests. Otherwise all test nodes will be used and tests will hang waiting."
  echo "-m, --mount          Bind mount to include in both node and testrunner containers."
  echo "                     This will not work correctly if multiple swarm nodes are used. "
  echo "                     Format is <local file/folder>:<container destination>"
  echo "-M, --testrunner-mount     Bind mount as with -m, but just for the testrunner container."
  echo "-p, --performance    Run performance tests."
  echo "-o, --consoleoutput  Output test execution on console/stdout."
  echo "-r, --resultdir      Directory to store results. Will auto allocate in \$HOME/tmp/systemtest.XXXXXX"
  echo "--service-constraint       Constraint on where a service node is scheduled"
  echo "--service-reserve-memory   Reserve memory for each service node"
  echo "--service-ramdisk          Use tmpfs in each service node"
  echo "--stop               Stop docker swarm service from earlier testrun and exit."
  echo "-t, --testrunid      Identifier for this testrun. Will be autogenerated if not specified."
  echo "-v, --verbose        Print debug output"
  echo "-w, --nodewait       Seconds to wait for required set of nodes to be available."
  exit 1
}

if [[ $# == 0 ]]; then usage;fi
if [[ $(echo $BASH_VERSION|cut -d. -f1) < 4 ]]; then
  echo "ERROR: Requires bash 4 or better."; echo; usage
fi

if ! docker service ls &> /dev/null; then
  echo "ERROR: Requires Docker swarm to be running."; echo; usage
fi

readonly BASEDIR=/tmp/testresults
readonly NETWORK="$USER-vespa"
readonly TESTRUNNER="$USER-testrunner"
readonly SERVICE="$USER-vespanode"

# Option parsing
POSITIONAL=()
CONFIGSERVER=""
CONSOLEOUTPUT=false
DNS_SETTLE_TIME=""
DOCKERIMAGE=""
ENVS=()
KEEPRUNNING=false
MOUNTS=()
TESTRUNNER_MOUNTS=()
NODEWAIT=""
NUMNODES=""
PERFORMANCE=false
RESULTDIR=""
STOP_SERVICE=false
TESTFILES=()
TESTRUNID=""
VERBOSE=false
SERVICE_EXTRA_ARGS=()
SERVICE_RAMDISK=false
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    --help)
    usage
    shift
    ;;
    -c|--configserver)
    CONFIGSERVER="$USER-configserver"
    shift
    ;;
    -d|--dns-settle-time)
    DNS_SETTLE_TIME="$2"
    shift; shift
    ;;
    -e|--env)
    ENVS+=("$2")
    shift; shift
    ;;
    -f|--file)
    TESTFILES+=("$2")
    shift; shift
    ;;
    -i|--image)
    DOCKERIMAGE="$2"
    shift; shift
    ;;
    -m|--mount)
    MOUNTS+=("$2")
    shift; shift
    ;;
    -M|--testrunner-mount)
    TESTRUNNER_MOUNTS+=("$2")
    shift; shift
    ;;
    -k|--keeprunning)
    KEEPRUNNING=true
    shift
    ;;
    -n|--nodes)
    NUMNODES="$2"
    shift; shift
    ;;
    -o|--consoleoutput)
    CONSOLEOUTPUT=true
    shift
    ;;
    -p|--performance)
    PERFORMANCE=true
    shift
    ;;
    -r|--resultdir)
    RESULTDIR="$2"
    shift; shift
    ;;
    --service-constraint)
    SERVICE_EXTRA_ARGS+=("--constraint" "$2")
    shift; shift
    ;;
    --service-ramdisk)
    SERVICE_RAMDISK=true
    shift
    ;;
    --service-reserve-memory)
    SERVICE_EXTRA_ARGS+=("--reserve-memory" "$2")
    shift; shift
    ;;
    --stop)
    STOP_SERVICE=true
    shift
    ;;
    -t|--testrunid)
    TESTRUNID="$2"
    shift; shift
    ;;
    -v|--verbose)
    VERBOSE=true
    shift
    ;;
    -w|--nodewait)
    NODEWAIT="$2"
    shift; shift
    ;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done

log() {
  echo "[$(date -u +'%Y-%m-%d %H:%M:%S %z')] $*"
}

log_debug() {
  if [[ $VERBOSE != 0 ]]; then
    log "DEBUG" $1
  fi
}

# Remove service and network
docker_cleanup() {
  docker rm -f $TESTRUNNER &> /dev/null || true
  docker rm -f $CONFIGSERVER &> /dev/null || true

  if docker service ps $SERVICE &> /dev/null; then
    if ! docker service rm $SERVICE &> /dev/null; then
      log_debug "Could not remove service $SERVICE"
    else
      while [[ -n $(docker ps | grep "$SERVICE\.[0-9].*") ]]; do
        log_debug "Waiting for service $SERVICE to shut down."
        sleep 2
      done
      log_debug "Removed service $SERVICE."
    fi
  fi

  if docker network inspect $NETWORK &> /dev/null; then
    retries=5
    while test $retries -gt 0; do
      if docker network rm $NETWORK &> /dev/null; then
        break
      fi
      retries=$(($retries - 1))
      log_debug "Could not remove network $NETWORK ($retries retries left)"
      sleep 2
    done
    if test $retries -gt 0; then
      while [[ -n $(docker network ls | grep "$NETWORK.*swarm") ]]; do
        log_debug "Waiting for network $NETWORK to be removed."
        sleep 2
      done
      log_debug "Removed network $NETWORK."
    fi
  fi
}

if $STOP_SERVICE; then
    CONFIGSERVER="$USER-configserver"
    VERBOSE=true
    docker_cleanup
    echo Tests stopped
    exit 0
fi

if [[ ${#POSITIONAL[@]} > 0 ]]; then
  set -- "${POSITIONAL[@]}"
fi

if [[ -z $DOCKERIMAGE   ]]; then usage; fi
if [[ -z $NUMNODES   ]]; then usage; fi
if [[ -z $RESULTDIR ]]; then 
  mkdir -p $HOME/tmp
  RESULTDIR=$(mktemp -d $HOME/tmp/systemtest.XXXXXX)
fi
TESTRUNNER_OPTS="-n $NUMNODES"
if [[ ${#TESTFILES[@]} > 0 ]]; then
  for F in "${TESTFILES[@]}"; do
    TESTRUNNER_OPTS="$TESTRUNNER_OPTS -f $F"
  done
fi
if [[ -n $CONFIGSERVER ]]; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -c $CONFIGSERVER.$NETWORK"
fi
if $CONSOLEOUTPUT; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -o"
fi
if [[ -n $DNS_SETTLE_TIME ]]; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -d $DNS_SETTLE_TIME"
fi
if $KEEPRUNNING; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -k"
fi
if [[ -n $NODEWAIT ]]; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -w $NODEWAIT"
fi
if $PERFORMANCE; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -p"
fi
if [[ -n $TESTRUNID ]]; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -i $TESTRUNID"
fi
if $VERBOSE; then
  TESTRUNNER_OPTS="$TESTRUNNER_OPTS -v"
fi
BINDMOUNT_OPTS=""
if [[ ${#MOUNTS[@]} > 0 ]]; then
    for M in "${MOUNTS[@]}"; do
        BINDMOUNT_OPTS="$BINDMOUNT_OPTS --mount type=bind,src=${M%:*},dst=${M#*:}"
    done
fi
TESTRUNNER_BINDMOUNT_OPTS=""
if [[ ${#TESTRUNNER_MOUNTS[@]} > 0 ]]; then
    for M in "${TESTRUNNER_MOUNTS[@]}"; do
        TESTRUNNER_BINDMOUNT_OPTS="$TESTRUNNER_BINDMOUNT_OPTS --mount type=bind,src=${M%:*},dst=${M#*:}"
    done
fi
ENV_OPTS=""
if [[ ${#ENVS[@]} > 0 ]]; then
  for E in "${ENVS[@]}"; do
    ENV_OPTS="$ENV_OPTS --env $E"
  done
fi

VESPAVERSION=$(docker run --rm $BINDMOUNT_OPTS --entrypoint bash $DOCKERIMAGE -lc '${VESPA_HOME-/opt/vespa}/bin/vespa-print-default version')
case "$VESPAVERSION" in
    7.*.0) VESPAVERSION=7-SNAPSHOT
	   ;;
    8.*.0) VESPAVERSION=8-SNAPSHOT
	   ;;
    *)
	   ;;
esac
if $SERVICE_RAMDISK; then
    DOCKERIMAGE_VESPA_HOME=$(docker run --rm $BINDMOUNT_OPTS --entrypoint bash $DOCKERIMAGE -lc 'echo ${VESPA_HOME-/opt/vespa}')
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/logs/systemtests,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/logs/vespa,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/var/tmp/vespa,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/var/tmp/systemtests,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/var/db/vespa,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/var/jdisc_container,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/var/vespa,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=$DOCKERIMAGE_VESPA_HOME/var/zookeeper,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=/tmp,tmpfs-mode=1777")
    SERVICE_EXTRA_ARGS+=("--mount" "type=tmpfs,destination=/var/tmp,tmpfs-mode=1777")
fi

TESTRUNNER_OPTS="$TESTRUNNER_OPTS -b $BASEDIR -V $VESPAVERSION"

log_info() {
  log "INFO" $1
}
log_error() {
  log "ERROR" $1
}

log_debug ""
log_debug "Options:"
log_debug "--  DOCKERIMAGE:                $DOCKERIMAGE"
log_debug "--  NETWORK:                    $NETWORK"
log_debug "--  CONFIGSERVER:               $CONFIGSERVER"
log_debug "--  SERVICE:                    $SERVICE"
log_debug "--  NUMNODES:                   $NUMNODES"
log_debug "--  KEEPRUNNING:                $KEEPRUNNING"
log_debug "--  PERFORMANCE:                $PERFORMANCE"
log_debug "--  RESULTDIR:                  $RESULTDIR"
log_debug "--  BINDMOUNT_OPTS:             $BINDMOUNT_OPTS"
log_debug "--  TESTRUNNER_OPTS:            $TESTRUNNER_OPTS"
log_debug "--  TESTRUNNER_BINDMOUNT_OPTS:  $TESTRUNNER_BINDMOUNT_OPTS"
log_debug "--  ENV_OPTS:                   $ENV_OPTS"
log_debug "--  VESPAVERSION:               $VESPAVERSION"
if [[ ${#POSITIONAL[@]} > 0 ]]; then
  log_debug "--  NOT PARSED:                 ${POSITIONAL[*]}"
fi
log_debug ""

docker_cleanup

if ! docker network create --driver overlay --attachable $NETWORK &> /dev/null; then
  log_error "Could not create network $NETWORK. Exiting."; docker_cleanup; exit 1
else
  if ! docker service create --init --limit-pids 0 --replicas $NUMNODES --hostname "{{.Service.Name}}.{{.Task.Slot}}.{{.Task.ID}}.$NETWORK" \
                             --cap-add SYSLOG --cap-add SYS_PTRACE --cap-add SYS_ADMIN --cap-add SYS_NICE \
                             ${SERVICE_EXTRA_ARGS[@]+"${SERVICE_EXTRA_ARGS[@]}"} \
                             --name $SERVICE --env NODE_SERVER_OPTS="-c $TESTRUNNER.$NETWORK:27183" \
                             $ENV_OPTS $BINDMOUNT_OPTS --network $NETWORK --detach $DOCKERIMAGE &> /dev/null; then
    log_error "Could not create service $SERVICE. Exiting."; docker_cleanup; exit 1
  fi
fi

if [[ -n $CONFIGSERVER ]]; then
  if ! docker run --init --pids-limit -1 --hostname $CONFIGSERVER.$NETWORK --network $NETWORK --name $CONFIGSERVER --detach \
                  --cap-add SYSLOG --cap-add SYS_PTRACE --cap-add SYS_ADMIN --cap-add SYS_NICE \
                  --security-opt no-new-privileges=true --security-opt seccomp=unconfined \
                  -e VESPA_CONFIGSERVERS=$CONFIGSERVER.$NETWORK -e VESPA_CONFIGSERVER_JVMARGS="-verbose:gc -Xms12g -Xmx12g" \
                  -e VESPA_CONFIGSERVER_MULTITENANT=true -e VESPA_SYSTEM=dev --entrypoint bash \
                  $ENV_OPTS $BINDMOUNT_OPTS \
                  $DOCKERIMAGE -lc "\${VESPA_HOME-/opt/vespa}/bin/vespa-start-configserver && tail -f /dev/null" &> /dev/null; then
    log_error "Could not create configserver $CONFIGSERVER. Exiting."; docker_cleanup; exit 1
  fi
fi

docker run --rm \
           --init \
           --pids-limit -1 \
           --cap-add SYSLOG --cap-add SYS_PTRACE --cap-add SYS_ADMIN --cap-add SYS_NICE \
           --security-opt no-new-privileges=true --security-opt seccomp=unconfined \
           $ENV_OPTS \
           $BINDMOUNT_OPTS \
           $TESTRUNNER_BINDMOUNT_OPTS \
           -v $RESULTDIR:$BASEDIR \
           --name $TESTRUNNER \
           --hostname $TESTRUNNER.$NETWORK \
           --network $NETWORK \
           --entrypoint bash $DOCKERIMAGE -lc \
           "ruby \${VESPA_SYSTEM_TEST_HOME-/opt/vespa-systemtests}/lib/testrunner.rb $TESTRUNNER_OPTS"

if ! $KEEPRUNNING; then
  docker_cleanup
fi

echo
log_info "Test results available in $RESULTDIR"
echo
