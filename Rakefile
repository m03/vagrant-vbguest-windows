require 'bundler/gem_tasks'

Dir.glob('lib/tasks/*.rake').each { |rake_task| import rake_task }

task :default => [:quality, :reek]
