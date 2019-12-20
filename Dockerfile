FROM ruby:2.6.3p62

WORKDIR /usr/src/app

RUN apt-get update && \
    apt-get -y install nodejs && \
    apt-get -y clean

COPY Gemfile Gemfile.lock ./
RUN bundle install
RUN bundle update

COPY ./dashboards ./dashboards
COPY ./widgets ./widgets
COPY ./jobs ./jobs
COPY ./config ./config
COPY ./config.ru .
COPY ./lib ./lib
COPY ./assets ./assets

ENV PORT 3030
EXPOSE $PORT

CMD ["/bin/sh"]
