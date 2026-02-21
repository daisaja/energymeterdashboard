# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ruby/Smashing dashboard for monitoring home energy consumption:
- **Grid meter** via Volkszähler (vzlogger) - power consumption/feed-in
- **Solar inverter** via OpenDTU - PV production
- **Heating meter** - heating consumption
- **Weather** via Open-Meteo API (DWD data, no API key required)
- **InfluxDB** for data export/storage
- **Tibber GraphQL API** for energy pricing

## Commands

```bash
# Run tests
bundle exec ruby -r simplecov -Itest test/unit_test.rb

# Build Docker image
docker build -t daisaja/energymeter:latest .

# Run locally
docker run -p 3030:3030 --env-file .env daisaja/energymeter:latest

# Install dependencies
bundle install
```

## Architecture

### Smashing Framework
- `dashboards/` - ERB templates (power.erb, overview.erb, ops.erb, p2.erb)
- `widgets/` - UI components (CoffeeScript, HTML, SCSS)
- `jobs/` - Scheduled background tasks pushing data to widgets

### Data Flow
1. **Jobs** run on SCHEDULER intervals (e.g., every 3s, 10m)
2. Jobs fetch data via **meter clients** (`jobs/meter_helper/`)
3. Jobs call `send_event('widget_id', { data })` to update dashboards

### Meter Clients (`jobs/meter_helper/`)
- `grid_meter_client.rb` - Volkszähler API (port 8081)
- `heating_meter_client.rb` - Heating consumption
- `solar_meter_client.rb` - SMA inverter (Firmware 2.13.33.R / 3.10.10.R)
- `opendtu_meter_client.rb` - OpenDTU API (`/api/livedata/status`)

### Required Environment Variables
- `GRID_METER_HOST` - Volkszähler host IP
- `OPENDTU_HOST` - OpenDTU inverter host IP

## Testing

Minitest with WebMock for HTTP stubbing:

```ruby
stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
  .to_return(status: 200, body: response.to_json)
```

## Code Patterns

- Use HTTParty for HTTP requests
- Wrap external API calls in begin/rescue with fallback values (see `jobs/weather.rb` pattern)
- Use `@@last_values` class variable pattern for caching last successful API response

## Git Workflow

After creating and merging a PR, always:
1. `git checkout master`
2. `git pull`
3. `git branch -d <feature-branch>` (delete the local feature branch)
