begin
  require 'cane/rake_task'

  Cane::RakeTask.new(:quality) do |cane|
    cane.abc_max = 20 
    cane.no_style = true
  end
rescue LoadError
  warn 'Cane not available.'
end
