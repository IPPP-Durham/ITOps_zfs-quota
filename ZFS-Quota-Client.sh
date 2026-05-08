#!/bin/bash
# ZFS Quota Client v2.6
# 2021 - Adam Boutcher
# IPPP, Durham University

# User Quota
servers[0]="/mnt/home"
servers[1]="/mnt/storage"

# Group Quota
grpsrvs[0]="/mnt/groups"

################################################################################
QUSER=${1:-$USER}

function check_bin() {
  if ! command -v "${1}" &>/dev/null; then
    echo "$1 cannot be found. Please install it or add it to the path. Exiting."
    exit 1
  fi
}

# This loops the quota checking in a function.
# Usage: quota_check (int)$id (string)$quota_dir (string)[$grp_name]
function zquota_check() {
  if [[ -n "${1}" && -n "${2}" ]]; then

    id="${1}"
    server="${2}"

    # This is a better matching than the previous,
    #  it should now look for a start of line and also '::'.
    zquota=$(grep "^${id}::" "${server}/quota.zfs" 2>/dev/null);
    if [[ -n "${zquota}" ]]; then
      zused=$(echo "${zquota}" | awk -F'::' '{print $2}' | numfmt --to=iec);
      if [[ $zused == "nan" ]]; then
        zused=0;
      fi
      ztotal=$(echo "${zquota}" | awk -F'::' '{print $3}');
      if [[ $ztotal != "none" ]]; then
        ztotal=$(echo "${ztotal}" | numfmt --to=iec);
      fi
      zperc=$(echo "${zquota}" | awk -F'::' '{print $4}');
      zage=$(date +"%c" -d @$(stat -c %Z ${server}/quota.zfs))
      # Display a nice goup name.
      if [[ -z "${3}" ]]; then
        mount_name="${server}"
      else
        mount_name="${server} (${3})"
      fi
      printf ' %-35s %-15s %-10s %-20s\n' "${mount_name}" "${zused} (${zperc})" "${ztotal}" "${zage}";
    fi
  fi
}

check_bin grep
check_bin awk
check_bin numfmt
check_bin stat
check_bin id
check_bin date
check_bin getent

printf "\n Storage Quota v2.6."
printf "\n Group reports are entire group usage not individual.\n"
printf "\n Quota Report for ${QUSER}\n"
printf ' %-35s %-15s %-10s %-20s\n' "Mount Point" "Used" "Total" "Last Checked";

# User Checks
QUID=$(id -u "${QUSER}" 2>/dev/null)
for server in "${servers[@]}"; do
  zquota_check "${QUID}" "${server}"
done;

# Group Checks
for grpid in $(id -G "${QUSER}" 2>/dev/null); do
  for server in "${grpsrvs[@]}"; do
    zquota_check "${grpid}" "${server}" "$(getent group $grp | awk -F':' '{print $1}')"
  done;
done;


printf "\n"
exit 0;
