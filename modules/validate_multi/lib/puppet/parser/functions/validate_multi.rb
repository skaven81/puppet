module Puppet::Parser::Functions
  newfunction( :validate_multi, :doc => <<-'ENDHEREDOC') do |args|
    Validate that the first argument given can pass validation of at least one
    other validator from the puppetlabs/stdlib library. The first argument is
    the data that needs validation. Each argument following should be the data
    type suffix from a validator function. The suffix should be in the form of
    a string. The passed data will then be validated against each validation
    function listed.

    The following validations will pass:

      validate_multi("I am a string",'string','array')
      validate_multi(true,'hash','bool')

    The following validations will not:

      validate_multi(false,'string','array')
      validate_multi('I am a string','hash','array')

    ENDHEREDOC

    # Validate Arguments
    if args.size < 2
      raise Puppet::ParseError, "validate_multi(): Wrong number of arguments (#{args.size}; must be 2 or more)"
    end

    # clean up our inputs to make way for MORE VALIDATION
    puppet_variable = args.shift
    args.flatten!

    # MORE VALIDATION
    args.each do |arg|
      unless arg.is_a? String
        raise Puppet::ParseError, "validate_multi(): validator names must be strings, recieved #{arg.inspect}"
      end
    end

    # Track state of validations
    failures = Array.new
    clean = false

    # Validate against each individual validator
    args.each do |validator|
      unless Puppet::Parser::Functions.function("validate_#{validator}")
        raise Puppet::ParseError, "validate_multi(): validator function \"validate_#{validator}()\" cannot be found, cannot perform validation"
      end

      begin
        self.send("function_validate_#{validator}", [puppet_variable])
      rescue Puppet::ParseError => err
        failures << err.message
      else
        clean = true
      end
    end

    # If we have not cleared at least one validation, we are now in failure state
    unless clean
      msg = "validate_multi(): failed to pass the following validations with the following errors\n"
      failures.each do |failed|
        msg += "    --- #{failed}\n"
      end
      raise Puppet::ParseError, msg
    end
  end
end
