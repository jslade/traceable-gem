#!/bin/bash -ex

function cleanup() {
  exit_code=$?
  set +e
  docker-compose kill
  exit $exit_code
}
trap cleanup INT TERM EXIT

docker-compose build
docker-compose run --rm app /bin/bash -l -c \
  "rvm-exec 2.4 bundle exec rubocop -a --fail-level autocorrect"
docker-compose run --rm --name traceable-coverage app $@
docker cp coverage:/app/coverage .
