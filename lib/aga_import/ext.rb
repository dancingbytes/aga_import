# encoding: utf-8
module AgaImport

  module StringExt

    def utf8

      self.force_encoding(::Encoding::UTF_8) if self.respond_to?(:force_encoding)
      self

    end # utf8

    def escape

      self.
        gsub(/'/, "\\\\'").
        gsub(/"/, '\\\\"').
        gsub(/\n/, "\\n").
        gsub(/\r/, "\\r")

    end # escape

  end # StringExt

  module NilExt

    def utf8
      self
    end # utf8

  end # NilExt

end # AgaImport

class String
  include ::AgaImport::StringExt
end # String

class NilClass
  include ::AgaImport::NilExt
end
