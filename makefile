include .env
export

# Get file from yesterday to be sure that it exists.
# Depending your timezone, the file of today does not yet exist.
YESTERDAY = $(shell date --date="yesterday" +%m_%d_%Y)

remote_all: init_remote map_reduce_remote

show_env: .env
	@cat .env

crawler/target/release/crawler: crawler/src/* crawler/Cargo.toml
	cd crawler && docker run --rm --user "$$(id -u)":"$$(id -g)" -v "$$PWD":/usr/src/myapp -w /usr/src/myapp rust cargo build --release

splitter/target/release/splitter: splitter/src/* splitter/Cargo.toml
	cd splitter && docker run --rm --user "$$(id -u)":"$$(id -g)" -v "$$PWD":/usr/src/myapp -w /usr/src/myapp rust cargo build --release

movie_ids:
	-wget -nc http://files.tmdb.org/p/exports/movie_ids_$(YESTERDAY).json.gz -O movie_ids.json.gz
	-gunzip -k movie_ids.json.gz

# In our case, init on only one host, because all hosts homes are synchronized via NFS
init_remote: crawler/target/release/crawler splitter/target/release/splitter
	ssh $(REMOTE_USER)@$(REMOTE_HOST) mkdir -p $(REMOTE_WORKING_DIR)
	scp -r .env makefile $(IPS) map_reduce.sh crawler/target/release/crawler splitter/target/release/splitter $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_WORKING_DIR)
	ssh $(REMOTE_USER)@$(REMOTE_HOST) "cd $(REMOTE_WORKING_DIR); make movie_ids"
	ssh $(REMOTE_USER)@$(REMOTE_HOST) "cd $(REMOTE_WORKING_DIR); curl -O 'https://raw.githubusercontent.com/tavinus/cloudsend.sh/master/cloudsend.sh' && chmod +x cloudsend.sh"

ping_remote:
	pssh -t 0 --user $(REMOTE_USER) --hosts $(IPS) --inline-stdout "echo pong"

load_remote:
	pssh -t 0 --user $(REMOTE_USER) --hosts $(IPS) -i "cat /proc/loadavg"

map_reduce_remote:
	pssh -t 0 --user $(REMOTE_USER) --hosts $(IPS) -i "cd $(REMOTE_WORKING_DIR); ./map_reduce.sh"

clean:
	cd crawler && cargo clean && rm -rf target
	cd splitter && cargo clean && rm -rf target
	rm -f movie_ids.json movie_ids.json.gz
