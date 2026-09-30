# frozen_string_literal: true

require 'yaml'

# The gemspec states the minimum Ruby; this fails a change that leaves CI behind it.
describe 'Ruby versions' do
  root = File.expand_path('..', __dir__)
  workflows = Dir[File.join(root, '.github', 'workflows', '*.yml')]

  # Every Ruby a workflow pins, from ruby-version: keys and matrix entries.
  # Expressions such as ${{ matrix.ruby-version }} resolve to values listed elsewhere.
  def pinned_rubies(node)
    case node
    when Hash
      node.flat_map do |key, value|
        pinned = key == 'ruby-version' ? Array(value).map(&:to_s).grep_v(/\$\{\{/) : []
        pinned + pinned_rubies(value)
      end
    when Array then node.flat_map { |value| pinned_rubies(value) }
    else []
    end
  end

  let(:requirement) { Gem::Specification.load(File.join(root, 'security.gemspec')).required_ruby_version }
  let(:minimum) { requirement.requirements.find { |operator, _| operator == '>=' }.last }

  workflows.each do |workflow|
    it "should only run Rubies the gem supports in #{File.basename(workflow)}" do
      too_old = pinned_rubies(YAML.load_file(workflow)).reject { |version| requirement.satisfied_by?(Gem::Version.new(version)) }

      expect(too_old).to be_empty, "#{File.basename(workflow)} pins #{too_old.uniq.join(', ')}, below #{requirement}"
    end
  end

  it 'should test the minimum Ruby itself' do
    pinned = workflows.flat_map { |workflow| pinned_rubies(YAML.load_file(workflow)) }

    expect(pinned.map { |version| Gem::Version.new(version) }).to include(minimum)
  end
end
