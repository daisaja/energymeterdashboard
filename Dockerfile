FROM ruby:2.6.5

WORKDIR /usr/src/app

RUN apt-get update && \
    apt-get -y install nodejs && \
    apt-get -y clean

RUN gem install bundler smashing

COPY Gemfile Gemfile.lock ./
RUN bundle install
RUN bundle update

COPY ./assets ./assets
COPY ./config.ru .
COPY ./dashboards ./dashboards
COPY ./jobs ./jobs
COPY ./public ./public
COPY ./widgets ./widgets

ENV PORT 3030
EXPOSE $PORT

ENTRYPOINT smashing start
