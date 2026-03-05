# frozen_string_literal: true

namespace :instagram do
  desc 'Re-subscribe all active Instagram channels to include messaging_deliveries'
  task resubscribe: :environment do
    channels = Channel::Instagram.all
    puts "Re-subscribing #{channels.count} channel(s)..."

    channels.find_each do |channel|
      print "  channel id=#{channel.id} instagram_id=#{channel.instagram_id} ... "
      channel.subscribe
      puts 'done'
      sleep 0.1
    rescue StandardError => e
      puts "FAILED: #{e.message}"
    end

    puts 'Re-subscription complete.'
  end
end
