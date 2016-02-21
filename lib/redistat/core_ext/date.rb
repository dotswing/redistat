class Date
  include Redistat::DateHelper

  def to_time
    Time.zone.parse(self.to_s)
  end

end
