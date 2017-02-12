FROM elixir:1.4.0

ARG env

RUN apt-get update
RUN apt-get install -y bash gawk sed grep wget inotify-tools

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install --force https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez

RUN mkdir -p /app
COPY ./mix.exs /app/mix.exs
COPY ./config /app/config
WORKDIR /app

RUN mix deps.get
RUN MIX_ENV=$env mix deps.compile
