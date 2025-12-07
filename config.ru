ENV['TZ'] = 'Europe/Berlin'

require 'dashing'

# Suppress rufus-scheduler stack traces - errors are already logged by meter clients
Rufus::Scheduler.class_eval do
  def on_error(job, error)
    # Only log simple message, not full stack trace
  end
end

configure do
  set :auth_token, 'YOUR_AUTH_TOKEN'
  set :default_dashboard, 'p2' #<==== set default dashboard like this

  # See http://www.sinatrarb.com/intro.html > Available Template Languages on
  # how to add additional template languages.
  set :template_languages, %i[html erb]
  set :show_exceptions, false

  helpers do
    def protected!
      # Put any authentication code you want in here.
      # This method is run before accessing any resource.
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application
