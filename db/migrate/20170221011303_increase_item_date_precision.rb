class IncreaseItemDatePrecision < ActiveRecord::Migration[5.0]
  def change
    change_column :items, :created_at, :datetime, limit: 6
    change_column :items, :updated_at, :datetime, limit: 6

    def add_random_microseconds_for_date(date)
      to_string = date.strftime('%Y-%m-%d %H:%M:%S.%N')
      comps = to_string.split(".")
      comps_minus_micro = comps[0]
      micro_comp = rand.to_s[2,6]
      date_string = "#{comps_minus_micro}.#{micro_comp}"
      return date_string.to_datetime
    end

    Item.all.each do |item|
      item.update_column(:created_at, add_random_microseconds_for_date(item.created_at))
      item.update_column(:updated_at, add_random_microseconds_for_date(item.updated_at))
    end

  end
end
