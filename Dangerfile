# frozen_string_literal: true

require_relative 'lib/glimmer_danger'
require_relative 'lib/glimmer/danger/request_helper'

danger.import_plugin('danger/plugins/helper.rb')
danger.import_plugin('danger/plugins/roulette.rb')
danger.import_plugin('danger/plugins/changelog.rb')
danger.import_plugin('danger/plugins/sidekiq_queues.rb')

return if helper.release_automation?

glimmer_danger = GlimmerDanger.new(helper.glimmer_helper)

glimmer_danger.rule_names.each do |file|
  danger.import_dangerfile(path: File.join('danger', file))
end

anything_to_post = status_report.values.any? { |data| data.any? }

if glimmer_danger.ci? && anything_to_post
  markdown("**If needed, you can retry the [`danger-review` job](#{ENV['CI_JOB_URL']}) that generated this comment.**")
end
