# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby/Smashing dashboard for monitoring home energy consumption. It integrates with:
- **Grid meter** via Volkszähler (vzlogger) for power consumption/feed-in data
- **Solar inverter** via OpenDTU for PV production
- **Heating meter** for heating consumption
- **InfluxDB** for data export/storage
- **Tibber GraphQL API** for energy pricing

## Commands

```bash
# Run tests
bundle exec ruby -r simplecov -Itest test/unit_test.rb

# Build Docker image
docker build -t daisaja/energymeter:latest .

# Run locally with Docker
docker run -p 3030:3030 --env-file .env daisaja/energymeter:latest

# Install dependencies
bundle install

# Precompile assets
rake precompile-assets
```

## Architecture

### Smashing Framework Structure
- `dashboards/` - ERB templates defining dashboard layouts (power.erb, overview.erb, ops.erb)
- `widgets/` - Reusable UI components (CoffeeScript, HTML, SCSS)
- `jobs/` - Scheduled background tasks that fetch data and push to widgets

### Data Flow
1. **Jobs** (in `jobs/`) run on SCHEDULER intervals (e.g., every 3s)
2. Jobs fetch data from external sources via **meter clients** (in `jobs/meter_helper/`)
3. Jobs call `send_event('widget_id', { data })` to push updates to dashboards

### Meter Clients
Located in `jobs/meter_helper/`:
- `grid_meter_client.rb` - Fetches grid power data from Volkszähler API (port 8081)
- `heating_meter_client.rb` - Fetches heating consumption
- `solar_meter_client.rb` - Fetches SMA inverter data
- `opendtu_meter_client.rb` - Fetches OpenDTU solar data (API: `/api/livedata/status`)

### Required Environment Variables
- `GRID_METER_HOST` - Volkszähler host IP
- `OPENDTU_HOST` - OpenDTU inverter host IP
- `EM_APP_ID`, `EM_CONSUMER_KEY`, `EM_CONSUMER_SECRET` - Yahoo Weather API credentials

## Testing

Tests use Minitest with WebMock for HTTP stubbing. All external API calls must be mocked.

```ruby
# Example test pattern
stub_request(:get, "http://192.168.1.100:80/api/livedata/status")
  .to_return(status: 200, body: response.to_json)
```

## Code Style

- Ruby 2-space indentation, snake_case naming
- Use HTTParty for HTTP requests
- Wrap external API calls in error handling with fallback values
- Follow existing Smashing widget conventions
