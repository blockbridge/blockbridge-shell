# Blockbridge Shell scripts

This Shell script is provided as a refence to illustate automation of Storage operations

## Snapshot management:

  1. Add snapshot to specified disk:
      
      * "-h" IP or hostname of Blockbridge node
      
      * "-t" parameter to specify a tag. All disks with this tag will be snapshotted.
      
      To assign a tag to disk from CLI:`bb disk update -d [disk-label] --tag snapSchedule`
      
      * "-d" Number of days to keep snapshots
      
      * "-a" Authorization token
      
      * "-p" Snapshot name Prefix
      

## Examples:

 Example: `snap-mgmt.sh -h bbhost -d 3 -a token -t snapSchedule`
 
 Example edit thes script to set all variables: `snap-mgmt.sh`
 
 
## Quick Start

### Run from your Blockbridge Controlplane shell:

#### Create a new user in BBUSER account which is only allowed to manage snapshots and Authorization tokens
````
bb auth login --user system
bb user create --name snapmgmt --grant vss.manage_snapshots
````

#### Create a persistent authorization token that inherits user rights (note the generated token, it cannot be re-displayed):
````
bb authorization create --user snapmgmt@system --scope 'v:o=all v:r=manage_snapshots'
````

## To avoid having to approve self-signed certificate, please follow this guide to install a properly signed SSL cert:
https://kb.blockbridge.com/guide/custom-certs/
