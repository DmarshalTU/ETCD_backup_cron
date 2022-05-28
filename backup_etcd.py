import re
import logging
import shlex
import datetime

from subprocess import Popen, PIPE, check_output
from os import path
from pathlib import Path
from sh import grep, cat



PATH = 'ETCD_BACKUP'
DATA = grep(cat("/etc/kubernetes/manifests/kube-apiserver.yaml"), '-e', 'etcd-.*=')
DATA_T = "cat /etc/kubernetes/manifests/kube-apiserver.yaml"
DATA_D = "grep -i -E 'etcd-.*=/etc|etcd-servers'"
CAFILE = re.search('--etcd-cafile=(.*?).pem', str(DATA))
CERTFILE = re.search('--etcd-certfile=(.*?).pem', str(DATA))
KEYFILE = re.search('--etcd-keyfile=(.*?).pem', str(DATA))
SERVERS = re.search('--etcd-servers=(.*?),', str(DATA))

logging.basicConfig(filename='etcd_backup.log', level=logging.INFO, format='%(asctime)s %(message)s')


def content_folder():
    """
    Creates a folder for the backup
    """
    logging.info('Checking for backup folder')
    if not Path(f"./{PATH}").is_dir():
        Path(f"{PATH}").mkdir(parents=True, exist_ok=True)
        logging.info('Backup folder created')
    else:
        logging.info('Backup folder already exists')


def is_tool():
    """
    Checks if etcdctl is installed

    Returns:
        bool: True if etcdctl is installed
    """
    from shutil import which
    logging.info('Checking if etcdctl is installed')
    return which("etcdctl") is not None


def backup_etcd(ca, cert, key):
    """
    Backup etcd data

    Args:
        ca (str): etcd ca file
        cert (str): etcd cert file
        key (str): etcd key file
    """
    now = datetime.datetime.now()
    files = {ca, cert, key}
    for file in files:
        if not path.isfile(file):
            logging.error(f'{file} is not a file')
            exit(1)
    logging.info('Starting backup')
    command = f'sudo etcdctl --cacert={ca} --cert={cert} --key={key} snapshot save ./{PATH}/etcd-{now.strftime("%Y-%m-%d-%H-%M-%S")}.snap'
    process = Popen(command.split(), stdout=PIPE)
    output, error = process.communicate()
    logging.info(output.decode('utf-8'))
    

def main():
    content_folder()
    logging.info('Preparing to backup etcd data')

    if is_tool():
        cafile, certfile, keyfile = CAFILE.group(1) + '.pem', CERTFILE.group(1) + '.pem', KEYFILE.group(1) + '.pem' # SERVERS.group(1)
        
        args = shlex.split(DATA_T)
        args2 = shlex.split(DATA_D)
        ps = Popen((args), stdout=PIPE)
        output = check_output((args2), stdin=ps.stdout)
        ps.wait()
        
        s = output.split()[-1].decode("utf-8")
        pat = r'.*?\=(.*)'
        match = re.search(pat, s)
        sl = match.group(1).split(',')
        
        logging.info("GENERATED\n")
        logging.info(sl)
        logging.info(cafile)
        logging.info(certfile)
        logging.info(keyfile)
        
        
        for _ in sl:
            logging.info(f'Starting backup from {_}')
            backup_etcd(cafile, certfile, keyfile)
        logging.info(f'END OF BACKUP')

    else:
        logging.error('etcdctl is not installed')

if __name__ == '__main__':
    main()
