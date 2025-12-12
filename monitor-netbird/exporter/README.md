# NetBird Events Exporter

This directory contains the **NetBird events exporter**, a small service that
integrates NetBird management events into the `monitor-netbird` observability
stack.

The exporter is intended to be operationally simple: it runs as a container,
reads new management events, and forwards them to Loki so that they can be
queried and visualised in Grafana alongside metrics from Prometheus.

---

## Purpose

In a self‑hosted NetBird deployment, the management service records events that
are useful for auditing and troubleshooting (for example, changes to peers or
policies). The exporter makes these events available in your logging backend by:

- Connecting to the existing NetBird management data volume (read‑only).
- Regularly polling for new events.
- Sending them to Loki as structured log entries.

All of this happens inside the monitoring Docker network; no external hosts or
credentials are referenced here.

---

## How it is run

You normally do **not** run this component directly. It is started through the
`monitor-netbird/docker-compose.yaml` file as part of the monitoring stack.

Typical lifecycle:

1. Bring up or verify your NetBird control plane.
2. From the `monitor-netbird/` directory, build the exporter image:

   ```bash
   docker compose build netbird-events-exporter
   ```

3. Start or restart the monitoring stack:

   ```bash
   docker compose up -d
   ```

4. Confirm that the exporter container is in the `Up` state:

   ```bash
   docker compose ps
   ```

Once running, the exporter should not require manual interaction.

---

## Configuration (operator view)

Configuration is supplied via environment variables in `docker-compose.yaml`.
At a high level you can control:

- **Where to find the NetBird management data** (path inside the container).
- **Which Loki endpoint to send events to** (the internal Loki service URL).
- **How frequently to poll for new events** and **how many to send per batch**.

These settings are deliberately kept minimal so that operators only need to
adjust them when moving between environments.

---

## Using the data in Grafana

After the monitoring stack is running and Loki is configured as a data source in
Grafana, you can:

- Explore NetBird‑related logs using the Loki data source.
- Build dashboards that combine NetBird events with infrastructure metrics.
- Create alerts around specific categories of NetBird activity.

The exact query patterns and dashboards are left to the operator so they can be
adapted to local policies and requirements.
