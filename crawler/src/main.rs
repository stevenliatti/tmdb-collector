// TMDb movies crawler
// Steven Liatti & Jeremy Favre

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::env;
use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::sync::mpsc::channel;
use std::thread;
use std::time::Instant;

#[derive(Serialize, Deserialize, Debug)]
struct IdObject {
    id: usize,
}

#[derive(Serialize, Deserialize, Debug)]
struct Credits {
    cast: Vec<IdObject>,
    crew: Vec<IdObject>,
}

#[derive(Serialize, Deserialize, Debug)]
struct ConnectedMovies {
    total_results: usize,
}

#[derive(Serialize, Deserialize, Debug)]
struct Movie {
    budget: usize,
    revenue: usize,
    genres: Vec<IdObject>,
    credits: Credits,
    similar: ConnectedMovies,
    recommendations: ConnectedMovies,
}

fn filter_movie(movie: &Movie) -> bool {
    const MIN_BUDGET: usize = 1000;
    const MIN_REVENUE: usize = 100000000;
    return movie.budget > MIN_BUDGET
        && movie.revenue >= MIN_REVENUE
        && !movie.genres.is_empty()
        && !movie.credits.cast.is_empty()
        && !movie.credits.crew.is_empty()
        && movie.similar.total_results > 0
        && movie.recommendations.total_results > 0;
}

// Construct url for request movie with given id and api key
fn make_movie_url(api_key: &String, id: usize) -> String {
    return format!(
        "https://api.themoviedb.org/3/movie/{}\
        ?api_key={}&language=en-US&append_to_response=\
        credits%2Ckeywords%2Csimilar%2Crecommendations",
        id, api_key
    );
}

// Construct url for request movie with given id and api key
fn make_actor_url(api_key: &String, id: usize) -> String {
    return format!(
        "https://api.themoviedb.org/3/person/{}\
        ?api_key={}&language=en-US&append_to_response=movie_credits",
        id, api_key
    );
}

// Extract each id from the daily export file from TMDb API
// and return an ids vector
fn make_ids(input_file: &String) -> Vec<usize> {
    let file = File::open(input_file).unwrap();
    let reader = BufReader::new(file);
    let mut all_ids = vec![];
    for line in reader.lines() {
        let movie: IdObject = serde_json::from_str(&line.unwrap()).unwrap();
        all_ids.push(movie.id);
    }
    return all_ids;
}

// Divide ids vector in multiple sub vectors, one for each thread
// Jump from multiple of threads to another to take current id
fn make_thread_ids(machines: usize, machine_id: usize, all_ids: &Vec<usize>) -> Vec<usize> {
    let mut thread_ids = vec![];
    let mut count: usize = machine_id;
    for (i, id) in all_ids.iter().enumerate() {
        if i == count {
            thread_ids.push(id.clone());
            count = count + machines;
        }
    }
    return thread_ids;
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Start timer
    let now = Instant::now();

    // Args management
    let args: Vec<String> = env::args().collect();
    if args.len() < 6 {
        println!("Wrong args");
        std::process::exit(42)
    }
    let api_key = &args[1];
    let input_file = &args[2];
    let movies_output_file = &args[3];
    let actor_ids_output_file = &args[4];
    let threads = &args[5].parse().unwrap();

    // Extract all ids from TMDb daily export file
    let ids = make_ids(input_file);

    // Threads and channel management
    let done = String::from("done");
    let (crawlers, writer) = channel();

    let handles = (0..*threads)
        .into_iter()
        .map(|i| {
            let api_key_clone = api_key.clone();
            let done_clone = done.clone();
            let crawler = crawlers.clone();
            // In each thread, make requests from own thread_ids
            let thread_ids = make_thread_ids(*threads, i, &ids);
            let handle = thread::spawn(move || {
                for id in thread_ids {
                    let response = reqwest::blocking::get(&make_movie_url(&api_key_clone, id));
                    match response {
                        Ok(data) => {
                            // If request succeed, check if movie's revenue and budget
                            // are greater than zero. In this case, send movie to writer.
                            if data.status().is_success() {
                                let movie_string = data.text().expect("fail to movie_string");
                                let movie: Result<Movie, serde_json::error::Error> =
                                    serde_json::from_str(&movie_string);
                                match movie {
                                    Ok(movie) => {
                                        if filter_movie(&movie) {
                                            crawler
                                                .send(movie_string)
                                                .expect("fail to send movie_string");
                                            movie
                                                .credits
                                                .cast
                                                .iter()
                                                .map(|a_id| a_id.id.to_string())
                                                .for_each(|a| {
                                                    crawler
                                                        .send(String::from("actor_id:") + &a)
                                                        .expect("fail to send a")
                                                });
                                        }
                                    }
                                    _ => (),
                                }
                            }
                        }
                        _ => (),
                    }
                }
                // When done, send "done" message
                crawler.send(done_clone).unwrap();
            });
            handle
        })
        .collect::<Vec<thread::JoinHandle<_>>>();

    // Join all threads
    for handle in handles {
        handle.join().unwrap()
    }

    // Write all movies responses in a file until all threads crawler finish
    let mut movies_output_file = File::create(movies_output_file).unwrap();
    let mut actor_ids_set = HashSet::new();
    let mut counter = 0;
    for message in writer {
        if message == done {
            counter = counter + 1;
        } else if message.starts_with("actor_id") {
            let id: String = message.split(":").collect::<Vec<_>>()[1].to_string();
            actor_ids_set.insert(id);
        } else {
            write!(movies_output_file, "{}\n", message).unwrap();
        }
        if &counter == threads {
            break;
        }
    }

    // Write all actor_ids retrieved
    let mut actor_ids_output_file = File::create(actor_ids_output_file).unwrap();
    for id in actor_ids_set {
        write!(actor_ids_output_file, "{}\n", id).unwrap();
    }

    println!("Done in {} seconds", now.elapsed().as_secs());
    Ok(())
}
