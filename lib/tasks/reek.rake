require 'reek/rake/task'

Reek::Rake::Task.new do |task|
  task.fail_on_error = false
end
