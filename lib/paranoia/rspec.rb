require 'rspec/expectations'

# Validate the subject's class did call "acts_as_paranoid"
RSpec::Matchers.define :act_as_paranoid do
  match { |subject| subject.class.ancestors.include?(Paranoia) }

  failure_message_proc = lambda do
    "expected #{subject.class} to use `acts_as_paranoid`"
  end

  failure_message_when_negated_proc = lambda do
    "expected #{subject.class} not to use `acts_as_paranoid`"
  end

  if respond_to?(:failure_message_when_negated)
    failure_message(&failure_message_proc)
    failure_message_when_negated(&failure_message_when_negated_proc)
  else
    # RSpec 2 compatibility:
    failure_message_for_should(&failure_message_proc)
    failure_message_for_should_not(&failure_message_when_negated_proc)
  end
end
