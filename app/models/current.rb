class Current < ActiveSupport::CurrentAttributes
  attribute :family, :session, :user

  def self.with_family(value, &)
    with(family: value, &)
  end

  def session=(value)
    super(value)

    if value.present?
      self.user = session.user
      self.family = session.family
    end
  end
end
