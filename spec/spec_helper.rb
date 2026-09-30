# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  skip '/spec/'
  skip '/vendor/'
  minimum_coverage 100
end

require_relative '../lib/security'

# rubocop:disable-next Style/MixinUsage
include Security
