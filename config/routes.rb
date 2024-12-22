Rails.application.routes.draw do
  root "products#index"
  resources :products do
    collection do
      post "import"
      get "download_sample"
    end
  end
end
