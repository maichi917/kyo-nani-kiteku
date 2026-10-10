class AddPictureUrlToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :picture_url, :string
  end
end
