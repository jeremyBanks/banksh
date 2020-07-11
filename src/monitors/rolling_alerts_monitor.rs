use std::{
  borrow::Cow,
  cell::{Cell, RefCell},
  collections::{BTreeMap, BTreeSet, HashMap, HashSet, VecDeque},
  fmt::{Debug, Display},
  io::{stderr, stdin, stdout, Cursor, Read, Write},
  rc::{Rc, Weak},
  str,
  sync::Arc,
};

use anyhow::{anyhow, Context};
use atty;
use csv;
use serde::{Deserialize, Serialize};
use serde_derive::{Deserialize, Serialize};
use serde_json;
use thiserror;

use super::models::RequestRecord;

pub struct RollingAlertsModel {
  /// Requests that are in the current alerting window.
  requests: VecDeque<Rc<RequestRecord>>,
}