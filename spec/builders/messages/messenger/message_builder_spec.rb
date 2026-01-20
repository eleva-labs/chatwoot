require 'rails_helper'

describe Messages::Messenger::MessageBuilder do
  describe '#unsupported_file_type?' do
    subject(:builder) { described_class.new }

    it 'returns true for template attachment type' do
      expect(builder.send(:unsupported_file_type?, 'template')).to be true
      expect(builder.send(:unsupported_file_type?, :template)).to be true
    end

    it 'returns true for unsupported_type attachment type' do
      expect(builder.send(:unsupported_file_type?, 'unsupported_type')).to be true
      expect(builder.send(:unsupported_file_type?, :unsupported_type)).to be true
    end

    it 'returns true for ephemeral attachment type' do
      expect(builder.send(:unsupported_file_type?, 'ephemeral')).to be true
      expect(builder.send(:unsupported_file_type?, :ephemeral)).to be true
    end

    it 'returns false for image attachment type' do
      expect(builder.send(:unsupported_file_type?, 'image')).to be false
      expect(builder.send(:unsupported_file_type?, :image)).to be false
    end

    it 'returns false for video attachment type' do
      expect(builder.send(:unsupported_file_type?, 'video')).to be false
      expect(builder.send(:unsupported_file_type?, :video)).to be false
    end

    it 'returns false for audio attachment type' do
      expect(builder.send(:unsupported_file_type?, 'audio')).to be false
      expect(builder.send(:unsupported_file_type?, :audio)).to be false
    end

    it 'returns false for file attachment type' do
      expect(builder.send(:unsupported_file_type?, 'file')).to be false
      expect(builder.send(:unsupported_file_type?, :file)).to be false
    end

    it 'returns false for share attachment type' do
      expect(builder.send(:unsupported_file_type?, 'share')).to be false
      expect(builder.send(:unsupported_file_type?, :share)).to be false
    end

    it 'returns false for story_mention attachment type' do
      expect(builder.send(:unsupported_file_type?, 'story_mention')).to be false
      expect(builder.send(:unsupported_file_type?, :story_mention)).to be false
    end

    it 'returns false for ig_reel attachment type' do
      expect(builder.send(:unsupported_file_type?, 'ig_reel')).to be false
      expect(builder.send(:unsupported_file_type?, :ig_reel)).to be false
    end

    it 'returns false for location attachment type' do
      expect(builder.send(:unsupported_file_type?, 'location')).to be false
      expect(builder.send(:unsupported_file_type?, :location)).to be false
    end

    it 'returns false for fallback attachment type' do
      expect(builder.send(:unsupported_file_type?, 'fallback')).to be false
      expect(builder.send(:unsupported_file_type?, :fallback)).to be false
    end
  end
end
