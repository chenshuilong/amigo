
module Redmine
  module Acts
    module Task
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_task(options = {})
          cattr_accessor :task_options
          self.task_options = {}
          task_options[:view_permission] = options.delete(:view_permission) || "view_#{self.name.pluralize.underscore}".to_sym
          task_options[:edit_permission] = options.delete(:edit_permission) || "edit_#{self.name.pluralize.underscore}".to_sym
          task_options[:delete_permission] = options.delete(:delete_permission) || "edit_#{self.name.pluralize.underscore}".to_sym

          has_many :tasks, lambda {order("tasks.created_at ASC, tasks.id ASC")},
                   options.merge(:as => :container, :dependent => :destroy, :inverse_of => :container)
          send :include, Redmine::Acts::Task::InstanceMethods
          before_save :attach_saved_tasks
          validate :warn_about_failed_tasks
        end
      end

      module InstanceMethods
        def self.included(base)
          base.extend ClassMethods
        end

        def tasks_visible?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
              user.allowed_to?(self.class.task_options[:view_permission], self.project)
        end

        def tasks_editable?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
              user.allowed_to?(self.class.task_options[:edit_permission], self.project)
        end

        def tasks_deletable?(user=User.current)
          (respond_to?(:visible?) ? visible?(user) : true) &&
              user.allowed_to?(self.class.task_options[:delete_permission], self.project)
        end

        def saved_tasks
          @saved_tasks ||= []
        end

        def unsaved_tasks
          @unsaved_tasks ||= []
        end

        def save_tasks(tasks, author=User.current)
          if tasks.is_a?(Array)
            @failed_task_count = 0
            tasks.each do |task|
              next unless task.is_a?(Hash)
              a = nil
              if name = task['name']
                a = Task.find_by_name(name)
                a = Task.create(:name => name, :author => author) if a.blank?
                unless a
                  @failed_task_count += 1
                  next
                end
              end
              next unless a
              a.description = task['description'].to_s.strip
              a.assigned_to_id = task['assigned_to_id'].to_s.strip
              a.save
              if a.new_record?
                unsaved_tasks << a
              else
                saved_tasks << a
              end
            end
          end
          {:tasks => saved_tasks, :unsaved => unsaved_tasks}
        end

        def attach_saved_tasks
          saved_tasks.each do |task|
            self.tasks << task
          end
        end

        def warn_about_failed_tasks
          if @failed_task_count && @failed_task_count > 0
            errors.add :base, ::I18n.t('warning_tasks_not_saved', count: @failed_task_count)
          end
        end

        module ClassMethods
        end
      end
    end
  end
end
