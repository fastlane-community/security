# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  minimum_coverage 100
end

require_relative '../lib/security'

# rubocop:disable Style/MixinUsage
include Security
# rubocop:enable Style/MixinUsage
