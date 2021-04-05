#!/bin/sh

set -e

for file in config/*.yml.example; do
  cp ${file} config/$(basename ${file} .example)
done

# Allow to override the glimmer URL from an environment variable, as this will avoid having to change the configuration file for simple deployments.
config=$(echo '<% glimmer_url = URI(ENV["GLIMMER_URL"] || "http://localhost:80") %>' | cat - config/glimmer.yml)
echo "$config" > config/glimmer.yml
sed -i "s/host: localhost/host: <%= glimmer_url.host %>/" config/glimmer.yml
sed -i "s/port: 80/port: <%= glimmer_url.port %>/" config/glimmer.yml
sed -i "s/https: false/https: <%= glimmer_url.scheme == 'https' %>/" config/glimmer.yml

# No need for config file. Will be taken care of by REDIS_URL env variable
rm config/resque.yml

# Set default unicorn.rb file
echo "" > config/unicorn.rb
