class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products do |t|
      t.string :title
      t.text :description
      t.decimal :price
      t.string :url
      t.string :category
      t.datetime :last_scraped_at

      t.timestamps
    end
    add_index :products, :url, unique: true
  end
end
