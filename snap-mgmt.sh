#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq;then
  echo "Please install jq"
  exit 1
fi

export BLOCKBRIDGE_API_HOST=dogfood
export BLOCKBRIDGE_API_KEY="1/QuOVIdHIO...A"
export DAYS=3
export TAG="snapschedule"
export PREFIX="scheduled_"
DATE=$(date +"%H-%M-%S_%m-%d-%y")
export DATE

usage() { echo "Usage: $0 [-h <BLOCKBRIDGE_HOST>] [-a <AUTHORIZATION_TOKEN>] [-d <DAYS_TO_KEEP_SNAPSHOTS>] [-t <TAG>] [-p <PREFIX>]" 1>&2; exit 1; }

while getopts h:t:d:a:p flag
do
    case "${flag}" in
        h) BLOCKBRIDGE_API_HOST=${OPTARG-};;
        a) BLOCKBRIDGE_API_KEY=${OPTARG-};;
        d) DAYS=${OPTARG-};;
        t) TAG=${OPTARG-};;
        p) PREFIX=${OPTARG-};;
        \?) usage ;;
        :) usage ;;
        *) usage ;;
    esac
done

if [ -z "${BLOCKBRIDGE_API_HOST-}" ] || [ -z "${BLOCKBRIDGE_API_KEY-}" ] || [ -z "${DAYS-}" ]; then
    usage
fi

#By using disk Tag option we can specify a group of disks to be snapshotted and avoid running an instance of script per disk
if [[ -n $TAG ]];then
#get all disks that are tagged
  disk_list=$(bb disk list -R|jq -r '.[]|select(.tags[] == env.TAG)|.serial')
#if no disks are tagged - exit with error code
  if [[ $disk_list == "" ]];then
    echo "no disks found with tag: $TAG"
    exit 1
  else
#iterate through tagged disks
    for disk in $disk_list;do
      #check if the disk has existing snapshots that have specified prefix. By using prefix we avoid removing manually created snapshots
      if ! snap_list=$(bb snapshot list --disk "$disk" -X label -X serial|grep -E "$PREFIX");then snap_list="";fi
      #check if number of prefixed snapshots is less than specified days
      snap_count=( "$snap_list" )
      snap_counter=${#snap_count[@]}

      while [[ $snap_counter -ge $DAYS ]];do
        #if its equal or more - find oldest snapshot and remove it
        echo "There are $snap_counter snapshots, deleting oldest"
        old_snap=$(bb snapshot list --disk "$disk" -R |jq -r '.[]|select(.label|contains(env.PREFIX))|[.ctime,.serial]|@tsv'|sort -k1|head -1|cut -f2)
        bb snapshot remove --snapshot "$old_snap"
        ((snap_counter=snap_counter-1))
      done

      #create new snapshot
      bb snapshot create --disk "$disk" --label "$PREFIX""$DATE""_snapshot"
    done
  fi   
fi
