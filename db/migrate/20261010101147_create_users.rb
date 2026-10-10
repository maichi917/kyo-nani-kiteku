class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :line_user_id, null: false # LINE のユーザーID。通知の送り先にも使う
      t.string :name, null: false # LINE の表示名
      t.integer :sensitivity, null: false, default: 0 # 体質（0 = ふつう）

      t.timestamps
    end
    add_index :users, :line_user_id, unique: true
  end
end
