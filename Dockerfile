FROM instructure/rvm

WORKDIR /app

COPY traceable.gemspec Gemfile /app/
COPY lib/traceable/version.rb /app/lib/traceable/version.rb

USER root
RUN mkdir -p /app/coverage \
             /app/log \
             /app/spec/dummy/log \
             /app/spec/dummy/tmp \
 && chown -R docker:docker /app

USER docker
RUN /bin/bash -l -c "cd /app && rvm-exec 2.4 bundle install"
COPY . /app

USER root
RUN chown -R docker:docker /app
USER docker

CMD /bin/bash -l -c "rvm-exec 2.4 bundle exec wwtd --parallel"
