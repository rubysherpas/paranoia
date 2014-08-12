require 'rspec/expectations'

# Validate the subject's class did call "acts_as_paranoid"
RSpec::Matchers.define :act_as_paranoid do
  match { |subject| subject.class.ancestors.include?(Paranoia) }

  failure_message { "expected #{subject.class} to use `acts_as_paranoid`" }
  failure_message_when_negated { "expected #{subject.class} not to use `acts_as_paranoid`" }

  # RSpec 2 compatibility:
  alias_method :failure_message_for_should, :failure_message
  alias_method :failure_message_for_should_not, :failure_message_when_negated
end
