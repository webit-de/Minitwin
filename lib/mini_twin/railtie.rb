class Minitwin
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(__dir__, "..", "tasks", "minitwin.rake")
    end
  end
end
