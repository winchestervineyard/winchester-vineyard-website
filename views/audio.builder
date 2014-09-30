xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0", :xmlns => "default", :'xmlns:itunes' => "http://www.itunes.com/dtds/podcast-1.0.dtd" do
  xml.channel do
    xml.title "Winchester Vineyard Sunday Talks"
    xml.description "Talks given on Sundays and at conferences at Winchester Vineyard"
    xml.link "http://winvin.org.uk/#wv-talks"
    xml.itunes :author, "Winchester Vineyard"
    xml.itunes :image, "http://winvin.org.uk/images/winvin-square-logo.png"
    xml.itunes :summary, "Talks given on Sundays and at conferences at Winchester Vineyard"

    @talks.each do |talk|
      if (talk['published'])
        xml.item do
          xml.guid 'winvin-talk' + talk['id']
          xml.title talk_title(talk)
          xml.enclosure :url => talk['download_url'], :type => 'audio/mpeg'
          xml.link talk['download_url']
          xml.description do
            xml.cdata! talk_title(talk) + " \n\n" + (talk['slides_url'].present? ? "<a href='#{talk['slides_url']}'>Slides are available here</a>" : "")
          end
          xml.pubDate Time.parse(talk['datetime']).rfc822()
          if (talk['series_name'].present?)
            xml.category talk['series_name']
          end
          xml.category talk['who']
        end
      end
    end
  end
end
