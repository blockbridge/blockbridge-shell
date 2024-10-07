#!/usr/bin/env bash
set -euo pipefail
#set -x

#per-vm snapshots (without memory state) driven by tag.

# Function to display help
show_help() {
    echo "Usage: $0 -t <tag> -p <prefix> -c <count>"
    echo ""
    echo "Arguments:"
    echo "  -t <tag>        Tag used to identify VMs that need snapshots (required)"
    echo "  -p <prefix>     Prefix to append to snapshot label (default 'auto')"
    echo "  -c <count>      Number of snapshots to maintain (default 2, max 16)"
    echo "  -d              Prune snapshots as specified by (-c). Does not create new snapshots."
    echo ""
}

# Initialize variables
tag=""
prefix="auto"
count="2"
cleanup=0

if (! getopts ":t" opt); then
  show_help
  exit 1
fi

# Parse arguments
while getopts "t:p:c:h:d" opt; do
    case ${opt} in
        t)
            tag=${OPTARG:-}
            ;;
        p)
            prefix=${OPTARG:-}
            ;;
        c)
            count=$OPTARG
            if [[ $count -gt 16 ]];then
              count=16
            fi
            ;;
        d)
            cleanup=1
            ;;
        h)
            show_help
            exit 0
            ;;
        \?)
            echo "Invalid option: -${OPTARG:-}" >&2
            show_help
            exit 1
            ;;
        :)
            echo "Error: Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

# If all arguments are provided
echo "Tag: $tag"
echo "Prefix: $prefix"
echo "Count: $count"

get_tagged_vms(){
  local tagged_vms
  tagged_vms=$(pvesh get /cluster/resources --type vm --output-format json | \
   jq --arg TAG "$tag" -r '.[] | select(.tags | type == "string" and ( . == $TAG or (. | split(";") | index($TAG) != null))) | "\(.vmid)=\(.node)"' | \
   paste -sd ' ')
  echo "${tagged_vms:-}"
}

get_snapshot_count(){
  local vmid node snap_count 
  vmid="$1"
  node="$2"
  snap_count=$(pvesh get /nodes/"$node"/qemu/"$vmid"/snapshot --output-format json | \
   jq --arg PREFIX "$prefix" '[.[] | select(.name | startswith($PREFIX))]|length')
  echo "${snap_count:=0}"
}

check_task_status(){
  local upid node task_state task_status count
  if [[ "$1" != *"UPID"* ]]; then
    echo "No valid UPID found!"
    echo "$1"
    return 1
  fi
  upid=$(echo "$1" |paste -sd ' ' | sed 's/.*\(UPID:.*\)/\1/' | sed 's/"//g')
  node=$(echo "$upid"|cut -d: -f2) 

  task_state=$(pvesh get /nodes/"$node"/tasks/"$upid"/status --output-format json )
  task_status=$(jq -r .status <<< "$task_state")
  while [[ "$task_status" != "stopped" && "${counter:=0}" -lt 10 ]]; do
    sleep 1
    task_state=$(pvesh get /nodes/"$node"/tasks/"$upid"/status --output-format json )
    task_status=$(jq -r .status <<< "$task_state")
    ((counter++))
    false
  done || ( echo "Task status is : $exit_status"
            echo "FAILED TASK: $upid"
            echo "EXIT STATUS: $exit_status"
            return 1
          )
  exit_status=$(echo "$task_state" | jq -r '.exitstatus' )
  if [[ "$exit_status" != "OK" ]]; then
    echo "FAILED TASK: $upid"
    echo "EXIT STATUS: $exit_status"
    return 1
  else
    echo "TASK $upid"
    echo "STATUS: $exit_status"
  fi
}

delete_old_snapshots(){
  local vmid node snaps_now oldest_snap oldest_snap_name oldest_snap_time status
  vmid="$1"
  node="$2"
  snaps_now=$(get_snapshot_count "$vmid" "$node")
  while [[ "$snaps_now" -gt "$count" ]];do
    echo "Current number of Snapshot Control snaps for VM $vmid is $snaps_now. Allowed number of snapshots is $count"
    oldest_snap=$(pvesh get /nodes/"$node"/qemu/"$vmid"/snapshot --output-format json | \
     jq --arg PREFIX "$prefix" -r '[.[]|select(.name | startswith($PREFIX))] | map(select(.snaptime != null)) | min_by(.snaptime)')
    oldest_snap_name=$(echo "$oldest_snap"|jq -r '.name')
    oldest_snap_time=$(echo "$oldest_snap"|jq -r '.snaptime')
    echo "Removing oldest snapshot $oldest_snap_name created on $(date -d @"$oldest_snap_time" '+%Y-%m-%d %H:%M:%S')"
    status=$(pvesh delete /nodes/"$node"/qemu/"$vmid"/snapshot/"$oldest_snap_name" )
    if ! check_task_status "$status";then
      echo "Snapshot delete for VM $vmid FAILED"
    fi
    snaps_now=$(get_snapshot_count "$vmid" "$node")
    sleep 1
  done
  echo "Current number of snapshots for VM $vmid is $snaps_now"
}

create_new_snapshot(){
  local vmid node suffix status
  vmid="$1"
  node="$2"
  suffix=$(date '+%Y-%m-%d-%H-%M')
  echo "Create new snapshot for VM $vmid with name ${prefix}_${suffix}"
  status=$(pvesh create /nodes/"$node"/qemu/"$vmid"/snapshot -snapname "$prefix"_"$suffix" -vmstate 0 -description "Created by Snapshot Control on $suffix" )
  echo "VM $vmid has $(get_snapshot_count "$vmid" "$node") snapshots"
  if ! check_task_status "$status";then
    return 1
  else
    return 0
  fi
}

tagged_vms=$(get_tagged_vms)
if [ -n "$tagged_vms" ];then
  echo "The following VM/s match the TAG=$tag selection criteria and will be processed: $(echo "$tagged_vms"| sed 's/=[^ ]*//g')"
else
  echo "Did not find any VMs with TAG $tag"
  exit
fi

if [[ "$cleanup" == 1 ]]; then
  echo "CLEANUP specified (-d) only attempting to remove extra snapshots"
fi

for vm in $tagged_vms; do
  vmid="${vm%%=*}"
  node="${vm#*=}"

  if [[ "$cleanup" == 1 ]]; then
    echo "----"
    delete_old_snapshots "$vmid" "$node"
  else
    echo "----"
    if ! create_new_snapshot "$vmid" "$node";then
      failed_vms="${failed_vms:-} $vmid"
    else
      delete_old_snapshots "$vmid" "$node"
    fi
  fi
done

if [[ -n ${failed_vms:-} ]];then
  echo "Following VM snapshots failed: $failed_vms"
  echo "Examine PVE task log"
  exit 1
else
  exit 0
fi
