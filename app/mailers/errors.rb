# encoding: utf-8
class Errors < ActionMailer::Base
  default :from       => "robot@aga-ural.ru",
          :from_alias => "robot"

  def send_errors
    @greeting = "Hi"

    mail to: "to@example.org"
  end
end
