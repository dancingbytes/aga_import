# encoding: utf-8
AgaImport::Engine.routes.draw do

  get  '1c_import(/:base)' => 'import#index'
  post '1c_import(/:base)' => 'import#save_file'

end # draw
