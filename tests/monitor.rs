#![allow(unused_imports)]

use std::{
  borrow::Cow,
  cell::{Cell, RefCell},
  collections::{BTreeMap, BTreeSet, HashMap, HashSet, VecDeque},
  io::{stderr, stdin, stdout, Cursor, Read, Write},
  rc::Rc,
  str,
  sync::Arc,
};

use anyhow::{anyhow, Context, Result};
use atty;
use csv;
use serde::{Deserialize, Serialize};
use serde_derive::{Deserialize, Serialize};
use serde_json;
use thiserror;

use dd_monitor::{monitor, MonitorConfig};

#[test]
/// Tests with no input.
fn test_monitor_nothing() -> Result<()> {
  let input = "";

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  let result = monitor(&mut source, &mut sink, &config);

  assert!(result.is_err(), "missing header");
  Ok(())
}

#[test]
#[ignore = "not implemented"]
fn test_monitor_one_request() -> Result<()> {
  let input = r#""remotehost","rfc931","authuser","date","request","status","bytes"
        "10.0.0.2","-","apache",1549573860,"GET /api/user HTTP/1.0",200,200"#;
  let expected = "";

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  monitor(&mut source, &mut sink, &config)?;

  let actual = sink.into_inner();
  let actual = str::from_utf8(&actual)?;
  assert_eq!(actual, expected);
  Ok(())
}

#[test]
#[ignore = "not implemented"]
fn test_monitor_sample_input() -> Result<()> {
  let input = &include_str!("../sample_input.csv")[..];
  let expected = "";

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  monitor(&mut source, &mut sink, &config)?;

  let actual = sink.into_inner();
  let actual = str::from_utf8(&actual)?;
  assert_eq!(actual, expected);
  Ok(())
}

#[test]
fn test_monitor_invalid_csv_input() -> Result<()> {
  let input = "1 2\n3 4\n5";

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  let result = monitor(&mut source, &mut sink, &config);

  assert!(result.is_err(), "invalid header");
  Ok(())
}

#[test]
fn test_monitor_invalid_csv_input_2() -> Result<()> {
  let input = r#"241"#;

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  let result = monitor(&mut source, &mut sink, &config);

  assert!(result.is_err(), "invalid header");
  Ok(())
}
#[test]
fn test_monitor_invalid_csv_input_3() -> Result<()> {
  let input = r#"241
        123
        456"#;

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  let result = monitor(&mut source, &mut sink, &config);

  assert!(result.is_err(), "this isn't csv it's just some numbers");
  Ok(())
}

#[test]
fn test_monitor_invalid_csv_input_4() -> Result<()> {
  let input = r#""remotehost","rfc931","authuser","date","request","status"
        "10.0.0.2","-","apache",1549573860,"GET /api/user HTTP/1.0",200
        "10.0.0.4","-","apache",1549573860,"GET /api/user HTTP/1.0",200";"#;

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  let result = monitor(&mut source, &mut sink, &config);

  assert!(result.is_err(), "size column missing");
  Ok(())
}

#[test]
fn test_monitor_invalid_csv_input_extra_column() -> Result<()> {
  let input = r#""remotehost","rfc931","authuser","date","request","status","bytes"
        "10.0.0.1","-","apache",1549574332,"GET /api/user HTTP/1.0",200,1234
        "10.0.0.4","-","apache",1549574333,"GET /report HTTP/1.0",200,1136,10101,13513
        "10.0.0.1","-","apache",1549574334,"GET /api/user HTTP/1.0",200,1194
        "10.0.0.4","-","apache",1549574334,"POST /report HTTP/1.0",404,1307"#;

  let mut source = Cursor::new(input);
  let mut sink = Cursor::new(Vec::new());
  let config = MonitorConfig::default();

  let result = monitor(&mut source, &mut sink, &config);

  assert!(result.is_err(), "extra column in record two");
  Ok(())
}