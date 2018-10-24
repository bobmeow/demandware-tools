require 'nokogiri'
require 'csv'

class DemandwareParser
  def initialize(file_name)
    @file = File.open(file_name)
    @export_csv = file_name.gsub(/\.xml/, '_from_xml.csv')
    @count = 0
    @regz_headers = "order-date,created-by,original-order-no,currency,customer customer-no,customer customer-name,customer customer-email,customer billing-address first-name,customer billing-address last-name,customer billing-address address1,customer billing-address address2,customer billing-address city,customer billing-address postal-code,customer billing-address state-code,customer billing-address country-code,customer billing-address phone,status order-status,status shipping-status,status confirmation-status,status payment-status,shipment shipping-method,shipping-address first-name,shipping-address last-name,shipping-address address1,shipping-address address2,shipping-address city,shipping-address postal-code,shipping-address state-code,shipping-address country-code,shipping-address phone,totals order-total gross-price,totals shipping-total gross-price".split(/,/)
    @prod_headers = "product gross-price,product product-id,product product-name,product lineitem-text,product quantity,product recipient-email".split(/,/)
    @payment_headers = "payment source,payment processor-id,payment card-type,payment card-number,payment card-holder".split(/,/)
    @custom_headers = "verified,AVSResponse,ccAuthCode,cvvResponse,paymentToken,BrowserAccept,BrowserID,CustomerIPAddress,BrowserIdLanguageCode".split(/,/)
    @merged_headers = @regz_headers + @prod_headers + @payment_headers + @custom_headers
  end

  def custom_attribute(order, attribute)
    value = ""
    attr_check = order.css("custom-attribute").find { | item | item.attributes["attribute-id"].value == attribute }
    attr_check.nil? ? '' : attr_check.content
  end

  def field_check(order, attribute)
    (!order.css(attribute).empty? ? order.css(attribute).first.content : "")
  end

  def fill_in_fields(order, product)
    csv_arr = @regz_headers.map{|header| field_check(order, header)}
    csv_arr += @prod_headers.map{|header| field_check(product, header.split(/\s/)[1])}
    payment = order.css("payment").first
    if !order.css("payment").empty?
      csv_arr << if !payment.css("credit-card").empty?
                   "Credit Card"
                 else
                   if !payment.css("gift-certificate").empty?
                     "Gift Certificate"
                   else
                     field_check(payment, "method-name")
                   end
                 end

      csv_arr += @payment_headers[1..-1].map{|header| field_check(payment, header.split(/\s/)[1])}
    else
      @payment_headers.length.times { csv_arr << '' }
    end
    @custom_headers.each { |custy| csv_arr << custom_attribute(order, custy) }
    CSV.open(@export_csv, "a") { |csv| csv << csv_arr }
  end


  def main_parser(string)
    Nokogiri::XML(string).css("order").each do |order|
      puts @count += 1
      order.css("product-lineitem").each do |product|
        fill_in_fields(order, product)
      end
      order.css("giftcertificate-lineitem").each do |product|
        fill_in_fields(order, product)
      end
    end
  end


  def start_streamer
    CSV.open(@export_csv, "a") { |csv| csv << @merged_headers }
    string = ''
    @file.each do |line|
      if line.match /<order .*>/
        string = ''
        string << line
      elsif line.match /<\/order>/
        string << line
        main_parser(string)
      else
        string << line
      end
    end
  end
end
