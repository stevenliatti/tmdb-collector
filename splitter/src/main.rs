// TMDb movies splitter
// Steven Liatti & Jeremy Favre

use std::env;
use std::fs::read_to_string;
use std::fs::File;
use std::io::Write;

fn main() -> std::io::Result<()>{
    let args: Vec<String> = env::args().collect();
    if args.len() < 5 {
        println!("Wrong args");
        std::process::exit(42)
    }
    let input_file = &args[1];
    let output_file = &args[2];
    let machines: usize = args[3].parse().unwrap();
    let machine_id: usize = args[4].parse().unwrap();

    // Select only ids on lines of multiple of machine_id
    // and push it in a vector
    let str_file = read_to_string(input_file)?;
    let mut count: usize = machine_id;
    let mut this_lines = vec![];
    for (i, line) in str_file.lines().enumerate() {
        if i == count {
            this_lines.push(line);
            count = count + machines;
        }
    }

    // Then write it in a subfile
    let mut output = File::create(output_file)?;
    for line in this_lines {
        write!(output, "{}\n", line)?;
    }

    Ok(())
}
