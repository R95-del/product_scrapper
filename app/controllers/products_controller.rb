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

  def import
    if params[:file].present?
      begin
        results = Product.process_urls_from_excel(params[:file])

        success_message = "Successfully processed #{results[:success].count} products."
        error_message = if results[:failed].any?
                         "Failed to process #{results[:failed].count} URLs: #{results[:failed].map { |f| f[:url] }.join(', ')}"
                       end

        flash[:notice] = success_message
        flash[:error] = error_message if error_message

      rescue StandardError => e
        flash[:error] = "Error processing file: #{e.message}"
      end
    else
      flash[:error] = "Please select a file to upload"
    end

    redirect_to products_path
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

  def download_sample
    send_file(
      Rails.root.join("lib", "templates", "product_urls_template.xlsx"),
      filename: "product_urls_template.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
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
