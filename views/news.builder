xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Winchester Vineyard News"
    xml.description "News & events coming up at Winchester Vineyard"
    xml.link "http://winvin.org.uk/#wv-news"
    xml.language "en-gb"

    @news.each do |item|
      if (item['published'])
        xml.item do
          xml.guid :isPermaLink => false do
            xml << 'winvin-item' + item['id']
          end
          xml.title [
            Time.parse(item['datetime']).strftime("%a %d %b %Y"),
            ": ",
            item['title']
          ].join
          xml.link 'http://winvin.org.uk/#wv-news'
          xml.description do
            xml.cdata! [
              item['text'],
              item['booking_url'].present? ? "\n\nBook here: " + item['booking_url'] : "",
              "\n\nLocation: ",
              item['location_title'],
            ].join
          end
          xml.pubDate item['pubDate'].rfc822()
        end
      end
    end
  end
end
