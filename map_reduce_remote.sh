#!/usr/bin/env bash

source .env

let "machine_id = 0"

for host in $(cat $IPS); do
    ssh $REMOTE_USER@$host "cd $REMOTE_WORKING_DIR; nohup ./map_reduce.sh &> $machine_id.out &"
    let "machine_id = machine_id + 1"
done
