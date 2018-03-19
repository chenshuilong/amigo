
module Redmine
  module Acts
    module Recordable
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_recordable(options = {})
          cattr_accessor :records_options
          self.records_options = {}
          records_options[:view_permission] = options.delete(:view_permission) || "view_#{self.name.pluralize.underscore}".to_sym
          records_options[:edit_permission] = options.delete(:edit_permission) || "edit_#{self.name.pluralize.underscore}".to_sym
          records_options[:delete_permission] = options.delete(:delete_permission) || "edit_#{self.name.pluralize.underscore}".to_sym

          has_many :alter_records, lambda {order("alter_records.created_at ASC, alter_records.id ASC")},
                   options.merge(:as => :alter_for, :dependent => :destroy, :inverse_of => :alter_for)
          send :include, Redmine::Acts::Recordable::InstanceMethods
          validate :warn_about_failed_records
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        def records_visible?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
              user.allowed_to?(self.class.task_options[:view_permission], self.project)
        end

        def records_editable?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
              user.allowed_to?(self.class.task_options[:edit_permission], self.project)
        end

        def records_deletable?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
              user.allowed_to?(self.class.task_options[:delete_permission], self.project)
        end

        def warn_about_failed_records
          if @failed_records_count && @failed_records_count > 0
            errors.add :base, ::I18n.t('warning_records_not_saved', count: @failed_records_count)
          end
        end

        module ClassMethods
        end
      end
    end
  end
end
