# Grafana Alloy Tutorial: Complete Telemetry Setup Guide

## Table of Contents
1. [Why Use Grafana Alloy?](#why-use-grafana-alloy)
2. [Prerequisites](#prerequisites)
3. [Understanding the Architecture](#understanding-the-architecture)
4. [Tutorial: Setting Up Alloy with a Rust Application](#tutorial-setting-up-alloy-with-a-rust-application)
5. [Step-by-Step Deployment](#step-by-step-deployment)
6. [Verification and Testing](#verification-and-testing)
7. [Troubleshooting](#troubleshooting)
8. [Production Considerations](#production-considerations)

## Why Use Grafana Alloy?

Grafana Alloy is a unified telemetry collector that revolutionizes how you gather observability data. Unlike traditional Prometheus that uses a pull model, Alloy acts as a central collector that provides:

### Key Benefits
- **Unified Collection**: Single agent for logs, metrics, and traces
- **Flexible Sources**: Collect from Docker containers, files, and applications directly
- **Protocol Support**: OTLP, Jaeger, Prometheus, and more
- **Simplified Architecture**: Reduce the number of monitoring components in your stack
- **Cloud-Native**: Designed for containerized environments

### What Alloy Can Do For Your Applications
- **Log Collection**: Actively scrape logs from Docker containers and log files
- **Trace Scraping**: Collect traces from applications using OpenTelemetry and other protocols
- **Data Transformation**: Process and enrich telemetry data before storage

## Prerequisites

Before starting this tutorial, ensure you have:

### Required Infrastructure
1. **Docker & Docker Compose** (v1.20+)
   ```bash
   docker --version
   docker-compose --version
   ```

2. **LGTM Stack** (Loki, Grafana, Tempo, Mimir)
   - Loki for log storage
   - Tempo for trace storage  
   - Grafana for visualization
   - Mimir or Prometheus for metrics (optional)


### Application Requirements
Your application should:
- Output structured logs (JSON format recommended)
- Support OpenTelemetry for tracing (optional but recommended)
- Run in Docker containers or have accessible log files

### Knowledge Prerequisites
- Basic understanding of Docker and containerization
- Basic knowledge of Grafana and observability stacks

## Understanding the Architecture

### Data Flow Overview
```
Application → Alloy → LGTM Stack 
```

### Components
1. **Alloy Collector**: Central telemetry collection agent
2. **Loki**: Log aggregation and storage
3. **Tempo**: Distributed tracing storage
4. **Grafana**: Visualization and analysis dashboard

### Collection Methods
- **Docker Logs**: Direct scraping from container stdout/stderr
- **File Logs**: Reading from application log files
- **OTLP Traces**: OpenTelemetry protocol scraping for distributed tracing
- **Jaeger Traces**: Legacy Jaeger protocol scraping support

## Tutorial: Building a Rust Application with Alloy Telemetry

Great! Let's build a complete Rust application from scratch that generates logs and traces, then use Alloy to scrape this data and push it to our LGTM stack.

### Step 1: Create Our Rust Calculator Application

We're going to build a simple but powerful calculator service that demonstrates structured logging and tracing. This will give Alloy real data to scrape!

#### 1.1 Project Setup

First, let's create our simple Rust project:

```bash
# Create new Rust project
cargo new calculator-app
cd calculator-app

# Add minimal dependencies to Cargo.toml
cat >> Cargo.toml << 'EOF'
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["json", "env-filter"] }
tracing-appender = "0.2"
uuid = { version = "1.0", features = ["v4"] }
EOF
```

#### 1.2 Build a Simple Calculator Service

Now let's create a simple application that focuses only on logging and tracing:

```rust
use tracing::{error, info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};
use tracing_appender::non_blocking::WorkerGuard;
use opentelemetry_sdk::{trace as sdktrace, Resource, runtime};
use opentelemetry::KeyValue;
use opentelemetry_otlp::WithExportConfig;
use uuid::Uuid;
use tokio::time::{sleep, Duration};

// Simple calculator function with structured logging and tracing
#[tracing::instrument]
fn calculate(operation: &str, a: f64, b: f64) -> Result<f64, String> {
    let request_id = Uuid::new_v4().to_string();
    
    // Create a span for the calculation operation
    let span = tracing::info_span!(
        "calculate",
        request_id = %request_id,
        operation = %operation,
        a = %a,
        b = %b
    );
    let _enter = span.enter();
    
    // Log the calculation request
    info!("Starting calculation");

    let result = match operation {
        "add" => {
            tracing::info!("Performing addition");
            a + b
        }
        "subtract" => {
            tracing::info!("Performing subtraction");
            a - b
        }
        "multiply" => {
            tracing::info!("Performing multiplication");
            a * b
        }
        "divide" => {
            if b == 0.0 {
                error!(
                    operation = %operation,
                    a = %a,
                    b = %b,
                    "Division by zero error"
                );
                return Err("Division by zero".to_string());
            }
            tracing::info!("Performing division");
            a / b
        }
        _ => {
            warn!(
                operation = %operation,
                "Unknown operation requested"
            );
            return Err(format!("Unknown operation: {}", operation));
        }
    };

    // Log successful result
    info!(
        result = %result,
        "Calculation completed successfully"
    );
    
    Ok(result)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize OpenTelemetry tracer
    let tracer = opentelemetry_otlp::new_pipeline()
        .tracing()
        .with_exporter(
            opentelemetry_otlp::new_exporter()
                .tonic()
                .with_endpoint("http://<alloy_domain>:4317"),
        )
        .with_trace_config(sdktrace::config()
            .with_resource(Resource::new(vec![
                KeyValue::new("service.name", "calculator-app"),
                KeyValue::new("service.version", "0.1.0"),
                KeyValue::new("service.instance.id", uuid::Uuid::new_v4().to_string()),
            ])))
        .install_batch(runtime::Tokio)?;

    // Initialize structured logging with JSON output to files
    let file_appender = tracing_appender::rolling::daily("/var/log/calculator-app", "calculator");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    tracing_subscriber::registry()
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "calculator_app=info".into()),
        )
        .with(tracing_subscriber::fmt::layer().json().with_writer(non_blocking))
        .with(tracing_subscriber::fmt::layer().json()) // Also output to console
        .with(tracing_opentelemetry::layer().with_tracer(tracer))
        .init();

    info!("Starting Simple Calculator Application");

    // Run some example calculations to generate logs and traces
    let operations = vec![
        ("add", 10.0, 5.0),
        ("subtract", 20.0, 8.0),
        ("multiply", 6.0, 7.0),
        ("divide", 15.0, 3.0),
        ("divide", 10.0, 0.0), // This will generate an error
        ("unknown", 1.0, 2.0), // This will generate a warning
    ];

    for (op, a, b) in operations {
        match calculate(op, a, b) {
            Ok(result) => {
                println!("{} {} {} = {}", a, op, b, result);
                tracing::info!("Calculation result: {} {} {} = {}", a, op, b, result);
            }
            Err(e) => {
                println!("Error: {}", e);
                tracing::error!("Calculation failed: {}", e);
            }
        }
        
        // Add a small delay between operations
        sleep(Duration::from_millis(100)).await;
    }

    info!("Calculator application finished");
    
    // Give some time for traces to be sent
    sleep(Duration::from_secs(2)).await;
    
    Ok(())
}

```


**Example log output:**
```json
{
  "timestamp": "2025-12-11T12:00:00.000Z",
  "level": "info",
  "target": "calculator_app",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "operation": "add",
  "a": 10.5,
  "b": 5.3,
  "message": "Processing calculation request"
}
```

#### 1.4 Create Simple Dockerfile

```dockerfile
# Simple Dockerfile for our calculator app
FROM rust:1.81 as builder

WORKDIR /app

# Copy source code
COPY Cargo.toml ./
COPY src ./src

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app user and log directory
RUN useradd -r -s /bin/false appuser && \
    mkdir -p /var/log/calculator-app && \
    chown -R appuser:appuser /var/log/calculator-app

WORKDIR /app

# Copy the binary
COPY --from=builder /app/target/release/calculator-app /app/calculator-app
RUN chown appuser:appuser /app/calculator-app

USER appuser

CMD ["./calculator-app"]
```

Now we have an application that produces perfect telemetry data for Alloy to scrape!

### Step 2: Create Docker Compose Configuration

Create a `docker-compose.yml` that includes both your application and Alloy:

```yaml
version: '3.8'

services:
  # Your Simple Calculator Application
  calculator-app:
    build: ./calculator-app
    container_name: calculator-app
    volumes:
      - calculator-logs:/var/log/calculator-app
    restart: unless-stopped
    environment:
      - RUST_LOG=info

  # Alloy Collector
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    command:
      - run
      - /etc/alloy/config.alloy
      - --server.http.listen-addr=0.0.0.0:12345
      - --storage.path=/var/lib/alloy/data
    ports:
      - "12345:12345"  # Alloy UI/metrics
      - "4317:4317"    # OTLP gRPC (traces)
      - "4318:4318"    # OTLP HTTP (traces)
      - "14268:14268"  # Jaeger HTTP (traces)
    volumes:
      - ./config.alloy:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - calculator-logs:/var/log/calculator-app:ro
      - alloy-data:/var/lib/alloy/data
    restart: unless-stopped
    environment:
      - LOKI_ENDPOINT=https://loki.<YOUR_DOMAIN>/loki/api/v1/push
      - TEMPO_ENDPOINT=https://tempo.<YOUR_DOMAIN>:4317
    depends_on:
      - calculator-app

volumes:
  calculator-logs:
  alloy-data:
```

### Step 3: Configure Alloy for Your Application

Create a `config.alloy` file tailored to collect logs from your calculator app:

```alloy
logging {
  level  = "info"
  format = "logfmt"
}

// Loki - Log Collection and Forwarding
loki.write "loki" {
  endpoint {
    url = "https://<LOKI_DOMAIN>/loki/api/v1/push"
  }
}

// Collect Docker container logs
loki.source.docker "containers" {
  host = "unix:///var/run/docker.sock"
  refresh_interval = "5s"
  targets = [
    {
      __path__ = "/var/lib/docker/containers/*/*.log",
      job = "docker",
    },
  ]
  forward_to = [loki.write.loki.receiver]
}

// Collect application logs from files
loki.source.file "app_logs" {
  targets = [
    {__path__ = "/var/log/calculator-app/calculator.2025-12-11", job = "calculator-app"},
  ]
  forward_to = [loki.write.loki.receiver]
}

// Tempo - Trace Collection
otelcol.receiver.otlp "default" {
  grpc {
    endpoint = "0.0.0.0:4317"
  }
  http {
    endpoint = "0.0.0.0:4318"
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "https://<TEMPO_DOMAIN>/v1/traces"
  }
}

// Jaeger receiver (for legacy applications)
otelcol.receiver.jaeger "default" {
  protocols {
    thrift_http {
      endpoint = "0.0.0.0:14268"
    }
  }
  output {
    traces = [otelcol.exporter.otlp.tempo.input]
  }
}

```


#### 4.1 Log Collection Strategy
The config uses **dual collection** for maximum reliability:
- **Docker logs**: Captures stdout/stderr from containers
- **File logs**: Reads structured logs from application files

#### 4.2 Structured Log Parsing
The calculator app outputs JSON logs, so Alloy includes parsing:
```alloy
parsing {
  logfmt {
    mapping = {
      timestamp = "timestamp",
      level = "level", 
      message = "message",
      request_id = "request_id",
      operation = "operation",
      result = "result"
    }
  }
}
```

#### 4.3 Trace Scraping Configuration
Alloy is configured to scrape traces via multiple protocols:
- **OTLP gRPC** (port 4317): Modern OpenTelemetry protocol scraping
- **OTLP HTTP** (port 4318): HTTP-based OpenTelemetry scraping
- **Jaeger HTTP** (port 14268): Legacy Jaeger protocol scraping

## Step-by-Step Deployment

### Step 5: Deploy the Stack

Follow these commands to deploy your application with Alloy:

```bash
# 1. Create the working directory
mkdir ~/alloy-tutorial && cd ~/alloy-tutorial

# 2. Create the calculator application directory and files
#    - Copy the Rust code from Step 1.2 into calculator-app/src/main.rs
#    - Copy the Cargo.toml from Step 1.1 into calculator-app/Cargo.toml  
#    - Copy the Dockerfile from Step 1.4 into calculator-app/Dockerfile
mkdir calculator-app
# (Create the files manually or copy from the sections above)

# 3. Create the config.alloy file (copy from Step 3 above)
nano config.alloy

# 4. Create the docker-compose.yml file (copy from Step 2 above)  
nano docker-compose.yml

# 5. Build and start the stack
docker-compose up -d --build

# 6. Verify all services are running
docker-compose ps

# 7. Check the application logs
docker-compose logs calculator-app
```

Expected output:
```
NAME              COMMAND                  SERVICE             STATUS              PORTS
alloy             "/bin/alloy run /etc…"   alloy               running             0.0.0.0:12345->12345/tcp, 0.0.0.0:14268->14268/tcp, 0.0.0.0:4317->4317/tcp, 0.0.0.0:4318->4318/tcp
calculator-app    "./calculator-app"       calculator-app      running             0.0.0.0:3000->3000/tcp
```

### Step 6: Test the Application

Generate some activity to create logs and traces:

```bash
# Test the calculator API
curl -X POST http://localhost:3000/calculate \
  -H "Content-Type: application/json" \
  -d '{"operation": "add", "a": 10.5, "b": 5.3}'

# Test health endpoint
curl http://localhost:3000/health

# Generate some error logs
curl -X POST http://localhost:3000/calculate \
  -H "Content-Type: application/json" \
  -d '{"operation": "divide", "a": 10, "b": 0}'
```

### Step 7: Verify Alloy Configuration

```bash
# Check Alloy logs
docker-compose logs -f alloy

# Verify configuration syntax
docker exec alloy alloy tools check /etc/alloy/config.alloy

# Check Alloy metrics
curl http://localhost:12345/metrics | grep loki
curl http://localhost:12345/metrics | grep traces
```

## Verification and Testing

### Verify Logs in Grafana

1. **Access Grafana**: Navigate to your Grafana instance
2. **Select Loki Data Source**: Click the data source selector (top-left) and choose **Loki**
3. **Run Log Queries**:

```logql
# View all calculator-app logs
{job="calculator-app"}

# Filter by operation type
{job="calculator-app"} |= "add"

# Find error logs
{job="calculator-app"} level="error"

# Search by request ID
{job="calculator-app"} request_id="550e8400-e29b-41d4-a716-446655440000"

# View Docker container logs
{job="docker"} container_name="calculator-app"
```

**Note**: These queries are specifically designed for our calculator application. For more advanced LogQL queries and syntax, refer to the [official Grafana LogQL Documentation](https://grafana.com/docs/loki/latest/logql/).

### Verify Traces in Grafana

1. **Select Tempo Data Source**: In Grafana, choose **Tempo** from the data source selector
2. **Search for Traces**:
   - Use service name: `calculator-service`
   - Filter by operation: `calculate` or `health_check`
   - Search by tags: `http.method="POST"`, `http.status_code="200"`

**Note**: These trace search examples are based on our calculator application. For comprehensive TraceQL queries and advanced tracing features, refer to the [official Grafana Tempo Documentation](https://grafana.com/docs/tempo/latest/traceql/).

### Expected Log Examples

You should see structured logs like this in Grafana:

```json
{
  "timestamp": "2025-12-11T12:00:00.000Z",
  "level": "info",
  "target": "calculator_app",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "operation": "add",
  "a": 10.5,
  "b": 5.3,
  "result": 15.8,
  "message": "Calculation completed successfully"
}
```

### Metric Verification

Check that Alloy is receiving and forwarding data:

```bash
# Log collection metrics
curl -s http://localhost:12345/metrics | grep loki_received_total
# Expected: loki_received_total{job="calculator-app"} 42

# Trace scraping metrics  
curl -s http://localhost:12345/metrics | grep otelcol_receiver_accepted_total
# Expected: otelcol_receiver_accepted_total{receiver="otlp",component_type="receiver"} 0
```

## Troubleshooting

### Common Issues and Solutions

#### Alloy Not Starting
```bash
# Check configuration syntax
docker exec alloy alloy tools check /etc/alloy/config.alloy

# Common errors:
# - Invalid Alloy syntax
# - Missing volume mounts
# - Port conflicts
```

#### No Logs in Grafana/Loki
```bash
# Check if Alloy is receiving logs
curl http://localhost:12345/metrics | grep loki_received_total

# Verify log file paths
docker exec alloy ls -la /var/log/calculator-app/

# Check Loki endpoint connectivity
curl -v http://loki.local/loki/api/v1/push
```

#### No Traces in Grafana/Tempo
```bash
# Check trace scraping receiver status
curl http://localhost:12345/metrics | grep otelcol_receiver

# Test Tempo connectivity
curl -v http://tempo.local:3200/ready

# Verify application is configured for trace scraping
# (Check if your app has OpenTelemetry instrumentation and is exporting traces)
```

#### Permission Issues
```bash
# Check Docker socket access
docker exec alloy ls -la /var/run/docker.sock

# Verify log directory permissions
docker exec alloy ls -la /var/log/calculator-app/
```

### Debug Commands
```bash
# Real-time Alloy logs
docker compose logs -f alloy

# Check all services status
docker compose ps

# Test configuration
docker exec alloy alloy tools check /etc/alloy/config.alloy

# View Alloy internal metrics
curl http://localhost:12345/metrics | head -20
```


## Summary

This tutorial demonstrated how to:
- Set up Grafana Alloy for comprehensive telemetry scraping
- Configure log scraping from both Docker containers and application files
- Implement trace scraping with OpenTelemetry support
- Deploy a complete stack with your Rust calculator application
- Verify and troubleshoot the telemetry scraping pipeline
