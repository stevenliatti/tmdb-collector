#!/usr/bin/env bash

source .env

line=$(grep -nr $(hostname -I | cut -d' ' -f1) $IPS | cut -d':' -f1)
let "machine_id = $line - 1"
machines=$(wc -w $IPS | cut -d' ' -f1)

echo "MAP: Split ids files"
./splitter movie_ids.json movie_ids$machine_id.json $machines $machine_id
./splitter popular_person.json actor_ids$machine_id.json $machines $machine_id

echo "MAP: Start crawler $IPS $machines $machine_id"
./crawler $TMDB_API_KEY $THREADS movie_ids$machine_id.json movies$machine_id.json movie
./crawler $TMDB_API_KEY $THREADS actor_ids$machine_id.json actors$machine_id.json actor

echo "REDUCE: send movies$machine_id.json"
./cloudsend.sh movies$machine_id.json $NEXTCLOUD_UPLOAD

echo "REDUCE: send actors$machine_id.json"
./cloudsend.sh actors$machine_id.json $NEXTCLOUD_UPLOAD
