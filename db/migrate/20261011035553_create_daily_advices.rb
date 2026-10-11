class CreateDailyAdvices < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_advices do |t|
      t.references :user, null: false, foreign_key: true
      t.date :date, null: false # 対象日
      t.integer :outfit_level, null: false # おすすめの服装（Outfit::LEVELS）
      t.text :comment # AI の一言（ホーム用）。AI に失敗した日は空
      t.text :line_comment # AI の一言（LINE 用・砕けた口調）。AI に失敗した日は空
      t.decimal :max_temp, precision: 4, scale: 1, null: false # 最高気温
      t.decimal :min_temp, precision: 4, scale: 1, null: false # 最低気温
      t.decimal :yesterday_max_temp, precision: 4, scale: 1, null: false # 昨日の最高気温（「昨日より○℃」用）
      t.integer :precipitation_probability # 降水確率（取れない日もある）

      t.timestamps
    end
    # 1人1日1件
    add_index :daily_advices, %i[user_id date], unique: true
  end
end
