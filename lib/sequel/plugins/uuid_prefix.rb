# -*- coding: utf-8 -*-

require 'sequel/plugins/after_initialize'

module Sequel
  module Plugins
    # Sequel::Model plugin to inject the UUIDPrefix feature to the model
    # class.
    #
    # UUIDPrefix model supports the features below:
    # - UUIDPrefix.uuid_prefix to both set and get uuid_prefix for the model.
    # - Collision detection for specified uuid_prefix.
    # - Generate unique value for :uuid column at initialization.
    # - Add column :uuid if the model is capable of :schema plugin methods.
    module UUIDPrefix
      UUID_TABLE='abcdefghijklmnopqrstuvwxyz0123456789'.split('').freeze
      UUID_REGEX=%r/^(\w+)-([#{UUID_TABLE.join}]+)/

      class InvalidUUIDError < StandardError; end
      class UUIDPrefixDuplication < StandardError; end
      class UUIDDuplication < StandardError; end
      class UnsetUUIDPrefix < StandardError; end

      def self.apply(model, _options = {})
        model.plugin Sequel::Plugins::AfterInitialize
      end

      def self.uuid_prefix_collection
        @uuid_prefix_collection ||= {}
      end

      # Find a model with an prefixed uuid object from the
      # given canonical uuid.
      #
      # # Find an account.
      # UUIDPrefix.find('a-xxxxxxxx')
      #
      # # Find a user.
      # UUIDPrefix.find('u-xxxxxxxx')
      def self.find(uuid)
        raise ArgumentError, "Invalid uuid syntax: #{uuid}" unless uuid =~ UUID_REGEX
        upc = uuid_prefix_collection[$1.downcase]
        raise "Unknown uuid prefix: #{$1.downcase}" if upc.nil?
        upc[:class].find(:uuid=>$2)
      end

      # Checks if the uuid object stored in the database.
      def self.exists?(uuid)
        !find(uuid).nil?
      end

      def self.configure(model)
        model.schema_builders << proc {
          unless has_column?(:uuid)
            # add :uuid column with unique index constraint.
            column(:uuid, String, :size=>8, :null=>false, :fixed=>true, :unique=>true)
          end
        }
      end

      module InstanceMethods
        # read-only instance method to retrieve @uuid_prefix class
        # variable.
        def uuid_prefix
          self.class.uuid_prefix
        end

        def before_validation
          # trim uuid prefix if it is in the self[:uuid]
          self[:uuid].sub!(/^#{self.class.uuid_prefix}-/, '')

          super
        end

        def before_create
          if !self.class.find(:uuid=>self[:uuid]).nil?
            raise UUIDDuplication, "Duplicate UUID: #{self.canonical_uuid} already exists"
          end

          super
        end

        def after_initialize
          super
          # set random generated uuid value
          self[:uuid] ||= Array.new(8) do UUID_TABLE[rand(UUID_TABLE.size)]; end.join
        end

        # Returns canonicalized uuid which has the form of
        # "{uuid_prefix}-{uuid}".
        def canonical_uuid
          "#{self.uuid_prefix}-#{self[:uuid]}"
        end
        alias_method :cuuid, :canonical_uuid

        def to_hash()
          r = self.values.dup.merge({id: self.id,
                                     uuid: canonical_uuid,
                                     class_name: self.class.name.demodulize
                                   })

          serialize_columns = []

          if defined? Sequel::Plugins::Serialization
            if self.class.plugins.member?(Sequel::Plugins::Serialization)
              self.class.deserialization_map.keys.each { |c|
                serialize_columns << c
                r[c] = self.__send__(c)
              }
            end
          end

          # convert Sequel::SQL::Blob column.
          # TODO: look for alternative method to stop to retrieve
          #       db_schema hash.
          self.class.db_schema.each { |c, v|
            if v[:db_type] == 'text' && v[:type] == :string && !serialize_columns.member?(c)
              r[c] = self.__send__(c).to_s
            end
          }
          r
        end

        # generate API response document. similar to to_hash() but not
        # to expose integer primary key.
        def to_api_document
          self.values.dup.merge({:id=>self.canonical_uuid, :uuid=>canonical_uuid})
        end
      end

      module ClassMethods
        # Getter and setter for uuid_prefix of the class.
        #
        # @example
        #   class Model1 < Sequel::Model
        #     plugin UUIDPrefix
        #     uuid_prefix('m')
        #   end
        #
        #   Model1.uuid_prefix # == 'm'
        #   Model1.new.canonical_uuid # == 'm-abcd1234'
        def uuid_prefix(prefix=nil)
          if prefix
            if UUIDPrefix.uuid_prefix_collection.has_key?(prefix)
              raise UUIDPrefixDuplication, "Found collision for uuid_prefix key: #{prefix}"
            end

            UUIDPrefix.uuid_prefix_collection[prefix]={:class=>self}
            @uuid_prefix = prefix
          end

          @uuid_prefix ||
            (superclass.uuid_prefix if superclass.respond_to?(:uuid_prefix)) ||
            raise(UnsetUUIDPrefix, "uuid prefix is unset for: #{self}")
        end


        # Override Model.[] to add lookup by uuid.
        #
        # @example
        #   Account['a-xxxxxx']
        def [](*args)
          if args.size == 1 and args[0].is_a? String
            super(:uuid=>trim_uuid(args[0]))
          else
            super(*args)
          end
        end

        # Returns dataset which has been selected for the uuid.
        #
        # @example
        #   Account.dataset_where_uuid('a-xxxxxx')
        def dataset_where_uuid(p_uuid)
          dataset.where(uuid: trim_uuid(p_uuid))
        end

        # Returns the uuid string which is removed prefix part: /^(:?\w+)-/.
        #
        # @example
        #   Account.trim_uuid('a-abcd1234') # = 'abcd1234'
        # @example Will get InvalidUUIDError as the uuid with invalid prefix has been tried.
        #   Account.trim_uuid('u-abcd1234') # 'u-' prefix is for User model.
        def trim_uuid(p_uuid)
          regex = %r/^#{self.uuid_prefix}-/
          if p_uuid and p_uuid =~ regex
            return p_uuid.sub(regex, '')
          end
          raise InvalidUUIDError, "Invalid uuid or unsupported uuid: #{p_uuid} in #{self}"
        end

        # Checks the general uuid syntax
        def check_trimmed_uuid_format(uuid)
          uuid.match(/^[\w]+$/) && uuid.length <= 255
        end

        # Checks the uuid syntax if it is for the UUIDPrefix class.
        def check_uuid_format(uuid)
          uuid =~ /^#{self.uuid_prefix}-/
        end

        def valid_uuid_syntax?(uuid)
          uuid =~ /^#{self.uuid_prefix}-[\w]+/
        end
      end

    end
  end
end
