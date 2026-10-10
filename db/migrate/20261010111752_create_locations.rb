class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      # 1人1つ（自宅）なので user_id はユニーク
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false # 地名（例：東京都渋谷区）
      t.decimal :latitude, precision: 9, scale: 6, null: false # 緯度
      t.decimal :longitude, precision: 9, scale: 6, null: false # 経度

      t.timestamps
    end
  end
end
