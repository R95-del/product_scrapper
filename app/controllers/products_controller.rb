class ProductsController < ApplicationController
  skip_before_action :verify_authenticity_token
  def index
    @products = Product.all
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    @product = Product.new
  end

  def create
    begin
      @product = Product.find_or_create_by(url: product_params[:url]) do |product|
        product_data = WebScraperService.scrape(product_params[:url])
        product.assign_attributes(
          product_data.merge(last_scraped_at: Time.current)
        )
      end

      status = @product.created_at == @product.updated_at ? :created : :ok
      render json: @product, status: status
    rescue StandardError => e
      Rails.logger.error("Scraping failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def search
    @query = params[:query]
    @products = if @query.present?
      Product.where("LOWER(title) LIKE ? OR LOWER(description) LIKE ?",
                   "%#{@query.downcase}%", "%#{@query.downcase}%")
    else
      Product.none
    end
    render json: @products
  end

  private

  def product_params
    params.require(:product).permit(:url)
  end
end
