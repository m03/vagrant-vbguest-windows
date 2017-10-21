begin
  require 'cane/rake_task'

  desc 'Run cane to check quality metrics'
  Cane::RakeTask.new(:quality) do |cane|
    cane.abc_max = 20 
    cane.style_measure = 120
  end
rescue LoadError
  warn 'Cane not available.'
end
