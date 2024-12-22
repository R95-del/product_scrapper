class Product < ApplicationRecord
  validates :url, presence: true
  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  scope :needs_update, -> { where("last_scraped_at < ?", 1.week.ago) }

  def formatted_price
    "₹#{price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
end
