# AI Coding Agent Rules for Energy Meter Dashboard

## Project Overview
This is a **Ruby/Smashing-based Energy Dashboard** project that monitors energy consumption, integrates with weather APIs, and uses InfluxDB for data storage. The project is containerized with Docker and uses GitHub Actions for CI/CD.

## Core Development Rules

### 1. **Code Style & Conventions**
- Follow Ruby style guide (2-space indentation, snake_case for methods/variables)
- Use Ruby gems from Gemfile - never bypass dependency management
- Maintain consistency with existing widget structure in the Smashing framework
- Use HTTParty for HTTP requests (already in dependencies)
- Prefer JSON format for API responses

### 2. **Testing Requirements**
- All code changes must include Minitest tests
- Maintain or improve SimpleCov coverage (minimum 80%)
- Run `rake test` locally before proposing changes
- Mock external API calls with WebMock
- Test environment variables and configuration handling

### 3. **Environment & Configuration**
- **Never hardcode** sensitive values (API keys, secrets, database credentials)
- Use environment variables: `EM_APP_ID`, `EM_CONSUMER_KEY`, `EM_CONSUMER_SECRET`
- Document all required env vars in changes
- Support both local development (.env files) and Docker runtime (--env-file)

### 4. **External Integrations**
- **Open-Meteo API**: Free weather API (no API key required) for temperature and weather data
- **SMA Inverter**: Firmware 2.13.33.R / 3.10.10.R (document version requirements)
- **InfluxDB**: Use influxdb-client gem for all database operations
- **Tibber GraphQL**: Use graphql-client gem for energy pricing data
- All external calls should have timeouts and error handling

### 5. **Docker & Deployment**
- All changes must be compatible with Dockerfile
- Test Docker build locally: `docker build -t daisaja/energymeter:latest .`
- Use build arguments for env vars during build time
- Document any new Docker volume or port requirements
- Ensure changes work in containerized environment

### 6. **Git & Version Control**
- Write clear, descriptive commit messages
- Reference issue numbers when applicable
- Keep commits atomic and focused
- Follow existing commit history style
- Update CHANGELOG if significant features added

### 7. **Code Quality Standards**
- **No breaking changes** to existing widget APIs
- Remove dead code and commented-out sections
- Keep methods small and focused (< 20 lines preferred)
- Document complex logic with comments
- Avoid nested callbacks (prefer blocks/methods)

### 8. **Widget Development**
- Follow Smashing widget structure and conventions
- All widgets must have proper error handling for failed data fetches
- Implement graceful degradation if external APIs are unavailable
- Update data with reasonable intervals (avoid API rate limits)
- Include meaningful widget titles and data labels

### 9. **Error Handling & Logging**
- Always wrap external API calls in begin/rescue blocks
- Log errors with context (which API, why it failed)
- Provide fallback values or display error states to users
- Don't expose internal errors to dashboard display
- Test error scenarios in unit tests

### 10. **Documentation**
- Update README.md if adding new API integrations or setup steps
- Document environment variables in comments
- Include usage examples for complex features
- Keep firmware/version requirements updated
- Comment non-obvious business logic

### 11. **Performance Considerations**
- Minimize API calls to external services
- Implement caching where appropriate
- Monitor InfluxDB query performance
- Avoid blocking operations in widget refresh
- Consider rate limits of weather and energy APIs

### 12. **Security Requirements**
- Never commit .env files or credentials
- Sanitize user input if applicable
- Use HTTPS for external API calls
- Validate API responses before processing
- Keep dependencies up to date (watch for CVEs)

## Agent Workflow
1. **Understand** - Read project structure, existing code, and issue context
2. **Plan** - Create a plan before implementing (use TODO lists for complex tasks)
3. **Test First** - Write tests for new functionality
4. **Implement** - Write clean, documented code
5. **Verify** - Run full test suite and Docker build
6. **Document** - Update README/comments as needed
7. **Commit** - Create clear, atomic commits

## Red Flags - DO NOT PROCEED
- Hardcoding secrets or API keys
- Breaking existing widget interfaces
- Skipping tests
- Ignoring Docker compatibility
- Committing without running tests
- Adding untested external API integrations

## Useful Commands
```bash
rake test                    # Run all tests
rake coverage               # Check test coverage
docker build -t energymeter .
docker run -p 3030:3030 --env-file .env energymeter
bundle install              # Install/update gems
bundle update               # Update gem versions
```
