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

%_ids.json.gz:
	wget http://files.tmdb.org/p/exports/$$(basename $@ .json.gz)_$(YESTERDAY).json.gz -O $@

%_ids.json: %_ids.json.gz
	gunzip -k $^

popular_person.json: person_ids.json
	cat $^ | jq -s 'sort_by(.popularity) | reverse | .[0:10000] | .[]' | jq -c > $@

# In our case, init on only one host, because all hosts homes are synchronized via NFS
init_remote: crawler/target/release/crawler splitter/target/release/splitter popular_person.json
	ssh $(REMOTE_USER)@$(REMOTE_HOST) mkdir -p $(REMOTE_WORKING_DIR)
	scp -r .env makefile $(IPS) map_reduce.sh $^ $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_WORKING_DIR)
	ssh $(REMOTE_USER)@$(REMOTE_HOST) "cd $(REMOTE_WORKING_DIR); make movie_ids.json"
	ssh $(REMOTE_USER)@$(REMOTE_HOST) "cd $(REMOTE_WORKING_DIR); curl -O 'https://raw.githubusercontent.com/tavinus/cloudsend.sh/master/cloudsend.sh' && chmod +x cloudsend.sh"

ping_remote:
	pssh -t 0 --user $(REMOTE_USER) --hosts $(IPS) --inline-stdout "echo pong"

load_remote:
	pssh -t 0 --user $(REMOTE_USER) --hosts $(IPS) -i "cat /proc/loadavg"

map_reduce_remote:
	./$@.sh

clean:
	cd crawler && cargo clean && rm -rf target
	cd splitter && cargo clean && rm -rf target
	rm -f *.json*

kill_remote:
	pssh -t 0 --user $(REMOTE_USER) --hosts $(IPS) --inline-stdout "killall crawler"

clean_remote:
	ssh $(REMOTE_USER)@$(REMOTE_HOST) rm -rf $(REMOTE_WORKING_DIR)
