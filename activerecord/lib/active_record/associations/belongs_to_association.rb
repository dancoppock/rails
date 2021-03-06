module ActiveRecord
  # = Active Record Belongs To Associations
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        replace(@reflection.create_association(attributes))
      end

      def build(attributes = {})
        replace(@reflection.build_association(attributes))
      end

      def replace(record)
        record = record.target if AssociationProxy === record
        raise_on_type_mismatch(record) unless record.nil?

        update_counters(record)
        replace_keys(record)
        set_inverse_instance(record)

        @target  = record
        @updated = true if record

        loaded
        record
      end

      def updated?
        @updated
      end

      def stale_target?
        if @target && @target.persisted?
          target_id   = @target[@reflection.association_primary_key].to_s
          foreign_key = @owner[@reflection.foreign_key].to_s

          target_id != foreign_key
        else
          false
        end
      end

      private
        def update_counters(record)
          counter_cache_name = @reflection.counter_cache_column

          if counter_cache_name && @owner.persisted? && different_target?(record)
            if record
              record.class.increment_counter(counter_cache_name, record.id)
            end

            if foreign_key_present
              target_klass.decrement_counter(counter_cache_name, target_id)
            end
          end
        end

        # Checks whether record is different to the current target, without loading it
        def different_target?(record)
          record.nil? && @owner[@reflection.foreign_key] ||
          record.id   != @owner[@reflection.foreign_key]
        end

        def replace_keys(record)
          @owner[@reflection.foreign_key] = record && record[@reflection.association_primary_key]
        end

        def find_target
          if foreign_key_present
            scoped.first.tap { |record| set_inverse_instance(record) }
          end
        end

        def construct_find_scope
          {
            :conditions => construct_conditions,
            :select     => @reflection.options[:select],
            :include    => @reflection.options[:include],
            :readonly   => @reflection.options[:readonly]
          }
        end

        def construct_conditions
          conditions = aliased_table[@reflection.association_primary_key].
                       eq(@owner[@reflection.foreign_key])

          conditions = conditions.and(Arel.sql(sql_conditions)) if sql_conditions
          conditions
        end

        def foreign_key_present
          !@owner[@reflection.foreign_key].nil?
        end

        # NOTE - for now, we're only supporting inverse setting from belongs_to back onto
        # has_one associations.
        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && inverse.macro == :has_one
        end

        def target_id
          if @reflection.options[:primary_key]
            @owner.send(@reflection.name).try(:id)
          else
            @owner[@reflection.foreign_key]
          end
        end
    end
  end
end
