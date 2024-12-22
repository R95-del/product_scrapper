class ProductsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def index
    if params[:search].present?
      @products = Product.where("lower(title) LIKE ? OR lower(description) LIKE ?",
                              "%#{params[:search].downcase}%",
                              "%#{params[:search].downcase}%")
    else
      @products = Product.all
    end
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
        product_data = Scrapers::WebScraperService.scrape(product_params[:url])
        product.assign_attributes(
          product_data.merge(last_scraped_at: Time.current)
        )
      end

      respond_to do |format|
        if @product.persisted?
          format.html { redirect_to products_path, notice: "Product was successfully scraped." }
          format.json { render json: @product, status: :created }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @product.errors, status: :unprocessable_entity }
        end
      end
    rescue StandardError => e
      Rails.logger.error("Scraping failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      respond_to do |format|
        format.html do
          flash[:error] = e.message
          redirect_to new_product_path
        end
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @product = Product.find(params[:id])
    @product.destroy
    redirect_to products_path, notice: "Product was successfully deleted"
  end

  private

  def product_params
    params.require(:product).permit(:url)
  end
end
