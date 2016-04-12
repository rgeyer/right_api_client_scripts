FROM ruby:2.2
MAINTAINER Ryan J. Geyer <me@ryangeyer.com>

RUN mkdir /code
COPY Gemfile /code/
RUN cd /code && bundle install

RUN cd /tmp && curl https://binaries.rightscale.com/rsbin/rsc/v5/rsc-linux-amd64.tgz | tar -zxf - -O rsc/rsc > rsc && chmod +x ./rsc && mv ./rsc /usr/bin/rsc

WORKDIR /code
