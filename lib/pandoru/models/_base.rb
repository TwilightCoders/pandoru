require 'time'

module Pandoru
  module Models
    # Simple base model for Pandora API objects
    class Base
      attr_reader :data

      def self.fields
        @fields ||= {}
      end

      def self.field(name, json_key = nil, type: nil, &block)
        json_key ||= name.to_s
        fields[name] = { json_key: json_key, type: type, formatter: block }
        attr_accessor name
      end

      def self.date_field(name, json_key = nil)
        field(name, json_key, type: :date)
      end

      def self.from_json(api_client, data)
        return nil unless data
        instance = new(data, api_client)
        instance.populate_from_json(data)
        instance
      end

      def self.from_json_list(api_client, data_list)
        return [] unless data_list
        data_list.map { |data| from_json(api_client, data) }
      end

      def initialize(data = {}, api_client = nil)
        @data = data
        @api_client = api_client
      end

      def populate_from_json(data)
        self.class.fields.each do |name, config|
          json_key = config[:json_key]
          type = config[:type]
          formatter = config[:formatter]
          
          value = data[json_key]
          
          # Apply type conversion
          value = case type
                  when :date
                    parse_date(value)
                  when :boolean
                    parse_boolean(value)
                  else
                    value
                  end
          
          # Apply custom formatter if provided
          value = formatter.call(value) if formatter && value
          
          instance_variable_set("@#{name}", value)
        end
      end

      def to_h
        hash = {}
        self.class.fields.each do |name, _|
          hash[name] = instance_variable_get("@#{name}")
        end
        hash
      end

      def inspect
        attrs = self.class.fields.keys.map do |name|
          value = instance_variable_get("@#{name}")
          "#{name}=#{value.inspect}"
        end.join(' ')
        "#<#{self.class.name} #{attrs}>"
      end

      private

      def parse_date(value)
        return nil unless value
        if value.is_a?(Hash) && value['time']
          Time.at(value['time'] / 1000.0).utc
        elsif value.is_a?(Numeric)
          Time.at(value / 1000.0).utc
        else
          value
        end
      end

      def parse_boolean(value)
        case value
        when true, false
          value
        when 'true', '1', 1
          true
        when 'false', '0', 0
          false
        else
          value
        end
      end
    end

    # Base class for collections of models
    class Collection < Base
      include Enumerable

      def initialize(data = {}, api_client = nil)
        super
        @items = []
      end

      def <<(item)
        @items << item
      end

      def [](index)
        @items[index]
      end

      def each(&block)
        @items.each(&block)
      end

      def length
        @items.length
      end
      alias_method :size, :length
      alias_method :count, :length

      def empty?
        @items.empty?
      end

      def first
        @items.first
      end

      def last
        @items.last
      end

      def to_a
        @items
      end
    end

    # PandoraModel base class similar to Python implementation
    class PandoraModel
      def self.fields
        @fields ||= {}
      end

      def self.field(name, json_key = nil, type: nil, &block)
        json_key ||= name.to_s
        fields[name] = { json_key: json_key, type: type, formatter: block }
        attr_accessor name
      end

      def self.date_field(name, json_key = nil)
        field(name, json_key, type: :date)
      end

      def self.from_json(api_client, data)
        return nil unless data
        instance = new(api_client)
        instance.populate_from_json(data)
        instance
      end

      def self.from_json_list(api_client, data_list)
        return [] unless data_list
        data_list.map { |data| from_json(api_client, data) }
      end

      def initialize(api_client)
        @api_client = api_client
      end

      def populate_from_json(data)
        self.class.fields.each do |name, config|
          json_key = config[:json_key]
          type = config[:type]
          formatter = config[:formatter]
          
          value = data[json_key]
          
          # Apply type conversion
          value = case type
                  when :date
                    parse_date(value)
                  when :boolean
                    parse_boolean(value)
                  else
                    value
                  end
          
          # Apply custom formatter if provided
          value = formatter.call(value) if formatter && value
          
          instance_variable_set("@#{name}", value)
        end
      end

      def to_h
        hash = {}
        self.class.fields.each do |name, _|
          hash[name] = instance_variable_get("@#{name}")
        end
        hash
      end

      def inspect
        attrs = self.class.fields.keys.map do |name|
          value = instance_variable_get("@#{name}")
          "#{name}=#{value.inspect}"
        end.join(' ')
        "#<#{self.class.name} #{attrs}>"
      end

      private

      def parse_date(value)
        return nil unless value
        if value.is_a?(Hash) && value['time']
          Time.at(value['time'] / 1000.0).utc
        elsif value.is_a?(Numeric)
          Time.at(value / 1000.0).utc
        else
          value
        end
      end

      def parse_boolean(value)
        case value
        when true, false
          value
        when 'true', '1', 1
          true
        when 'false', '0', 0
          false
        else
          value
        end
      end
    end

    # List Model for indexed collections
    class PandoraListModel < PandoraModel
      include Enumerable

      def self.from_json(api_client, data)
        instance = new(api_client)
        instance.populate_from_json(data)

        # Extract the list items
        list_key = instance.class.list_key
        list_model = instance.class.list_model
        
        if list_key && list_model && data[list_key]
          items = list_model.from_json_list(api_client, data[list_key])
          instance.instance_variable_set(:@items, items)
          
          # Create index if specified
          if instance.class.index_key
            index = {}
            items.each { |item| index[item.send(instance.class.index_key)] = item }
            instance.instance_variable_set(:@index, index)
          end
        else
          instance.instance_variable_set(:@items, [])
          instance.instance_variable_set(:@index, {})
        end

        instance
      end

      def self.list_key
        @list_key
      end

      def self.list_model
        @list_model
      end

      def self.index_key
        @index_key
      end

      def self.set_list_config(list_key:, list_model:, index_key: nil)
        @list_key = list_key
        @list_model = list_model
        @index_key = index_key
      end

      def initialize(api_client)
        super(api_client)
        @items = []
        @index = {}
      end

      def each(&block)
        @items.each(&block)
      end

      def [](key)
        if key.is_a?(Integer)
          @items[key]
        else
          @index[key] if @index
        end
      end

      def []=(index, value)
        @items[index] = value if index.is_a?(Integer)
      end

      def size
        @items.size
      end

      def length
        @items.length
      end

      def empty?
        @items.empty?
      end
    end

    # Dictionary List Model
    # For models that have both array and hash-like access patterns
    class PandoraDictListModel < PandoraListModel
      # Additional dictionary-like methods can be added here
    end

    # Date Field similar to Python implementation
    class DateField
      attr_reader :field

      def initialize(field)
        @field = field
      end

      def formatter(api_client, data, value)
        return nil unless value
        return nil if value.is_a?(Hash) && value.empty?
        
        if value.is_a?(Hash) && value["time"]
          Time.at(value["time"] / 1000.0).utc
        elsif value.is_a?(Numeric)
          Time.at(value / 1000.0).utc
        else
          value
        end
      end
    end
  end
end