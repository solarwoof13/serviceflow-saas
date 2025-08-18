FROM ruby:3.3.0-slim

ENV BUNDLE_VERSION=2.2.32

# Update to use current Debian repositories
RUN apt-get update -qq \
    && apt-get install -y git build-essential libpq-dev curl nodejs npm \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN gem install bundler --version "$BUNDLE_VERSION" \
    && bundle config set force_ruby_platform true \
    && bundle install --jobs 20 --retry 5

COPY . /app

EXPOSE 8080

ENTRYPOINT ["sh","./docker-entrypoint.sh"]