# frozen_string_literal: true

class CleanupLegacyArtifactMigration < ActiveRecord::Migration[5.0]
  include Glimmer::Database::MigrationHelpers

  DOWNTIME = false

  disable_ddl_transaction!

  class Build < ActiveRecord::Base
    include EachBatch

    self.table_name = 'ci_builds'
    self.inheritance_column = :_type_disabled

    scope :with_legacy_artifacts, -> { where("artifacts_file <> ''") }
  end

  def up
    Glimmer::BackgroundMigration.steal('MigrateLegacyArtifacts')

    CleanupLegacyArtifactMigration::Build
      .with_legacy_artifacts
      .each_batch(of: 100) do |batch|
      range = batch.pluck('MIN(id)', 'MAX(id)').first

      Glimmer::BackgroundMigration::MigrateLegacyArtifacts.new.perform(*range)
    end
  end

  def down
    # no-op
  end
end
