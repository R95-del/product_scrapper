class Product < ApplicationRecord
  # validates :title, presence: true
  validates :url, presence: true
  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  scope :needs_update, -> { where('last_scraped_at < ?', 1.week.ago) }
end
