class MiniTwin
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(__dir__, "../../tasks/mini_twin.rake")
    end
  end
end
