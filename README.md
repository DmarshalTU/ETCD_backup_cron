# ETCD_backup_cron

https://hub.docker.com/repository/docker/dmarshaltu/etcd-backup-base
https://hub.docker.com/repository/docker/dmarshaltu/etcd-backup

/var/local-path-provisioner/...

## Etcd Backup general

Locate kube-apiserver.yaml on master node

``` bash
root@master01~ cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -i -E 'etcd-.*=/etc|etcd-servers'
    - --etcd-cafile={path_to}/ca.pem # ETCDCTL_CACERT
    - --etcd-certfile={path_to}/master01.pem # ETCDCTL_CERT
    - --etcd-keyfile={path_to}/master01-key.pem # ETCDCTL_KEY
    - --etcd-servers=https://{first_endpoint}:2379,https://{second_endpoint}:2379,https://{third_endpoint}:2379 # --endpoints
```

### Show endpoints of etcd

``` bash
ETCDCTL_API=3 ETCDCTL_CACERT={path_to}/ca.pem ETCDCTL_CERT={path_to}/master01.pemETCDCTL_KEY={path_to}/master01-key.pem \
 etcdctl --endpoints=https://{first_endpoint}:2379,https://{second_endpoint}:2379,https://{third_endpoint}:2379 member list --write-out=table

+------------------+---------+-------+-------------------------------+-------------------------------+------------+
|        ID        | STATUS  | NAME  |           PEER ADDRS          |          CLIENT ADDRS         | IS LEARNER |
+------------------+---------+-------+-------------------------------+-------------------------------+------------+
|  347799df1339cc0 | started | etcd2 | https://{secon_endpoint}:2380 | https://{secon_endpoint}:2379 |      false |
| 42cc40fb31f053f4 | started | etcd3 | https://{third_endpoint}:2380 | https://{third_endpoint}:2379 |      false |
| f3557b48052211ce | started | etcd1 | https://{first_endpoint}:2380 | https://{first_endpoint}:2379 |      false |
+------------------+---------+-------+----------------------------+----------------------------+------------------+
```

### Create backup of etcd to snapshot.db

``` bash
ETCDCTL_API=3 ETCDCTL_CACERT={path_to}/ca.pem ETCDCTL_CERT={path_to}/master01.pemETCDCTL_KEY={path_to}/master01-key.pem \
 etcdctl --endpoints=https://{first_endpoint} snapshot save /var/lib/etcd/snapshot.db

{"level":"info","ts":1652104388.37455,"caller":"snapshot/v3_snapshot.go:119","msg":"created temporary db file","path":"/var/lib/etcd/snapshot.db.part"}
{"level":"info","ts":"2022-05-09T16:53:08.381+0300","caller":"clientv3/maintenance.go:200","msg":"opened snapshot stream; downloading"}
{"level":"info","ts":1652104388.3819335,"caller":"snapshot/v3_snapshot.go:127","msg":"fetching snapshot","endpoint":"https://{first_endpoint}:2379"}
{"level":"info","ts":"2022-05-09T16:53:09.321+0300","caller":"clientv3/maintenance.go:208","msg":"completed snapshot read; closing"}
{"level":"info","ts":1652104389.4932795,"caller":"snapshot/v3_snapshot.go:142","msg":"fetched snapshot","endpoint":"https://{first_endpoint}:2379","size":"154 MB","took":1.118669416}
{"level":"info","ts":1652104389.5116656,"caller":"snapshot/v3_snapshot.go:152","msg":"saved","path":"/var/lib/etcd/snapshot.db"}
Snapshot saved at /var/lib/etcd/snapshot.db
```

### Show backup status of etcd snapshot.db

``` bash
ETCDCTL_API=3 ETCDCTL_CACERT={path_to}/ca.pem ETCDCTL_CERT={path_to}/master01.pemETCDCTL_KEY={path_to}/master01-key.pem \
 etcdctl --endpoints=https://{first_endpoint} --write-out=table snapshot status /var/lib/etcd/snapshot.db

+---------+-----------+------------+------------+
|  HASH   | REVISION  | TOTAL KEYS | TOTAL SIZE |
+---------+-----------+------------+------------+
| 9643227 | 287233484 |      18123 |     324 MB |
+---------+-----------+------------+------------+
```

### Schedule backup of etcd to snapshot.db

``` py
import schedule

def backup_etcd(): ...

schedule.every().day.at("00:00").do(backup_etcd)
```
or
``` bash
00 00 * * * python /path/to/main.py
```

#### Denis Tu, May 2022
