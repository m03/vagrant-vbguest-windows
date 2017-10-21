begin
  require 'reek/rake/task'

  desc 'Run reek to check code smell metrics'
  Reek::Rake::Task.new do |task|
    task.fail_on_error = false
  end
rescue LoadError
  warn 'Reek not available.'
end
