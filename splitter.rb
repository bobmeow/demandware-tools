class DemandwareSplitter
  def initialize(file_name)
    @file_name = file_name
    @order_count = 0
  end

  def start_streamer
    puts "hi"
    print "\r"
    print "start"
    file = File.open(@file_name)
    stream_thru(file)
    file.close
  end

  def stream_thru(file)
    order_string = ''
    output_name = ''
    file.each do |line|
      case line
      when /<orders .*>|<\?xml.*>|<\/orders>/
        next
      when /<order .*>/
        @order_count += 1
        print "\r"
        print @order_count
        order_string.clear
        order_string << line
      when /<order-date>/
        output_name = "#{@file_name.split('.')[0]}--#{line.match /\d{4}-\d{2}/}.xml"
        order_string << line
      when /<\/order>/
        order_string << line
        File.open(output_name, 'a') do |write_file|
          write_file << order_string
        end
      else
        order_string << line
      end
    end
  end
end
