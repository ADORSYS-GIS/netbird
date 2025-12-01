use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use reqwest::Client;
use rusqlite::params;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::env;
use std::time::Duration;
use tokio::time::sleep;
use tokio_rusqlite::Connection;
use tracing::{error, info, warn};

// Activity type constants from NetBird source code
// Source: https://github.com/netbirdio/netbird/blob/main/management/server/activity/codes.go
const ACTIVITY_TYPES: &[(i32, &str)] = &[
    (0, "peer_added_by_user"),
    (1, "peer_added_with_setup_key"),
    (2, "user_joined"),
    (3, "user_invited"),
    (4, "account_created"),
    (5, "peer_removed_by_user"),
    (6, "rule_added"),
    (7, "rule_updated"),
    (8, "rule_removed"),
    (9, "policy_added"),
    (10, "policy_updated"),
    (11, "policy_removed"),
    (12, "setup_key_created"),
    (13, "setup_key_updated"),
    (14, "setup_key_revoked"),
    (15, "setup_key_overused"),
    (16, "group_created"),
    (17, "group_updated"),
    (18, "group_added_to_peer"),
    (19, "group_removed_from_peer"),
    (20, "group_added_to_user"),
    (21, "group_removed_from_user"),
    (22, "user_role_updated"),
    (23, "group_added_to_setup_key"),
    (24, "group_removed_from_setup_key"),
    (25, "group_added_to_disabled_management_groups"),
    (26, "group_removed_from_disabled_management_groups"),
    (27, "route_created"),
    (28, "route_removed"),
    (29, "route_updated"),
    (30, "peer_ssh_enabled"),
    (31, "peer_ssh_disabled"),
    (32, "peer_renamed"),
    (33, "peer_login_expiration_enabled"),
    (34, "peer_login_expiration_disabled"),
    (35, "nameserver_group_created"),
    (36, "nameserver_group_deleted"),
    (37, "nameserver_group_updated"),
    (38, "account_peer_login_expiration_enabled"),
    (39, "account_peer_login_expiration_disabled"),
    (40, "account_peer_login_expiration_duration_updated"),
    (41, "personal_access_token_created"),
    (42, "personal_access_token_deleted"),
    (43, "service_user_created"),
    (44, "service_user_deleted"),
    (45, "user_blocked"),
    (46, "user_unblocked"),
    (47, "user_deleted"),
    (48, "group_deleted"),
    (49, "user_logged_in_peer"),
    (50, "peer_login_expired"),
    (51, "dashboard_login"),
    (52, "integration_created"),
    (53, "integration_updated"),
    (54, "integration_deleted"),
    (55, "account_peer_approval_enabled"),
    (56, "account_peer_approval_disabled"),
    (57, "peer_approved"),
    (58, "peer_approval_revoked"),
    (59, "transferred_owner_role"),
    (60, "posture_check_created"),
    (61, "posture_check_updated"),
    (62, "posture_check_deleted"),
    (63, "peer_inactivity_expiration_enabled"),
    (64, "peer_inactivity_expiration_disabled"),
    (65, "account_peer_inactivity_expiration_enabled"),
    (66, "account_peer_inactivity_expiration_disabled"),
    (67, "account_peer_inactivity_expiration_duration_updated"),
    (68, "setup_key_deleted"),
    (69, "user_group_propagation_enabled"),
    (70, "user_group_propagation_disabled"),
    (71, "account_routing_peer_dns_resolution_enabled"),
    (72, "account_routing_peer_dns_resolution_disabled"),
    (73, "network_created"),
    (74, "network_updated"),
    (75, "network_deleted"),
    (76, "network_resource_created"),
    (77, "network_resource_updated"),
    (78, "network_resource_deleted"),
    (79, "network_router_created"),
    (80, "network_router_updated"),
    (81, "network_router_deleted"),
    (82, "resource_added_to_group"),
    (83, "resource_removed_from_group"),
    (84, "account_dns_domain_updated"),
    (85, "account_lazy_connection_enabled"),
    (86, "account_lazy_connection_disabled"),
    (87, "account_network_range_updated"),
    (88, "peer_ip_updated"),
    (89, "user_approved"),
    (90, "user_rejected"),
    (99999, "account_deleted"),
];

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Event {
    id: i64,
    timestamp: String,
    activity: i32,
    initiator_id: Option<String>,
    target_id: Option<String>,
    account_id: Option<String>,
    meta: Option<String>,
}

#[derive(Debug, Serialize)]
struct LokiStream {
    stream: HashMap<String, String>,
    values: Vec<(String, String)>,
}

#[derive(Debug, Serialize)]
struct LokiPushRequest {
    streams: Vec<LokiStream>,
}

#[derive(Debug)]
struct Config {
    loki_url: String,
    db_path: String,
    check_interval: Duration,
    batch_size: i64,
}

impl Config {
    fn from_env() -> Self {
        Self {
            loki_url: env::var("LOKI_URL").unwrap_or_else(|_| "http://loki:3100".to_string()),
            db_path: env::var("EVENTS_DB_PATH")
                .unwrap_or_else(|_| "/netbird-data/events.db".to_string()),
            check_interval: Duration::from_secs(
                env::var("CHECK_INTERVAL")
                    .unwrap_or_else(|_| "10".to_string())
                    .parse()
                    .unwrap_or(10),
            ),
            batch_size: env::var("BATCH_SIZE")
                .unwrap_or_else(|_| "100".to_string())
                .parse()
                .unwrap_or(100),
        }
    }
}

fn get_activity_name(code: i32) -> String {
    ACTIVITY_TYPES
        .iter()
        .find(|(c, _)| *c == code)
        .map(|(_, name)| name.to_string())
        .unwrap_or_else(|| format!("unknown_{}", code))
}

fn timestamp_to_nanoseconds(timestamp: &str) -> String {
    DateTime::parse_from_rfc3339(timestamp)
        .or_else(|_| {
            let ts = timestamp.trim_end_matches('Z');
            DateTime::parse_from_rfc3339(&format!("{}+00:00", ts))
        })
        .map(|dt| (dt.timestamp_nanos_opt().unwrap_or(0)).to_string())
        .unwrap_or_else(|_| {
            warn!("Failed to parse timestamp: {}, using current time", timestamp);
            Utc::now().timestamp_nanos_opt().unwrap_or(0).to_string()
        })
}

async fn wait_for_loki(client: &Client, loki_url: &str) -> Result<()> {
    info!("Waiting for Loki to be ready...");
    let ready_url = format!("{}/ready", loki_url);
    
    for attempt in 1..=60 {
        match client.get(&ready_url).timeout(Duration::from_secs(2)).send().await {
            Ok(resp) if resp.status().is_success() => {
                info!("✓ Loki is ready");
                return Ok(());
            }
            _ => {
                if attempt % 10 == 0 {
                    info!("Still waiting for Loki... (attempt {}/60)", attempt);
                }
                sleep(Duration::from_secs(2)).await;
            }
        }
    }
    
    anyhow::bail!("Failed to connect to Loki after 60 attempts")
}

async fn get_initial_last_id(conn: &Connection, db_path: &str) -> Result<i64> {
    info!("Checking for database at: {}", db_path);
    
    let last_id = conn
        .call(|conn| {
            let mut stmt = conn.prepare("SELECT MAX(id) FROM events")?;
            let id: Option<i64> = stmt.query_row([], |row| row.get(0)).ok().flatten();
            Ok::<i64, rusqlite::Error>(id.unwrap_or(0))
        })
        .await?;
    
    info!("Starting from event ID: {}", last_id);
    Ok(last_id)
}

async fn read_events(conn: &Connection, last_id: i64, batch_size: i64) -> Result<Vec<Event>> {
    conn.call(move |conn| {
        let mut stmt = conn.prepare(
            "SELECT id, timestamp, activity, initiator_id, target_id, account_id, meta 
             FROM events 
             WHERE id > ?1 
             ORDER BY id ASC 
             LIMIT ?2",
        )?;
        
        let events = stmt
            .query_map(params![last_id, batch_size], |row| {
                Ok(Event {
                    id: row.get(0)?,
                    timestamp: row.get(1)?,
                    activity: row.get(2)?,
                    initiator_id: row.get(3)?,
                    target_id: row.get(4)?,
                    account_id: row.get(5)?,
                    meta: row.get(6)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        
        Ok::<Vec<Event>, rusqlite::Error>(events)
    })
    .await
    .context("Failed to read events from database")
}

async fn send_to_loki(client: &Client, loki_url: &str, events: Vec<Event>) -> Result<()> {
    if events.is_empty() {
        return Ok(());
    }
    
    let mut streams: HashMap<String, LokiStream> = HashMap::new();
    
    for event in &events {
        let activity_name = get_activity_name(event.activity);
        
        // Parse metadata if it exists for richer logging
        let meta_display = if let Some(meta_str) = &event.meta {
            match serde_json::from_str::<serde_json::Value>(meta_str) {
                Ok(meta_json) => format!("{}", serde_json::to_string_pretty(&meta_json).unwrap_or_else(|_| meta_str.clone())),
                Err(_) => meta_str.clone(),
            }
        } else {
            "N/A".to_string()
        };
        
        // Log detailed event information to stdout/stderr for visibility
        info!(
            "╔════════════════════════════════════════════════════════════════\n\
             ║ EVENT ID: {} | Activity: {} ({})\n\
             ║ Timestamp: {}\n\
             ║ Initiator: {}\n\
             ║ Target: {}\n\
             ║ Account: {}\n\
             ║ Metadata:\n\
             ║ {}\n\
             ╚════════════════════════════════════════════════════════════════",
            event.id,
            activity_name,
            event.activity,
            event.timestamp,
            event.initiator_id.as_deref().unwrap_or("N/A"),
            event.target_id.as_deref().unwrap_or("N/A"),
            event.account_id.as_deref().unwrap_or("N/A"),
            meta_display.lines().map(|l| format!("║ {}", l)).collect::<Vec<_>>().join("\n")
        );
        
        let mut labels = HashMap::new();
        labels.insert("job".to_string(), "netbird-events".to_string());
        labels.insert(
            "account_id".to_string(),
            event.account_id.clone().unwrap_or_else(|| "unknown".to_string()),
        );
        labels.insert("activity".to_string(), activity_name.clone());
        labels.insert("activity_code".to_string(), event.activity.to_string());
        
        let label_key = format!(
            "{{{}}}",
            labels
                .iter()
                .map(|(k, v)| format!("{}=\"{}\"", k, v))
                .collect::<Vec<_>>()
                .join(",")
        );
        
        let log_data = serde_json::json!({
            "event_id": event.id,
            "timestamp": event.timestamp,
            "activity": activity_name,
            "activity_code": event.activity,
            "initiator_id": event.initiator_id.as_deref().unwrap_or(""),
            "target_id": event.target_id.as_deref().unwrap_or(""),
            "account_id": event.account_id.as_deref().unwrap_or(""),
            "meta": event.meta.as_deref().unwrap_or(""),
        });
        
        let ts_ns = timestamp_to_nanoseconds(&event.timestamp);
        let log_line = serde_json::to_string(&log_data)?;
        
        streams
            .entry(label_key)
            .or_insert_with(|| LokiStream {
                stream: labels.clone(),
                values: Vec::new(),
            })
            .values
            .push((ts_ns, log_line));
    }
    
    let request = LokiPushRequest {
        streams: streams.into_values().collect(),
    };
    
    let push_url = format!("{}/loki/api/v1/push", loki_url);
    let response = client
        .post(&push_url)
        .json(&request)
        .timeout(Duration::from_secs(10))
        .send()
        .await?;
    
    if response.status().is_success() {
        info!("✓ Sent {} events to Loki", events.len());
        Ok(())
    } else {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        anyhow::bail!("Failed to send to Loki: {} - {}", status, body)
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            env::var("RUST_LOG").unwrap_or_else(|_| "info".to_string()),
        )
        .init();
    
    let config = Config::from_env();
    
    info!("========================================");
    info!("NetBird Events Exporter (Rust)");
    info!("========================================");
    info!("Loki URL: {}", config.loki_url);
    info!("Events DB: {}", config.db_path);
    info!("Check interval: {:?}", config.check_interval);
    info!("Batch size: {}", config.batch_size);
    info!("========================================");
    
    let client = Client::builder()
        .timeout(Duration::from_secs(30))
        .build()?;
    
    wait_for_loki(&client, &config.loki_url).await?;
    
    let conn = Connection::open(&config.db_path)
        .await
        .context("Failed to open database")?;
    
    let mut last_id = get_initial_last_id(&conn, &config.db_path).await?;
    let mut consecutive_errors = 0;
    const MAX_CONSECUTIVE_ERRORS: u32 = 10;
    
    info!("Started monitoring (checking every {:?})", config.check_interval);
    
    loop {
        match read_events(&conn, last_id, config.batch_size).await {
            Ok(events) => {
                if !events.is_empty() {
                    let new_last_id = events.iter().map(|e| e.id).max().unwrap_or(last_id);
                    info!("Found {} new events (last ID: {})", events.len(), new_last_id);
                    
                    match send_to_loki(&client, &config.loki_url, events).await {
                        Ok(_) => {
                            last_id = new_last_id;
                            consecutive_errors = 0;
                        }
                        Err(e) => {
                            error!("Failed to send to Loki: {}", e);
                            consecutive_errors += 1;
                        }
                    }
                }
            }
            Err(e) => {
                error!("Failed to read events: {}", e);
                consecutive_errors += 1;
            }
        }
        
        if consecutive_errors >= MAX_CONSECUTIVE_ERRORS {
            error!(
                "Too many consecutive errors ({}), waiting 30s before retry...",
                consecutive_errors
            );
            sleep(Duration::from_secs(30)).await;
            consecutive_errors = 0;
        }
        
        sleep(config.check_interval).await;
    }
}
