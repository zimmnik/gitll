#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset
# set -o xtrace

export STOR="/srv/data/backup/gitll"

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
# RESTORE
echo "Restore the latest backup ..."
cd "${STOR}/latest"
for FILE in *.tar.zst; do
  docker volume rm "${FILE%-*-*-*-*.tar.zst}" || true
  docker volume create "${FILE%-*-*-*-*.tar.zst}" || true
  zstdmt -d -c "${FILE}" | docker volume import "${FILE%-*-*-*-*.tar.zst}" - 
  ls -alh $(docker volume inspect "${FILE%-*-*-*-*.tar.zst}" | jq -r '.[] | .Mountpoint')
done

#-------------------------------------------------------------------------------
# REMOVE LOCK
rm /tmp/gitlab-pod-backup.lock || true

#-------------------------------------------------------------------------------
# START GITLAB

if [[ "${STATE}" == "active" ]]; then
  systemctl start gitlab-pod
fi
