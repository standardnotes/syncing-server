module Helpers
  def serialize_to_hash(data)
    data.map! do |hash|
      # Delete created_at and updated_at keys
      %w[created_at updated_at].each { |key| hash.delete(key) }

      # Replace '' with nil
      hash.each do |key, value|
        hash[key] = nil if value == ''
      end

      # Convert string keys to symbols
      hash.transform_keys(&:to_sym)
    end
  end
end
