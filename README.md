# Energy Meter Dashboard

[![Docker Image CI](https://github.com/daisaja/energymeterdashboard/actions/workflows/docker.yml/badge.svg)](https://github.com/daisaja/energymeterdashboard/actions/workflows/docker.yml)
[![CodeQL](https://github.com/daisaja/energymeterdashboard/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/daisaja/energymeterdashboard/actions/workflows/codeql-analysis.yml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=daisaja_energymeterdashboard&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=daisaja_energymeterdashboard)
[![Coverage](https://sonarcloud.io/api/project_badges/measure?project=daisaja_energymeterdashboard&metric=coverage)](https://sonarcloud.io/summary/new_code?id=daisaja_energymeterdashboard)
[![Maintainability Rating](https://sonarcloud.io/api/project_badges/measure?project=daisaja_energymeterdashboard&metric=sqale_rating)](https://sonarcloud.io/summary/new_code?id=daisaja_energymeterdashboard)

Check out http://smashing.github.io/smashing for more information.

## Docker

Run docker with:

```bash
docker run -p3030:3030 --env-file .env daisaja/energymeter:latest
```

Build and push:

```bash
docker build -t daisaja/energymeter:latest .
docker push daisaja/energymeter:latest
```

SMA firmware: 2.13.33.R / 3.10.10.R

# Copy ssd image

sudo fdisk -l

sudo mount | grep sdc
sudo umount /dev/sdc1

~/Downloads/volkszaehler_latest$ sudo dd if=./2019-07-07-volkszaehler_raspian_buster.img | pv -s 8G | sudo dd of=/dev/sdc bs=1M


## Architecture

### System Context

```mermaid
C4Context
  title System Context – Energy Meter Dashboard

  Person(user, "Homeowner", "Monitors energy consumption\nand solar production at home")

  System(dashboard, "Energy Meter Dashboard", "Smashing-based web dashboard\nrunning in Docker on a Synology DiskStation")

  System_Ext(vzlogger, "Volkszähler / vzlogger", "Reads grid meter (E320)\nvia SML optical interface")
  System_Ext(opendtu, "OpenDTU", "Reads Hoymiles solar inverter\nvia radio protocol")
  System_Ext(openmeteo, "Open-Meteo API", "Public weather forecast API\n(DWD data, no key required)")
  System_Ext(influxdb, "InfluxDB", "Time-series database\nfor long-term storage")

  Rel(user, dashboard, "Views", "Browser / HTTP 3030")
  Rel(dashboard, vzlogger, "Polls every 3s", "HTTP 8081")
  Rel(dashboard, opendtu, "Polls every 3s", "HTTP 80")
  Rel(dashboard, openmeteo, "Polls every 10min", "HTTPS")
  Rel(dashboard, influxdb, "Exports metrics", "HTTP 8086")
```

### Container Diagram

```mermaid
C4Container
  title Container Diagram – Energy Meter Dashboard

  Person(user, "Homeowner")

  Container_Boundary(synology, "Docker on Synology DiskStation") {
    Container(smashing, "Smashing Dashboard", "Ruby / Smashing framework", "Serves the web UI and runs scheduled background jobs")
    ContainerDb(statefile, "state.json", "JSON file on /data volume", "Persists daily/monthly consumption baselines across restarts")
  }

  System_Ext(vzlogger, "vzlogger on Raspberry Pi", "HTTP API :8081\nGrid meter readings (SML)")
  System_Ext(opendtu, "OpenDTU", "HTTP API :80\nSolar inverter live data")
  System_Ext(openmeteo, "Open-Meteo", "HTTPS\nWeather forecast")
  System_Ext(influxdb, "InfluxDB", "HTTP :8086\nTime-series storage")

  Rel(user, smashing, "Views dashboard", "HTTP :3030")
  Rel(smashing, vzlogger, "GridMeterClient – polls supply/feed totals & current power", "HTTP")
  Rel(smashing, opendtu, "OpenDTUMeterClient – polls PV power, daily & total yield", "HTTP")
  Rel(smashing, openmeteo, "WeatherClient – polls temperature & forecast", "HTTPS")
  Rel(smashing, influxdb, "InfluxExporter – writes measurements", "HTTP")
  Rel(smashing, statefile, "StateManager – reads/writes baselines", "File I/O")
```
