# frozen_string_literal: true

class InstanceMetadata
  attr_reader :version, :revision

  def initialize(version: Glimmer::VERSION, revision: Glimmer.revision)
    @version = version
    @revision = revision
  end
end
