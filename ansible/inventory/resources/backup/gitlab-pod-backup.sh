#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
# set -o xtrace

export STOR="/srv/data/backup/gitll"

mkdir -p ${STOR}/latest
mkdir -p ${STOR}/previous

#-------------------------------------------------------------------------------
# ADD LOCK
if [[ -f /tmp/gitlab-pod-backup.lock ]]; then
  echo "backup already running or crashed"
  return 1
else
  touch /tmp/gitlab-pod-backup.lock
fi
  
#-------------------------------------------------------------------------------
# CHECK SYSTEM

STATE=$(systemctl show -p ActiveState --value gitlab-pod)
case ${STATE} in
active)
  systemctl stop gitlab-pod
  while docker pod inspect gitlab-pod &> /dev/null; do echo -n .; sleep 1; done
  ;;
inactive)
  :
  ;;
*)
  echo "Wrong service state - ${STATE}"
  exit 1
  ;;
esac

#-------------------------------------------------------------------------------
# CHECK LATEST BACKUP
echo "Check latest backup files ..."
cd "${STOR}/latest"
if compgen -G *.tar.zst > /dev/null; then
  for FILE in *.tar.zst; do
    zstdmt -d -c "${FILE}" | tar tf - > /dev/null
    echo "${FILE} done"
  done
fi


#-------------------------------------------------------------------------------
# ROTATE
echo "Rotate an old backup ..."
cd "${STOR}"
rm -v -rf previous/
mv -v latest/ previous/

#-------------------------------------------------------------------------------
# BACKUP
ID="$(date '+%Y-%m-%d')-$(openssl rand -hex 4)"
echo "Create a new backup ..."
mkdir -v latest/
cd "${STOR}/latest"
for VL in $(docker volume ls --noheading --quiet --filter "name=gitlab-*"); do
  umask o-rwx
  docker volume export "$VL" | zstdmt -z - > "${VL}-${ID}.tar.zst"
  echo "${VL}-${ID}.tar.zst done"
done

#-------------------------------------------------------------------------------
# REMOVE LOCK
rm /tmp/gitlab-pod-backup.lock || true

#-------------------------------------------------------------------------------
# START GITLAB

if [[ "${STATE}" == "active" ]]; then
  systemctl start gitlab-pod
fi
