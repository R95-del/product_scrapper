require "roo"
class Product < ApplicationRecord
  validates :url, presence: true
  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  def formatted_price
    "₹#{price.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse}"
  end

  def self.process_urls_from_excel(file)
    case File.extname(file.original_filename)
    when ".xlsx"
      spreadsheet = Roo::Excelx.new(file.path)
    when ".xls"
      spreadsheet = Roo::Excel.new(file.path)
    else
      raise "Unknown file type: #{file.original_filename}"
    end

    results = {
      success: [],
      failed: []
    }

    # Get all URLs from first column (without skipping any row)
    urls = spreadsheet.column(1).compact

    urls.each_with_index do |url, index|
      next if url.blank?
      begin
        product = Product.find_or_create_by(url: url.strip) do |p|
          data = WebScraperService.scrape(url.strip)
          p.assign_attributes(
            data.merge(last_scraped_at: Time.current)
          )
        end
        results[:success] << product
      rescue StandardError => e
        Rails.logger.error("Failed to process URL #{index + 1}: #{e.message}")
        results[:failed] << { url: url, error: e.message }
      end
    end

    results
  end
end
