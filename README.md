# Blockbridge Shell scripts

These Shell scripts are provided as a refence to illustate automation of Storage operations directly with Blockbridge as well as with Proxmox VE.

- ## Snapshot management: snap-mgmt.sh

  Add snapshot to tagged Blockbridge virtual disks:
      
      * "-h" IP or hostname of Blockbridge node
      
      * "-t" parameter to specify a tag. All disks with this tag will be snapshotted.
      
      To assign a tag to disk from CLI:`bb disk update -d [disk-label] --tag snapSchedule`
      
      * "-d" Number of days to keep snapshots
      
      * "-a" Authorization token
      
      * "-p" Snapshot name Prefix
      

   Example: `snap-mgmt.sh -h bbhost -d 3 -a token -t snapSchedule`
  
   #### Quick Start

   #### From your Blockbridge Controlplane shell create a new user in SYSTEM account which is only allowed to manage snapshots
   ````
   bb auth login --user system
   bb user create --name snapmgmt --grant vss.manage_snapshots
   ````

   ##### Create a persistent authorization token that inherits user rights (note the generated token, it cannot be re-displayed):
   ````
   bb authorization create --user snapmgmt@system --scope 'v:o=all v:r=manage_snapshots'
   ````

- ## Proxmox Virtual Environment (PVE) Snapshot management: pve-snapshot_control.sh

  Add snapshot to tagged PVE virtual machines:
      
      * -t <tag>        Tag used to identify VMs that need snapshots (required)
      
      * -p <prefix>     Prefix to append to snapshot label (default 'auto')
            
      * -c <count>      Number of snapshots to maintain (default 2, max 16)
      
      * -d              Prune snapshots as specified by (-c). Does not create new snapshots.

  #### Examples:

   Example: `pve-snapshot_control.sh -t autosnap -p autosnap -c 3`
 
   Take a snapshot of all PVE VMs that contain tag "autosnap". Keep at most 3 snapshots on each VM.
