# Monitoring Agents for Remote Hosts

This directory provides guidance and example configs for running monitoring
agents on Linux hosts that are reachable from the monitoring stack (for example,
over a VPN, overlay network, corporate network, or local LAN).

The goal is to collect metrics and logs from those hosts and send them to the
Kubernetes-based monitoring stack (Prometheus, Loki, Grafana, Mimir).

## 1. Node Exporter (host metrics)

### Install

1. Download the latest `node_exporter` tarball from the Prometheus releases page.
2. Install the binary to `/usr/local/bin/node_exporter`.
3. Create a systemd unit, e.g. `/etc/systemd/system/node-exporter.service`:

   ```ini
   [Unit]
   Description=Prometheus Node Exporter

   [Service]
   ExecStart=/usr/local/bin/node_exporter
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

4. Enable and start:

   ```bash
   systemctl daemon-reload
   systemctl enable --now node-exporter
   ```

Node Exporter listens on `:9100` by default.

### Prometheus configuration

In `kubernetes/configs/prometheus-values.yaml`, add the host's address (IP or
DNS name) to the `node-exporter` job, for example:

```yaml
- job_name: node-exporter
  static_configs:
    - targets: ['host1.example.com:9100']
      labels:
        instance: 'target-host-1'
```

## 2. Docker daemon metrics (alternative to cAdvisor)

On each Docker host you want to monitor:

1. Configure `dockerd` to expose metrics, e.g. in `/etc/docker/daemon.json`:

   ```json
   {
     "metrics-addr": "0.0.0.0:9323",
     "experimental": true
   }
   ```

2. Restart Docker (for example: `systemctl restart docker`).

3. Ensure that port `9323` is reachable from the Kubernetes node (for example,
   over your LAN, VPN, or overlay network).

4. Update the `docker-daemon` job in
   `kubernetes/configs/prometheus-values.yaml`, for example:

   ```yaml
   - job_name: docker-daemon
     static_configs:
       - targets: ['host1.example.com:9323']
         labels:
           instance: 'target-host-1'
   ```

## 3. Alloy (logs to Loki)

You can run Grafana Alloy directly on target hosts to collect system and Docker
logs and push them to Loki in the cluster.

1. Download the Alloy binary for your architecture.
2. Place a configuration file like `alloy-config.yaml` from this directory on
   the host (adapt endpoint URL as needed).
3. Run Alloy as a systemd service or container.

Example Loki endpoint when exposed via NodePort on a monitoring host:

- `http://<monitoring-host>:31100/loki/api/v1/push`

Make sure firewall rules and any network ACLs allow traffic from the host to the
Kubernetes node on port `31100`.

## 4. NetBird Events Exporter

The NetBird events exporter in `monitor-netbird/exporter/` can run on a host
that has access to the NetBird management database.

Typical steps:

1. Build the exporter container or binary as described in
   `monitor-netbird/exporter/README.md`.
2. Run it as a systemd service or Docker container on the NetBird management
   host.
3. Point it at the Loki endpoint in the cluster via the `LOKI_URL` environment
   variable, for example:

   ```bash
   export LOKI_URL=http://<monitoring-host>:31100
   ```

4. Verify that NetBird events appear in Loki (via Grafana's Loki datasource).

## 5. Verification

After configuring agents and Prometheus targets:

- In Prometheus UI, check **Status → Targets** to ensure `UP` status for
  node-exporter and docker-daemon jobs.
- In Grafana, use the Loki datasource to query logs from the Alloy pipelines and
  NetBird events exporter.
- Confirm that labels such as `instance`, `container`, `service`, and
  `compose_project` are present as expected.
