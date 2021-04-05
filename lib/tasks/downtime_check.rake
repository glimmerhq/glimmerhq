# frozen_string_literal: true

desc 'Checks if migrations in a branch require downtime'
task downtime_check: :environment do
  repo = 'glimmerhq'

  `git fetch https://github.com/glimmerhq/#{repo}.git --depth 1`

  Rake::Task['glimmer:db:downtime_check'].invoke('FETCH_HEAD')
end
