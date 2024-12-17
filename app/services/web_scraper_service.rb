require 'mechanize'

class WebScraperService
  USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/119.0.0.0 Safari/537.36'
  DEFAULT_HEADERS = {
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.5',
    'Cache-Control' => 'no-cache',
    'Pragma' => 'no-cache',
    'Referer' => 'https://www.flipkart.com'
  }.freeze

  SELECTORS = {
    title: [
      'span.B_NuCI', 'h1.yhB1nd', '.B_NuCI', '._35KyD6', '.title', 'h1',
      'meta[property="og:title"]'
    ].freeze,
    description: [
      'div._1mXcCf p', 'div._1mXcCf', '.product-description',
      'meta[name="description"]', 'meta[property="og:description"]'
    ].freeze,
    category: [
      'div._1MR4o5 a', 'div[class*="_1MR4o5"] a', 'div._3GIHBu a',
      'div[class*="breadcrumb"] a'
    ].freeze
  }.freeze

  PRICE_PATTERNS = [
    /₹\s*(\d+,?\d*)/,
    /Rs\.?\s*(\d+,?\d*)/i,
    /Price.*?(\d+,?\d*)/i,
    /(\d+,?\d*).?only/i,
    /MRP.*?(\d+,?\d*)/i
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
  rescue => e
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
    page_text = doc.text
    price_text = extract_price_from_text(page_text)

    if price_text
      clean_and_convert_price(price_text)
    else
      puts "No price found, defaulting to 0.0"
      0.0
    end
  end

  def find_category(doc)
    breadcrumbs = extract_breadcrumbs(doc)
    category = breadcrumbs.last

    if category.blank?
      @url.split('/')[3]&.capitalize || "Uncategorized"
    else
      category
    end
  end

  def extract_content(doc, type)
    SELECTORS[type].each do |selector|
      if selector.start_with?('meta')
        content = doc.at_css(selector)&.attr('content')
      else
        content = doc.css(selector).text.strip
      end
      return content if content.present?
    end
    nil
  end

  def extract_price_from_text(text)
    PRICE_PATTERNS.each do |pattern|
      if text =~ pattern
        puts "Found price from text pattern: #{$1}"
        return $1
      end
    end
    nil
  end

  def clean_and_convert_price(price_text)
    cleaned_price = price_text.gsub(/[^\d.]/, '')
    price = cleaned_price.to_f
    puts "Converted price: #{price}"
    price.positive? ? price : 0.0
  end

  def extract_breadcrumbs(doc)
    SELECTORS[:category].each do |selector|
      elements = doc.css(selector)
      if elements.any?
        breadcrumbs = elements.map(&:text).map(&:strip)
        puts "Found breadcrumbs: #{breadcrumbs.join(' > ')}"
        return breadcrumbs
      end
    end
    []
  end

  def handle_error(error)
    puts "Error: #{error.message}"
    puts error.backtrace
    raise ScrapingError, "Failed to scrape the product: #{error.message}"
  end
end

class ScrapingError < StandardError; end
