#!/bin/bash

# Global Variables
ADVERTISED_CLIENT_URL=""
ETCD_SERVER_CERT=${ETCD_PKI_HOSTPATH}/${ETCD_SERVER_CERT}
ETCD_SERVER_KEY=${ETCD_PKI_HOSTPATH}/${ETCD_SERVER_KEY}
ETCD_CACERT=${ETCD_PKI_HOSTPATH}/${ETCD_CACERT}
ADVERTISED_CLIENT_URL=${ETCD_ENDPOINTS}

function paramValue(){
    source=$1
    search=$2
    local result=${source#*$search}
    echo "$result"
}

function log(){
    
    if [ ! -d ${LOG_DIR} ]; then
        mkdir -p ${LOG_DIR}
    fi

    LOG_FILE_DATE=$(date '+%Y-%m')
    LOG_FILE=${LOG_DIR}/etcd-backup-${LOG_FILE_DATE}.log
    if [ ! -f ${LOG_FILE} ]; then
        touch ${LOG_FILE}
    fi
    LOG_TIMESTAMP=$(date '+%F-%T %p')
    LOG_MESSAGE="${LOG_TIMESTAMP}   $1"
    echo "$LOG_MESSAGE"
    echo "$LOG_MESSAGE" >> ${LOG_FILE}
}

function backup(){

    #kubectl=(kubectl --kubeconfig /config)
    
    ETCD_PODS_NAME=$(kubectl get pod -l component=etcd -o jsonpath="{.items[*].metadata.name}" -n kube-system) 

    for etcd in $ETCD_PODS_NAME
    do
        log "Startinng snapshot for $etcd ... "

        COMMANDS=$(kubectl get pods $etcd -n kube-system -o=jsonpath='{.spec.containers[0].command}')
        
        for row in $(echo "${COMMANDS}" | jq -r '.[]'); do
            if [[ ${row} = --advertise-client-urls* ]]; then
                ADVERTISED_CLIENT_URL=$(paramValue ${row} "=")
                log "ADVERTISED_CLIENT_URL = ${ADVERTISED_CLIENT_URL}"
            elif [[ ${row} = --cert-file* ]]; then
                ETCD_SERVER_CERT=$(paramValue ${row} "=")
                log "ETCD_SERVER_CERT = ${ETCD_SERVER_CERT}"
            elif [[ ${row} = --key-file* ]]; then
                ETCD_SERVER_KEY=$(paramValue ${row} "=")
                log "ETCD_SERVER_KEY = ${ETCD_SERVER_KEY}"
            elif [[ ${row} = --trusted-ca-file* ]]; then
                ETCD_CACERT=$(paramValue ${row} "=")
                log "ETCD_CACERT = ${ETCD_CACERT}"
            fi
        done

        cp ${ETCD_CACERT} /tmp/ca.crt && cp ${ETCD_SERVER_CERT} /tmp/server.crt && cp ${ETCD_SERVER_KEY} /tmp/server.key

        TIMESTAMP=$(date '+%Y-%m-%d-%H-%M-%s')

        log "Backing up $etcd ... Snapshot file: ${BAKCUP_PATH}/$etcd-${TIMESTAMP} ..."

        OUTPUT=$( (ETCDCTL_API=3 ${ETCD_PATH}/etcdctl --endpoints ${ADVERTISED_CLIENT_URL} \
        snapshot save ${BAKCUP_PATH}/$etcd-${TIMESTAMP} \
        --cacert="/tmp/ca.crt" \
        --cert="/tmp/server.crt" \
        --key="/tmp/server.key") 2>&1 )

        log "${OUTPUT}"
        
    done
}

log "Timezone: ${TZ}"
backup