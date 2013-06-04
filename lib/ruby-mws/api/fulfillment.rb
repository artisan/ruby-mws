require 'builder'

module MWS
  module API

    class Fulfillment < Base
      include Feeds

      # Takes a hash of order and item details
      # Returns true if the order was acknowledged successfully
      # Otherwise raises an exception
      def order_acknowledgement(hash)
        # example use: order_acknowledgement(amazon_order_id: '112-2598432-0713054', merchant_order_id: 336, status: 'Success', items: {'47979057082330' => '438'})
        #              order_acknowledgement(amazon_order_id: '112-2598432-0713054', merchant_order_id: 336, status: 'Success')
        # order acknowledgment is done by sending an XML "feed" to Amazon
        # as of this writing, XML schema docs are available at:
        # https://images-na.ssl-images-amazon.com/images/G/01/rainier/help/XML_Documentation_Intl.pdf
        # https://images-na.ssl-images-amazon.com/images/G/01/mwsportal/doc/en_US/bde/MWSFeedsApiReference._V372272627_.pdf
        xml     = ""
        builder = Builder::XmlMarkup.new(:indent => 2, :target => xml)
        builder.instruct! # <?xml version="1.0" encoding="UTF-8"?>
        builder.AmazonEnvelope(:"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", :"xsi:noNamespaceSchemaLocation" => "amzn-envelope.xsd") do |env|
          env.Header do |head|
            head.DocumentVersion('1.01')
            head.MerchantIdentifier(@connection.seller_id)
          end
          env.MessageType('OrderAcknowledgement')
          env.Message do |mes|
            mes.MessageID('1')
            mes.OrderAcknowledgement do |oa|
              oa.AmazonOrderID(hash[:amazon_order_id])
              oa.MerchantOrderID(hash[:merchant_order_id]) unless hash[:merchant_order_id].blank?
              oa.StatusCode(hash[:status])
              (hash[:items] || {}).each do |item_code, merchant_item_id|
                oa.Item do |item|
                  item.AmazonOrderItemCode(item_code)
                  item.MerchantOrderItemID(merchant_item_id) unless merchant_item_id.blank?
                end
              end
            end
          end
        end

        submit_feed('_POST_ORDER_ACKNOWLEDGEMENT_DATA_', xml)
      end

      def shipping_confirmation(hash)
        # example use: shipping_confirmation(merchant_order_id: 336, date: Time.parse("2013-06-03 17:58:25"), carrier: 'USPS', shipping_method: 'First Class', tracking: '9400110200883803727403')
        #              shipping_confirmation(mamazon_order_id: '112-2598432-0713054', date: Time.parse("2013-06-03 17:58:25"), carrier: 'USPS', shipping_method: 'First Class', tracking: '9400110200883803727403')
        if hash[:date].is_a? String
          # do nothing for now. Maybe later ensure it's the correct format.
        else
          # assume it's a Time, DateTime, ActiveSupport::TimeWithZone, etc...
          hash[:date] = hash[:date].strftime('%Y-%m-%dT%H:%M:%S%:z')
        end
        xml     = ""
        builder = Builder::XmlMarkup.new(:indent => 2, :target => xml)
        builder.instruct! # <?xml version="1.0" encoding="UTF-8"?>
        builder.AmazonEnvelope(:"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", :"xsi:noNamespaceSchemaLocation" => "amzn-envelope.xsd") do |env|
          env.Header do |head|
            head.DocumentVersion('1.01')
            head.MerchantIdentifier(@connection.seller_id)
          end
          env.MessageType('OrderFulfillment')
          env.Message do |mes|
            mes.MessageID('1')
            mes.OrderFulfillment do |orf|
              if hash[:amazon_order_id]
                orf.AmazonOrderID(hash[:amazon_order_id])
              else
                orf.MerchantOrderID(hash[:merchant_order_id])
              end
              orf.MerchantFulfillmentID(hash[:merchant_fulfillment_id]) if hash[:merchant_fulfillment_id]
              orf.FulfillmentDate(hash[:date])
              orf.FulfillmentData do |fd|
                fd.CarrierCode(hash[:carrier])
                fd.ShippingMethod(hash[:shipping_method])
                fd.ShipperTrackingNumber(hash[:tracking])
              end
              (hash[:items] || []).each do |item|
                orf.Item do |oi|
                  if item[:amazon_order_item_code]
                    oi.AmazonOrderItemCode(item[:amazon_order_item_code])
                  else
                    oi.MerchantOrderItemID(item[:merchant_order_item_id])
                  end
                  oi.MerchantFulfillmentItemID(item[:merchant_fulfillment_item_id]) if item[:merchant_fulfillment_item_id]
                  oi.Quantity if item[:quantity]
                end
              end
            end
          end
        end
        submit_feed('_POST_ORDER_FULFILLMENT_DATA_', xml)
      end

    end

  end

end
