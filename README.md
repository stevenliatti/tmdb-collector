# TMDb collector

Distributed and parallel collector from TMDb via its API, written with Rust, makefile and shell scripts. Designed if you have to quickly retrieve the full dataset of movies and actors. This programme is designed to be run on a fleet of machines accessible by SSH. It use the [daily file exports](https://developers.themoviedb.org/3/getting-started/daily-file-exports) of TMDb.

## Workflow

Until the end of 2019, the TMDb API had a usage limit of 40 requests over 10 seconds, or 4 requests per second. But since the beginning of the year, there is no longer a limit. We can therefore "bombard" the API to retrieve data as quickly as we want. To do this, we have developed a multi-threaded crawler in Rust. The choice of Rust was made for its performance, the accuracy of the code obtained and to practice the language as well. We used different Rust *crates*, such as [reqwest](https://crates.io/crates/reqwest) for HTTP requests, [serde](https://crates.io/crates/serde) and [serde_json](https://crates.io/crates/serde_json) for the (de)serialisation of JSON and the standard Rust library for competition management (via [channels](https://doc.rust-lang.org/rust-by-example/std_misc/channels.html)). Each recovered movie is de-serialised and the following conditions are tested:

```rust
fn filter_movie(movie: &Movie) -> bool {
    const MIN_BUDGET: usize = 1000;
    const MIN_REVENUE: usize = 10000000;
    return movie.budget > MIN_BUDGET
        && movie.revenue >= MIN_REVENUE
        && !movie.genres.is_empty()
        && !movie.credits.cast.is_empty()
        && !movie.credits.crew.is_empty();
}
```

If these conditions are met, the movie is kept for writing to a file.

To further speed up recovery, the program can be distributed to different machines available via `ssh`. Using a second small Rust program, the `splitter`, and various Linux commands such as `parallel-ssh`, we were able to separate the IDs file from the films into as many equal parts as there were machines available. With a last script `map_reduce_remote.sh` and [`cloudsend.sh`](https://github.com/tavinus/cloudsend.sh), we were able to retrieve all the product files containing the complete movie information, one movie per line, from a nextcloud account in our possession.

To reproduce this recovery, you need GNU/Linux machines connected to the internet, which you can control with `ssh`, whose `home` directory is synchronised on each one, and fill in the `.env` file in a similar way to the following one:


```conf
IPS=ips.txt ; IPs machines hosts, one host/ip per line
REMOTE_USER=user ; SSH user
REMOTE_HOST=192.168.1.2 ; Main machine IP, for init
REMOTE_WORKING_DIR=working_dir ; Distant working directory
TMDB_API_KEY=1a2b3c4d5e6f7g8h9i0j ; TMDb API key
THREADS=20 ; threads per machine
NEXTCLOUD_UPLOAD=https://your.nextcloud.com/qwertz ; nextcloud URL
```

A `makefile` is available to perform each step of the recovery process.
