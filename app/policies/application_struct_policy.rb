class ApplicationStructPolicy

  def self.new(*args)
    klass = Struct.new(*args)
    klass.class_eval do
      define_method :method_missing do |name, *opts|
        attrs = args.map{|arg| self.send arg}
        app_policy = ApplicationPolicy.new(*attrs)
        if name.to_sym == :auth
          method = opts.first || caller_locations(1,1)[0].label
          app_policy.auth(method, self)
        else
          app_policy.send(name, *opts)
        end
      end

      define_singleton_method :method_missing do |name, *opts|
        ApplicationPolicy.send(name, *opts)
      end
    end
    klass
  end

end
