module PolicyControl

  class << self
    def map
      mapper = Mapper.new
      yield mapper
      @permissions ||= []
      @permissions += mapper.mapped_permissions
    end

    def permissions
      @permissions
    end

    # Returns the permission of given name or nil if it wasn't found
    # Argument should be a symbol
    def permission(name)
      permissions.detect {|p| p.name == name}
    end

    # Returns the actions that are allowed by the permission of given name
    def allowed_actions(permission_name)
      perm = permission(permission_name)
      perm ? perm.actions : []
    end

    def read_action(action)
      permissions.select{|p| p.actions.include?(action)}
    end

    def read_action?(action)
      if action.is_a?(Symbol)
        perm = permission(action)
        !perm.nil? && perm.read?
      elsif action.is_a?(Hash)
        s = "#{action[:controller]}/#{action[:action]}"
        permissions.detect {|p| p.actions.include?(s) && p.read?}.present?
      else
        raise ArgumentError.new("Symbol or a Hash expected, #{action.class.name} given: #{action}")
      end
    end

    def available_blocks
      @available_blocks ||= @permissions.collect(&:block).uniq.compact
    end

    def modules_permissions(modules)
      @permissions.select {|p| p.block.nil? || modules.include?(p.block.to_s)}
    end
  end

  class Mapper
    def initialize
      @block = nil
    end

    def permission(name, hash, options={})
      @permissions ||= []
      options.merge!(:block => @block)
      @permissions << Permission.new(name, hash, options)
    end

    def block(name, options={})
      @block = name
      yield self
      @block = nil
    end

    def mapped_permissions
      @permissions
    end
  end

  class Permission
    attr_reader :name, :actions, :block, :label

    def initialize(name, hash, options)
      @name = name
      @actions = []
      @label = options[:label]
      @require = options[:require]
      @block = options[:block]
      hash.each do |block, actions|
        if actions.is_a? Array
          @actions << actions.collect {|action| "#{block}/#{action}"}
        else
          @actions << "#{block}/#{actions}"
        end
      end
      @actions.flatten!
    end

    def require_member?
      @require && @require == :member
    end

    def require_loggedin?
      @require && (@require == :member || @require == :loggedin)
    end
  end

end

