# frozen_string_literal: true

require "mechanize"

# Service to scrape product information from Flipkart
class WebScraperService
  USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36"

  DEFAULT_HEADERS = {
    "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language" => "en-US,en;q=0.5",
    "Cache-Control" => "no-cache",
    "Pragma" => "no-cache",
    "Referer" => "https://www.flipkart.com"
  }.freeze

  SELECTORS = {
    title: [
      "span.B_NuCI",
      "h1.yhB1nd",
      ".B_NuCI",
      "._35KyD6",
      ".title",
      "h1",
      'meta[property="og:title"]'
    ].freeze,
    description: [
      "div._1mXcCf p",
      "div._1mXcCf",
      ".product-description",
      'meta[name="description"]',
      'meta[property="og:description"]'
    ].freeze,
    category: [
      "div._1MR4o5 a",
      'div[class*="_1MR4o5"] a',
      "div._3GIHBu a",
      'div[class*="breadcrumb"] a'
    ].freeze
  }.freeze

  PRICE_PATTERNS = [
    /₹\s*([\d,]+(?:\.\d{2})?)/,                      # Match ₹2999 or ₹2,999.00
    /Rs\.?\s*([\d,]+(?:\.\d{2})?)/i,                 # Match Rs. 2999 or Rs. 2,999.00
    /Rs\.([\d,]+)/i,                                 # Match Rs.2999
    /Price.*?Rs\.?\s*([\d,]+(?:\.\d{2})?)/i,        # Match Price: Rs. 2999
    /(\d+,?\d*(?:\.\d{2})?)(?=\s*(?:only|from))/i   # Match 2999 followed by 'only' or 'from'
  ].freeze

  def self.scrape(url)
    new(url).scrape
  end

  def initialize(url)
    @url = url
    @agent = setup_agent
  end

  def scrape
    page = @agent.get(@url)
    html = Nokogiri::HTML(page.body)

    {
      title: find_title(html),
      description: find_description(html),
      price: find_price(html),
      category: find_category(html),
      url: @url
    }
  rescue StandardError => e
    handle_error(e)
  end

  private

  def setup_agent
    agent = Mechanize.new
    agent.user_agent = USER_AGENT
    agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
    agent.request_headers = DEFAULT_HEADERS
    agent
  end

  def find_title(doc)
    title = extract_content(doc, :title)
    raise ScrapingError, "Title not found" if title.blank?

    title
  end

  def find_description(doc)
    extract_content(doc, :description) || "No description available"
  end

  def find_price(doc)
    price_element = doc.css("div._30jeq3._16Jk6d").first
    if price_element
      price_text = price_element.text.strip
      Rails.logger.info("Found price from element: #{price_text}")
      return clean_and_convert_price(price_text)
    end

    # Fallback to current price patterns
    page_text = doc.text
    price_text = extract_price_from_text(page_text)

    if price_text
      clean_and_convert_price(price_text)
    else
      Rails.logger.info("No price found, defaulting to 0.0")
      0.0
    end
  end

  def find_category(doc)
    breadcrumbs = extract_breadcrumbs(doc)
    category = breadcrumbs.last

    return category if category.present?

    @url.split("/")[3]&.capitalize || "Uncategorized"
  end

  def extract_content(doc, type)
    SELECTORS[type].each do |selector|
      content = if selector.start_with?("meta")
                 doc.at_css(selector)&.attr("content")
               else
                 doc.css(selector).text.strip
               end
      return content if content.present?
    end
    nil
  end

  def extract_price_from_text(text)
    return nil if text.blank?

    PRICE_PATTERNS.each do |pattern|
      if text =~ pattern
        price = $1
        Rails.logger.info("Found price from text pattern: #{price}")
        return price
      end
    end
    nil
  end

  def clean_and_convert_price(price_text)
    return 0.0 if price_text.blank?
    cleaned_price = price_text.gsub(/[^\d.]/, "")
    price = cleaned_price.to_f
    Rails.logger.info("Converted price: #{price}")
    price.positive? ? price : 0.0
  end

  def extract_breadcrumbs(doc)
    SELECTORS[:category].each do |selector|
      elements = doc.css(selector)
      next unless elements.any?

      breadcrumbs = elements.map(&:text).map(&:strip)
      Rails.logger.info("Found breadcrumbs: #{breadcrumbs.join(" > ")}")
      return breadcrumbs
    end
    []
  end

  def handle_error(error)
    Rails.logger.error("Error: #{error.message}")
    Rails.logger.error(error.backtrace.join("\n"))
    raise ScrapingError, "Failed to scrape the product: #{error.message}"
  end
end

class ScrapingError < StandardError; end
