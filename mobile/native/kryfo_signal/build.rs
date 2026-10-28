// SPDX-License-Identifier: GPL-3.0-or-later
// the libsignal and spqr sources Cargo.lock names, built into the library
// so a build can say what it was made from (ks_build_info)

use std::{env, fs, path::Path};

fn source_of(lock: &str, name: &str) -> String {
    let mut found = Vec::new();
    for pkg in lock.split("[[package]]") {
        let mut lines = pkg.lines().map(str::trim);
        if lines.clone().any(|l| l == format!("name = \"{name}\"")) {
            if let Some(src) = lines.find_map(|l| l.strip_prefix("source = \"")) {
                found.push(src.trim_end_matches('"').to_string());
            }
        }
    }
    match found.as_slice() {
        [one] => one.clone(),
        _ => panic!("Cargo.lock names {name} {} times", found.len()),
    }
}

fn main() {
    println!("cargo:rerun-if-changed=Cargo.lock");
    let lock = fs::read_to_string("Cargo.lock").expect("Cargo.lock");
    let out = Path::new(&env::var("OUT_DIR").expect("OUT_DIR")).join("build_info.rs");
    fs::write(
        out,
        format!(
            "pub const LIBSIGNAL: &str = {:?};\npub const SPQR: &str = {:?};\n",
            source_of(&lock, "libsignal-protocol"),
            source_of(&lock, "spqr"),
        ),
    )
    .expect("build_info.rs");
}
