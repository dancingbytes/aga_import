# encoding: UTF-8
module AgaImport

  # Класс-шаблон по разбору товарных xml-файлов
  class XmlParser < ::Nokogiri::XML::SAX::Document

    def initialize(saver)

      @saver  = saver
      @item   = {}
      @level  = 0
      @tags   = {}
      @partial = false
      @created_at = nil
      @catalogs = []
      @catalog_level = -1
      @validation_stage = 1

    end # initialize

    def start_element(name, attrs = [])

      attrs  = ::Hash[attrs]
      @str   = ""

      @level += 1
      @tags[@level] = name

      case name

        # 1C 8
        when 'КоммерческаяИнформация' then
          @created_at = DateTime.iso8601(attrs['ДатаФормирования'])
          
        when 'ПакетПредложений','Каталог' then
          @partial = attrs['СодержитТолькоИзменения'] == 'true' if attrs['СодержитТолькоИзменения']
          @saver.partial = @partial

        when 'Группа'       then start_catalog
        when 'Группы'       then start_catalogs
        when 'ТипЦены'      then start_parse_price
        when 'Предложение'  then start_parse_item
        when 'Товар'        then start_parse_item
        when 'Цена'         then start_parse_item_price
      end # case

    end # start_element

    def end_element(name)

      @level -= 1

      case name

        when 'Группа'         then stop_catalog
        when 'Группы'         then stop_catalogs

        when 'Ид'             then
          case parent_tag
            when 'Классификатор'  then
              @validation_stage = 1
            when 'Группа'         then
              grub_catalog('id')
          end
          @price_id  = @str  if for_price?
          grub_item('code_1c')
          grub_catalog_for_item
          grub_image_for_item
        when 'Наименование'   then
          grub_catalog('name')
          @price_name = @str if for_price?
          grub_item('name')
        when 'ИдКаталога'     then
          if parent_tag == 'ПакетПредложений'
            @validation_stage = 2
          end
        when 'Отдел'          then grub_item('department')
        when 'Артикул'        then grub_item('marking_of_goods')
        when 'АртикулПроизводителя' then 
          grub_item('vendor_artikul')
        when 'Производитель'  then grub_item('vendor')
        when 'Количество'     then grub_item('available')

        when 'БазоваяЕдиница' then grub_item('unit')

        when 'ЦенаЗаЕдиницу'  then
          @item_price = @str.sub(/\A\s+/, "").sub(/\s+\z/, "").gsub(/(\s){2,}/, '\\1').try(:to_f)  if for_item_price?

        when 'ПроцентСкидки'  then
          @item_discount = @str.sub(/\A\s+/, "").sub(/\s+\z/, "").gsub(/(\s){2,}/, '\\1').try(:to_f) if for_item_price?

        when 'ИдТипаЦены'   then
          @item_price_id = @str  if for_item_price?

        when 'ТипЦены'              then stop_parse_price
        when 'Предложение','Товар'  then stop_parse_item
        when 'Цена'                 then stop_parse_item_price
        when 'Описание'             then grub_item_description
        when 'Картинка'             then grub_image_for_item

      end # case

    end # end_element

    def characters(str)
      @str << str.squish unless str.blank?
    end # characters

    def error(string)
      @saver.log "[XML Errors] #{string}"
    end # error

    def warning(string)
      @saver.log "[XML Warnings] #{string}"
    end # warning

    def end_document
    end

    private

    def parent_tag(index = 0)
      @tags[@level+0] || ""
    end # parent_tag

    def for_item?
      (@start_parse_item && parent_tag == 'Предложение') || (@start_parse_item && parent_tag == 'Товар')
    end # for_item?

    def group_for_item?
      @start_parse_item && parent_tag == 'Группы'
    end

    def for_price?
      (@parse_price && parent_tag == 'ТипЦены')
    end # for_price?

    def for_item_price?
      (@start_parse_item_price && parent_tag == 'Цена')
    end # for_item_price?

    def grub_item(attr_name)
      @item[attr_name] = @str.xml_unescape if for_item?
    end # grub_item

    def grub_catalog(attr_name)
      @catalogs.last[attr_name] = @str if for_catalog?
    end

    def grub_catalog_for_item(attr_name = 'catalog')
      @item[attr_name] = @str.xml_unescape if group_for_item?
    end



    def save_catalog(attrs)
      @saver.save_catalog(
        attrs['id'],
        attrs['name'],
        attrs['parent']
        )
    end

    def save_item(attrs)
      @saver.save_item(
        attrs['code_1c'],
        attrs['name'],
        attrs['marking_of_goods'],
        attrs['vendor_artikul'],
        attrs['supplier_purchasing_price'].try(:to_f),
        attrs['supplier_wholesale_price'].try(:to_f),
        attrs['available'].try(:to_i),
        attrs['unit'],
        attrs['in_pack'].try(:to_i) || 1,
        attrs['catalog'],
        attrs['vendor'],
        attrs['description'],
        attrs['image']
      )
    end
    
    #
    # 1C 8
    #

    def start_catalogs
      @catalog_level += 1 
      @catalogs.last['level'] = @catalog_level-1 if @catalog_level > 0
    end

    def start_catalog
      @catalogs << {}
    end

    def stop_catalogs
      if parent_tag == 'Классификатор'
        @catalogs.each do |c|
          save_catalog(c)
        end
      end
      @catalog_level -= 1
    end

    def stop_catalog
      return if @catalogs.last['level']
      @catalogs.last['level'] = @catalog_level
      if @catalog_level > 0
        possible_parents = @catalogs.select {|sel| sel['level'] == (@catalog_level - 1)}
        @catalogs.last['parent'] = possible_parents.last['id'] if possible_parents && possible_parents.last['id']
      elsif @catalog_level == 0
        @catalogs.last['parent'] = ''
      end
    end
    
    def for_catalog?
      parent_tag == "Группа"
    end

    def start_parse_price
      @parse_price = true
    end # start_parse_price

    def stop_parse_price

      # if !@price_name.blank? && !@price_id.blank?
      #   @price_types[@price_id] = @price_name
      # end

      @price_name   = nil
      @price_id     = nil
      @parse_price  = false

    end # stop_parse_price

    def start_parse_item

      @start_parse_item = true
      @item = {}

    end # start_parse_item

    def stop_parse_item
      save_item(@item) if validate_1c_8(@item)

      @start_parse_item = false
      @item = {}

    end # start_parse_item

    def start_parse_item_price
      @start_parse_item_price = true
    end # start_parse_item_price

    def stop_parse_item_price

      if !@item_price.blank? && !@item_price_id.blank?

        case @item_price_id

          when "926c45bf-1f44-11de-8200-001a4d377c6e" then
            @item["supplier_wholesale_price"] = @item_price

          when "c8de0f96-191b-11de-bee1-00167682119b" then
            @item["supplier_purchasing_price"] = @item_price

        end # case

      end # if

      @item_price     = nil
      @item_price_id  = nil
      @item_discount  = nil
      @start_parse_item_price = false

    end # stop_parse_item_price

    def grub_item_description(attr_name = 'description')
      @item[attr_name] = @str.xml_unescape
    end

    def grub_image_for_item(attr_name = 'image')
      @item[attr_name] = @str.xml_unescape
    end

    def validate_1c_8(attrs)

      if attrs.empty?
        return false
      end

      if attrs['code_1c'].blank?
        @saver.log "[Errors 1C 8] Не найден идентификатор у товара: #{attrs['marking_of_goods']}"
        return false
      end

      if attrs['name'].blank?
        @saver.log "[Errors 1C 8] Не найдено название у товара: #{attrs['marking_of_goods']}"
        return false
      end

      if attrs['marking_of_goods'].blank?
        @saver.log "[Errors 1C 8] Не найден артикул у товара: #{attrs['name']}"
        return false
      end

      if @validation_stage == 2
        if attrs['supplier_wholesale_price'].blank?
          @saver.log "[Errors 1C 8] Не найдена оптовая цена у товара: #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end

        if attrs['supplier_purchasing_price'].blank?
          @saver.log "[Errors 1C 8] Не найдена закупочная цена у товара: #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end

        if attrs['available'].blank?
          @saver.log "[Errors 1C 8] Не найдено количество товара: #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end
      end

      if @validation_stage == 1
        if attrs['catalog'].blank?
          @saver.log "[Errors 1C 8] Товар не привязан : #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end
      end

      true

    end # validate_1c_8

  end # XmlParser

end # AgaImport
