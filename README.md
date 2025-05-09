# gitll

Gitll is an ansible playbook that allow to quickly configure local dev environment:
- gitlab-ce
- gitlab-runner

#### Requirements
- **python v3.12**
- **podman v5**
- **systemd v255**

## Usage

```ShellSession
systemctl enable podman.socket --now

dnf --assumeyes --quiet install python3.12-pip python3.12-pip-wheel git
python3.12 -m venv --upgrade-deps .venv && source .venv/bin/activate 
  python --version

pip install --requirement ansible/pip_requirements.txt
  pip list --format freeze
  ansible-lint --version

export ANSIBLE_CONFIG=ansible/ansible.cfg
ansible-galaxy install --role-file ansible/galaxy_requirements.yml
  ansible-galaxy collection list --format yaml
  ansible-lint -c ansible/.ansible-lint ansible/
  ansible-inventory --graph --vars
cat << 'EOF' >> .env
export GITLAB_POD_ADMIN_PASSWORD="xxx"
export GITLAB_POD_ADMIN_API_TOKEN="yyy"
export GITLAB_POD_ADMIN_SSH_PUB_KEY="ssh-rsa zzz Administrator (domain.com)"
export GITLAB_POD_TLS_CA_PATH="/some/file1"
export GITLAB_POD_TLS_CRT_PATH="/some/file2"
export GITLAB_POD_TLS_KEY_PATH="/some/file3"
EOF
source .env

ansible-playbook -K ansible/[install|delete].yml 

#systemctl start gitlab-pod-backup.service && journalctl -u gitlab-pod-backup -f
#systemctl start gitlab-pod-restore.service && journalctl -u gitlab-pod-restore -f
```

## TODO
```
cat /etc/containers/containers.conf 
#[network]
#network_backend = "cni"
[containers]
shm_size="256m"

```
