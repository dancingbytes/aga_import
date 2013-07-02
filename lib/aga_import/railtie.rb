require 'rails/railtie'

module AgaImport

  class Railtie < ::Rails::Railtie #:nodoc:

    config.after_initialize do

      Imp( ::AgaImport::proc_name, ::AgaImport::daemon_log ) do

        t = ::Listen.to(::AgaImport::import_dir, :filter => /\.zip$/, :ignore => [/\.jpg$/, /\.png$/, /\.jpeg$/], :force_polling => true, :latency => 1.0 ) do |modified, added, removed|
          unless added.empty?
            ::AgaImport::Manager.run
          end
        end
        t.join
      end # Imp

    end # initializer

  end # Railtie

end # AgaImport
