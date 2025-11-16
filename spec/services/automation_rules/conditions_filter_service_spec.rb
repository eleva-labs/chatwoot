require 'rails_helper'

RSpec.describe AutomationRules::ConditionsFilterService do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:email_channel) { create(:channel_email, account: account) }
  let(:email_inbox) { create(:inbox, channel: email_channel, account: account) }
  let(:message) do
    create(:message, account: account, conversation: conversation, content: 'test text', inbox: conversation.inbox, message_type: :incoming)
  end
  let(:rule) { create(:automation_rule, account: account) }

  before do
    conversation = create(:conversation, account: account)
    conversation.contact.update(phone_number: '+918484828282', email: 'test@test.com')
    create(:conversation, account: account)
    create(:conversation, account: account)
  end

  describe '#perform' do
    context 'when conditions based on filter_operator equal_to' do
      before do
        rule.conditions = [{ 'values': ['open'], 'attribute_key': 'status', 'query_operator': nil, 'filter_operator': 'equal_to' }]
        rule.save
      end

      context 'when conditions in rule matches with object' do
        it 'will return true' do
          expect(described_class.new(rule, conversation, { changed_attributes: { status: [nil, 'open'] } }).perform).to be(true)
        end
      end

      context 'when conditions in rule does not match with object' do
        it 'will return false' do
          conversation.update(status: 'resolved')
          expect(described_class.new(rule, conversation, { changed_attributes: { status: %w[open resolved] } }).perform).to be(false)
        end
      end
    end

    context 'when conditions based on filter_operator start_with' do
      before do
        contact = conversation.contact
        contact.update(phone_number: '+918484848484')
        rule.conditions = [
          { 'values': ['+918484'], 'attribute_key': 'phone_number', 'query_operator': 'OR', 'filter_operator': 'starts_with' },
          { 'values': ['test'], 'attribute_key': 'email', 'query_operator': nil, 'filter_operator': 'contains' }
        ]
        rule.save
      end

      context 'when conditions in rule matches with object' do
        it 'will return true' do
          expect(described_class.new(rule, conversation, { changed_attributes: {} }).perform).to be(true)
        end
      end

      context 'when conditions in rule does not match with object' do
        it 'will return false' do
          conversation.contact.update(phone_number: '+918585858585')
          expect(described_class.new(rule, conversation, { changed_attributes: {} }).perform).to be(false)
        end
      end
    end

    context 'when conditions based on messages attributes' do
      context 'when filter_operator is equal_to' do
        before do
          rule.conditions = [
            { 'values': ['test text'], 'attribute_key': 'content', 'query_operator': 'AND', 'filter_operator': 'equal_to' },
            { 'values': ['incoming'], 'attribute_key': 'message_type', 'query_operator': nil, 'filter_operator': 'equal_to' }
          ]
          rule.save
        end

        it 'will return true when conditions matches' do
          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(true)
        end

        it 'will return false when conditions in rule does not match' do
          message.update!(message_type: :outgoing)
          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(false)
        end
      end

      context 'when filter_operator is on processed_message_content' do
        before do
          rule.conditions = [
            { 'values': ['help'], 'attribute_key': 'content', 'query_operator': 'AND', 'filter_operator': 'contains' },
            { 'values': ['incoming'], 'attribute_key': 'message_type', 'query_operator': nil, 'filter_operator': 'equal_to' }
          ]
          rule.save
        end

        let(:conversation) { create(:conversation, account: account, inbox: email_inbox) }
        let(:message) do
          create(:message, account: account, conversation: conversation, content: "We will help you\n\n\n test",
                           inbox: conversation.inbox, message_type: :incoming,
                           content_attributes: { email: { text_content: { quoted: 'We will help you' } } })
        end

        it 'will return true for processed_message_content matches' do
          message
          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(true)
        end

        it 'will return false when processed_message_content does no match' do
          rule.update(conditions: [{ 'values': ['text'], 'attribute_key': 'content', 'query_operator': nil, 'filter_operator': 'contains' }])

          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(false)
        end
      end

      context 'when filtering messages based on conversation attributes' do
        let(:conversation) { create(:conversation, account: account, status: :open, priority: :high) }
        let(:message) do
          create(:message, account: account, conversation: conversation, content: 'Test message',
                           inbox: conversation.inbox, message_type: :incoming)
        end

        it 'will return true when conversation status matches' do
          rule.update(conditions: [{ 'values': ['open'], 'attribute_key': 'status', 'query_operator': nil, 'filter_operator': 'equal_to' }])
          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(true)
        end

        it 'will return false when conversation status does not match' do
          rule.update(conditions: [{ 'values': ['resolved'], 'attribute_key': 'status', 'query_operator': nil, 'filter_operator': 'equal_to' }])
          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(false)
        end

        it 'will return true when conversation priority matches' do
          rule.update(conditions: [{ 'values': ['high'], 'attribute_key': 'priority', 'query_operator': nil, 'filter_operator': 'equal_to' }])
          expect(described_class.new(rule, conversation, { message: message, changed_attributes: {} }).perform).to be(true)
        end
      end
    end

    context 'when conditions based on entry_phrase with multiple conditions' do
      it 'evaluates each entry_phrase condition independently with unique cache keys' do
        # Create initial messages
        create(:message, conversation: conversation, content: 'hello there', message_type: :incoming)
        create(:message, conversation: conversation, content: 'necesito ayuda', message_type: :incoming)

        # Create automation rule with two entry_phrase conditions connected by OR
        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'OR'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['ayuda'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        # Execute the service
        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform

        # Should match because first condition finds 'hello'
        expect(result).to be(true)

        # Verify that both conditions created unique cache keys
        conversation.reload
        cache_keys = conversation.custom_attributes.keys.select { |k| k.start_with?('ai_auto_phrase_') }

        # Should have cache keys for both conditions (2 keys each: _checked and _passed)
        expect(cache_keys.length).to be >= 2
        expect(cache_keys.uniq.length).to eq(cache_keys.length) # All cache keys should be unique
      end

      it 'creates independent cache entries for each condition' do
        # Create message that matches both conditions
        create(:message, conversation: conversation, content: 'hello there, necesito ayuda', message_type: :incoming)

        # Create automation rule with two entry_phrase conditions
        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'AND'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['ayuda'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        # Execute the service
        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform

        # Should match because both conditions find their phrases
        expect(result).to be(true)

        # Verify cache stores different entries for each condition
        conversation.reload
        cache_entries = conversation.custom_attributes.select { |k, _v| k.start_with?('ai_auto_phrase_') }

        # Should have entries for both conditions (each creates checked + passed keys)
        expect(cache_entries.keys.length).to be >= 2

        # Verify both results are stored independently
        passed_keys = cache_entries.keys.select { |k| k.end_with?('_passed') }
        expect(passed_keys.length).to eq(2)
        passed_keys.each do |key|
          expect(cache_entries[key]).to be(true)
        end
      end
    end

    context 'when testing OR logic between conditions' do
      it 'passes when first condition matches (A OR B, only A true)' do
        create(:message, conversation: conversation, content: 'hello there', message_type: :incoming)

        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'OR'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['nonexistent'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform
        expect(result).to be(true)
      end

      it 'passes when second condition matches (A OR B, only B true)' do
        create(:message, conversation: conversation, content: 'necesito ayuda', message_type: :incoming)

        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'OR'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['ayuda'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform
        expect(result).to be(true)
      end

      it 'passes when both conditions match (A OR B, both true)' do
        create(:message, conversation: conversation, content: 'hello, necesito ayuda', message_type: :incoming)

        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'OR'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['ayuda'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform
        expect(result).to be(true)
      end

      it 'fails when neither condition matches (A OR B, both false)' do
        create(:message, conversation: conversation, content: 'goodbye', message_type: :incoming)

        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'OR'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['ayuda'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform
        expect(result).to be(false)
      end

      it 'evaluates mixed operators correctly: (false AND false) OR true = true' do
        create(:message, conversation: conversation, content: 'hello', message_type: :incoming)

        rule.conditions = [
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['goodbye'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'AND'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['nonexistent'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => 'OR'
          },
          {
            'attribute_key' => 'entry_phrase',
            'filter_operator' => 'contains',
            'values' => ['hello'],
            'custom_filters' => { 'message_limit' => 2, 'case_sensitive' => false },
            'query_operator' => nil
          }
        ]
        rule.save

        result = described_class.new(rule, conversation, { changed_attributes: {} }).perform
        expect(result).to be(true)
      end
    end
  end
end
