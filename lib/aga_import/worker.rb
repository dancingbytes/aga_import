# encoding: UTF-8
module AgaImport

  # Сохранение данных (добавление новых, обновление сущестующих), полученных
  # при разборе xml-файла.
  class Worker
    attr_writer :partial
    def initialize(file, manager)

      @file         = file
      @ins, @upd    = 0, 0
      @cins, @cupd  = 0, 0
      @file_name    = ::File.basename(@file)
      @manager      = manager
      @items_not_deleted    = []
      @catalogs_not_deleted = []
      @partial      = false
    end # new

    def parse

      log "[#{Time.now.strftime('%H:%M:%S %d-%m-%Y')}] Обработка файлов импорта ============================"

      unless @file && ::FileTest.exists?(@file)
        log "Файл не найден: #{@file}"
      else

        log "Файл: #{@file}\n"

        start = Time.now.to_f

        work_with_file

        log "Добавлено товаров: #{@ins}"
        log "Обновлено товаров: #{@upd}"
        log "Добавлено каталогов #{@cins}:"
        log "Обновлено каталогов #{@cupd}:"
        log "Затрачено времени: #{ '%0.3f' % (Time.now.to_f - start) } секунд."
        log ""
        @manager.ins += @ins
        @manager.upd += @upd

        start = Time.now.to_f

        begin

          # тут пометить на удаление

        end

        log "Затрачено времени на 'удаление': #{ '%0.3f' % (Time.now.to_f - start) } секунд."
        log ""
        log ""

      end

      self

    end # parse_file

    def save_catalog(
      id,
      name,
      parent
      )

      group = ItemGroup.find_or_initialize_by(:id_1c => id) do | group |
        group.id_1c = id
        group.name  = name.xml_unescape
      end

      if group.save
        @cins += 1
        true
      else
        false
      end

    end # save_doc

    def save_item(
      id,
      name,
      artikul,
      vendor_artikul,
      price1,
      price2,
      count,
      unit,
      in_pack,
      catalog,
      vendor,
      description,
      imagepath
      )

      catalog = ItemGroup.where(:id_1c => catalog).first



      if ( item = ::Item.where(:id_1c => id).first )
        item.name                     = name.xml_unescape
        item.id_1c                    = id
        item.price_purchase           = price1
        item.price_wholesale          = price2
        item.marking_of_goods         = artikul
        item.vendor_marking_of_goods  = vendor_artikul  unless vendor_artikul.blank?
        item.available                = count
        item.unit                     = unit
        item.in_pack                  = in_pack
        item.item_group_id            = catalog.id      unless catalog.blank?
        item.vendor                   = vendor          unless vendor.blank?
        item.description              = description     unless description.blank?

        uri = File.join(File.expand_path('..', @file), imagepath)
        if File.exists?(uri)
          item.images.destroy_all
          item.images = [uri]
        end

        if item.save
          @ins += 1
          true
        else
          false
        end
      else
        item = ::Item.new
        item.name                     = name.xml_unescape
        item.id_1c                    = id
        item.price_purchase           = price1
        item.price_wholesale          = price2
        item.marking_of_goods         = artikul
        item.vendor_marking_of_goods  = vendor_artikul
        item.available                = count
        item.unit                     = unit
        item.in_pack                  = in_pack
        item.item_group_id            = catalog.id
        item.vendor                   = vendor
        item.description              = description

        # uri = File.join(File.expand_path('..', @file), imagepath)
        # if File.exists?(uri)
        #   item.images = [uri]
        # end

        if item.save
          @ins += 1
          true
        else
          false
        end
      end

    end # save_item

    def log(msg)
      @manager.log(msg)
    end # log

    private

    def work_with_file

      pt = ::AgaImport::XmlParser.new(self)

      parser = ::Nokogiri::XML::SAX::Parser.new(pt)
      parser.parse_file(@file)

      begin

        if ::AgaImport::backup_dir && ::FileTest.directory?(::AgaImport::backup_dir)
          ::FileUtils.mv(@file, ::AgaImport.backup_dir)
        end

      rescue SystemCallError
        log "Не могу переместить файл `#{@file_name}` в `#{::AgaImport.backup_dir}`"
      ensure
        ::FileUtils.rm_rf(@file)
      end

    end # work_with_file    

  end # Worker

end # AgaImport
