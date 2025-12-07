# Build stage - compile assets
FROM ruby:3.3-slim AS builder

WORKDIR /usr/src/app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install bundler and gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && \
    bundle config set --local without 'test' && \
    bundle install --jobs 4

# Copy application files
COPY ./assets ./assets
COPY ./config.ru .
COPY ./dashboards ./dashboards
COPY ./jobs ./jobs
COPY ./public ./public
COPY ./widgets ./widgets

# Precompile assets
RUN bundle exec rake precompile-assets 2>/dev/null || true

# Production stage - minimal runtime image
FROM ruby:3.3-slim

WORKDIR /usr/src/app

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    gem install bundler

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application from builder
COPY --from=builder /usr/src/app ./

ENV PORT=3030
EXPOSE $PORT

CMD ["smashing", "start"]
