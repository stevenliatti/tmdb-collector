#!/usr/bin/env bash

source .env

line=$(grep -nr $(hostname -I | cut -d' ' -f1) $IPS | cut -d':' -f1)
let "machine_id = $line - 1"
machines=$(wc -w $IPS | cut -d' ' -f1)

echo "MAP: Start crawler $IPS $machines $machine_id"
./splitter movie_ids.json movie_ids$machine_id.json $machines $machine_id
./crawler $TMDB_API_KEY movie_ids$machine_id.json movies$machine_id.json $THREADS

echo "REDUCE: send movies$machine_id.json"
./cloudsend.sh movies$machine_id.json $NEXTCLOUD_UPLOAD