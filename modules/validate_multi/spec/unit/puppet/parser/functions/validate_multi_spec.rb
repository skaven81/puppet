#! /usr/bin/env/ruby -S rspec

require 'spec_helper'

describe Puppet::Parser::Functions.function(:validate_multi) do
  let(:scope) { PuppetlabsSpec::PuppetInternals.scope }
  describe 'when calling validate_multi from puppet' do

    it "should not compile when less than 2 arguments" do
      Puppet[:code] = "validate_multi('one arg')"
      expect { scope.compiler.compile }.to raise_error(Puppet::ParseError, /must be 2 or more/)
    end

    it "should not compile when validators are not provided as strings" do
      Puppet[:code] = "validate_multi('data',true)"
      expect { scope.compiler.compile }.to raise_error(Puppet::ParseError, /validator names must be strings/)
    end

    it "should not compile when one of the validators cannot be found" do
      Puppet[:code] = "validate_multi('data', 'not_a_real_validator_and_never_should_be')"
      expect { scope.compiler.compile }.to raise_error(Puppet::ParseError, /cannot be found, cannot perform validation/)
    end

    it "should not compile when all of the validators fails" do
      # none of these validators will validate this value
      Puppet[:code] = "validate_multi('a_string','array','bool')"
      expect { scope.compiler.compile }.to raise_error(Puppet::ParseError)
    end

    it "should compile when at least one of the validators passes" do
      Puppet[:code] = "validate_multi(true,'string','bool')"
      scope.compiler.compile
    end
  end
end
