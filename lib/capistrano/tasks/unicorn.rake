# namespace :unicorn do
#   desc 'Starts unicorn'
#   task :start do
#     on roles :app, reject: lambda { |h| h.properties.no_release } do
#       execute("cd #{current_path} && bin/unicorn -c #{shared_path}/config/unicorn.conf.rb -E #{fetch(:rails_env)} -D")
#     end
#   end
#   desc 'Stops unicorn'
#   task :stop do
#     on roles :app , reject: lambda { |h| h.properties.no_release } do
#       execute(" kill `cat #{unicorn_pid}`")
#     end
#   end
#   desc 'Stops unicorn gracefully (QUIT)'
#   task :graceful_stop do
#     on roles :app , reject: lambda { |h| h.properties.no_release } do
#       execute(" kill -s QUIT `cat #{unicorn_pid}`")
#     end
#   end
#   desc 'Reloads unicorn sending USR2'
#   task :reload do
#     on roles :app , reject: lambda { |h| h.properties.no_release } do
#       execute(" kill -s USR2 `cat #{unicorn_pid}`")
#     end
#   end
#   desc 'Restarts unicorn by stop an start'
#   task :restart do
#     on roles :app , reject: lambda { |h| h.properties.no_release } do
#       stop
#       start
#     end
#   end
# end


namespace :load do
  task :defaults do
    set :unicorn_pid, -> { "#{shared_path}/tmp/pids/unicorn.pid" }
    set :unicorn_config_path, -> { File.join(shared_path, "config", "unicorn.rb") }
    set :unicorn_restart_sleep_time, 3
    set :unicorn_roles, -> { :app }
    set :unicorn_options, -> { "" }
    set :unicorn_rack_env, -> { fetch(:rails_env)  }
    set :unicorn_bundle_gemfile, -> { File.join(current_path, "Gemfile") }
  end
end

namespace :unicorn do
  desc "Start Unicorn"
  task :start do
    on roles(fetch(:unicorn_roles)) do
      within current_path do
        with rails_env: fetch(:rails_env), bundle_gemfile: fetch(:unicorn_bundle_gemfile) do
          execute :bundle, "exec unicorn", "-c", fetch(:unicorn_config_path), "-E", fetch(:unicorn_rack_env), "-D", fetch(:unicorn_options)
        end
      end
    end
  end

  desc "Stop Unicorn (QUIT)"
  task :stop do
    on roles(fetch(:unicorn_roles)) do
      within current_path do
        if test("[ -e #{fetch(:unicorn_pid)} ]")
          if test("kill -0 #{pid}")
            info "stopping unicorn..."
            execute :kill, "-s QUIT", pid
          else
            info "cleaning up dead unicorn pid..."
            execute :rm, fetch(:unicorn_pid)
          end
        else
          info "unicorn is not running..."
        end
      end
    end
  end

  desc "Reload Unicorn (HUP); use this when preload_app: false"
  task :reload do
    # on roles(fetch(:unicorn_roles)) do
    #   within current_path do
    #     info "reloading..."
    #     execute :kill, "-s HUP", pid
    #   end
    # end
    invoke "unicorn:stop"
    invoke "unicorn:start"
  end

  desc "Restart Unicorn (USR2 + QUIT); use this when preload_app: true"
  task :restart do
    invoke "unicorn:start"
    on roles(fetch(:unicorn_roles)) do
      within current_path do
        info "unicorn restarting..."
        execute :kill, "-s USR2", pid
        execute :sleep, fetch(:unicorn_restart_sleep_time)
        if test("[ -e #{fetch(:unicorn_pid)}.oldbin ]")
          execute :kill, "-s QUIT", pid_oldbin
        end
      end
    end
  end

  desc "Add a worker (TTIN)"
  task :add_worker do
    on roles(fetch(:unicorn_roles)) do
      within current_path do
        info "adding worker"
        execute :kill, "-s TTIN", pid
      end
    end
  end

  desc "Remove a worker (TTOU)"
  task :remove_worker do
    on roles(fetch(:unicorn_roles)) do
      within current_path do
        info "removing worker"
        execute :kill, "-s TTOU", pid
      end
    end
  end
end

def pid
  "`cat #{fetch(:unicorn_pid)}`"
end

def pid_oldbin
  "`cat #{fetch(:unicorn_pid)}.oldbin`"
end