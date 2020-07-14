use std::{collections::HashMap, convert::TryInto, fmt::Debug, ops::Range, rc::Rc};

use chrono::NaiveDateTime;
use itertools::Itertools;

use crate::{Config, Monitor, RequestRecord};

#[derive(Debug, Clone)]
pub struct ChunkedStatsMonitor {
    /// The number of seconds of requests to include in each stats chunk.
    chunk_seconds: u32,

    /// Requests that are in the chunk currently being aggregated.
    requests: Vec<Rc<RequestRecord>>,
    /// The range of timestamps included in the pending chunk.
    /// Will be None if we haven't had any chunks yet, so we
    /// don't have any timestamp.
    requests_time_range: Option<Range<u32>>,

    /// Request counts for the current chunk.
    request_count: u64,
    requests_by_status_code: HashMap<u16, u64>,
    requests_by_section: HashMap<String, u64>,
}

impl ChunkedStatsMonitor {
    fn maybe_flush_before(&mut self, record: &RequestRecord) -> anyhow::Result<Vec<String>> {
        // If this is the first record we're seeing, use it for the starting time
        // of the first chunk.
        let mut requests_time_range = self
            .requests_time_range
            .clone()
            .unwrap_or_else(|| record.date..(record.date + self.chunk_seconds));

        let mut output = Vec::new();
        while !requests_time_range.contains(&record.date) {
            output.append(&mut self.pending()?);

            if !self.requests.is_empty() {
                self.requests.clear();
                self.request_count = 0;
                self.requests_by_status_code.clear();
                self.requests_by_section.clear();
            }

            requests_time_range =
                requests_time_range.end..(requests_time_range.end + self.chunk_seconds);
        }

        self.requests_time_range = Some(requests_time_range);

        Ok(output)
    }
}

impl Monitor for ChunkedStatsMonitor {
    fn from_config(config: &Config) -> Self {
        Self {
            chunk_seconds: config.stats_window,
            requests: Vec::new(),
            requests_time_range: None,
            request_count: 0,
            requests_by_status_code: HashMap::new(),
            requests_by_section: HashMap::new(),
        }
    }

    fn push(&mut self, record: &std::rc::Rc<RequestRecord>) -> anyhow::Result<Vec<String>> {
        let output = self.maybe_flush_before(record)?;

        self.requests.push(record.clone());
        self.request_count += 1;
        self.requests_by_status_code
            .entry(record.status)
            .and_modify(|n| *n += 1)
            .or_insert(1);
        self.requests_by_section
            .entry(String::from("/") + record.section())
            .and_modify(|n| *n += 1)
            .or_insert(1);

        Ok(output)
    }

    fn pending(&mut self) -> anyhow::Result<Vec<String>> {
        if self.requests_time_range.is_none() {
            return Ok(Vec::new());
        }

        let range = self.requests_time_range.as_ref().unwrap();

        let start = NaiveDateTime::from_timestamp(range.start.try_into().unwrap(), 0);
        let end = NaiveDateTime::from_timestamp(range.end.try_into().unwrap(), 0).time();

        let rate = self.request_count as f64 / self.chunk_seconds as f64;

        let top_status_codes = self
            .requests_by_status_code
            .iter()
            .map(|(code, count)| (count, code))
            .sorted()
            .rev()
            .take(3)
            .map(|(count, code)| format!("{:3}% {:03}", 100 * count / self.request_count, code))
            .join(", ");

        let top_sections = self
            .requests_by_section
            .iter()
            .map(|(section, count)| (count, section))
            .sorted()
            .rev()
            .take(1)
            .map(|(count, section)| {
                format!("{:3}% in {:<11}", 100 * count / self.request_count, section)
            })
            .join(", ");

        if self.request_count > 0 {
            Ok(vec![format!(
                "{}-{}  |  {:4} requests at {:5.1}rps  |  {}  |  {}",
                start, end, self.request_count, rate, top_sections, top_status_codes
            )])
        } else {
            Ok(vec![format!("{}-{}  |  no requests", start, end,)])
        }
    }
}
