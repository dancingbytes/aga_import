require 'rails/railtie'

module AgaImport

  class Railtie < ::Rails::Railtie #:nodoc:

    config.after_initialize do

      Imp( ::AgaImport::proc_name, ::AgaImport::daemon_log ) do

        ::Listen.to(::AgaImport::import_dir, :filter => /\.zip$/) do |modified, added, removed|
          unless added.empty?
            ::AgaImport::Manager.run
          end
        end

        Thread.current.join

      end # Imp

    end # initializer

  end # Railtie

end # AgaImport
