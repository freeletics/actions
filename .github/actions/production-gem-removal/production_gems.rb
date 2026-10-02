# Prints the names of the gems the production image installs for the Gemfile
# and Gemfile.lock in DIR, one per line, sorted.
#
#   ruby production_gems.rb DIR
#
# The image runs `bundle config without development:test`
# (docker-rails-baseimage), and Bundler skips a Gemfile entry only when every
# one of its groups is excluded. So `group :development, :test, :qa` is still
# installed. The roots are those entries; everything they reach through the
# lockfile is installed with them.
#
# Only the Gemfile DSL and the lockfile parser are used: nothing is resolved,
# fetched or installed, so this needs neither the network nor the gems.

dir = File.expand_path(ARGV.fetch(0))
gemfile = File.join(dir, "Gemfile")
lockfile = File.join(dir, "Gemfile.lock")

# Gemfiles read files relative to themselves (`ruby File.read(".ruby-version")`,
# `gemspec`), and Bundler.root comes from BUNDLE_GEMFILE, so both must point at
# DIR before Bundler is loaded.
ENV["BUNDLE_GEMFILE"] = gemfile
Dir.chdir(dir)
require "bundler"

EXCLUDED_GROUPS = %i[development test].freeze

definition = Bundler::Definition.build(gemfile, lockfile, nil)
roots = definition.dependencies
  .select(&:should_include?)
  .reject { |dep| (dep.groups - EXCLUDED_GROUPS).empty? }
  .map(&:name)

# A gem locked for several platforms has the dependencies of all its variants
# merged, so the set is the same on an x64 and an arm runner.
#
# The set can hold a build-only gem the image lacks. The backends lock only the
# ruby platform, yet Bundler installs nokogiri's precompiled Linux build, which
# does not need the mini_portile2 the lockfile lists. Such extras are gems the
# app never loads, so at worst they add a removal to the report.
dependencies = Hash.new { |hash, name| hash[name] = [] }
Bundler::LockfileParser.new(Bundler.read_file(lockfile)).specs.each do |spec|
  dependencies[spec.name] |= spec.dependencies.map(&:name)
end

# Names missing from the lockfile (bundler itself) are not installed from it.
installed = {}
queue = roots.select { |name| dependencies.key?(name) }
until queue.empty?
  name = queue.shift
  next if installed[name]

  installed[name] = true
  queue.concat(dependencies.fetch(name).select { |dep| dependencies.key?(dep) })
end

puts installed.keys.sort
