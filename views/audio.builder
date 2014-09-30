xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0" do
  xml.channel do
    xml.title "Winchester Vineyard Sunday Talks"
    xml.description "Talks given on Sundays and at conferences at Winchester Vineyard"
    xml.link "http://winvin.org.uk/#wv-talks"

    @talks.each do |talk|
      if (talk['published'])
        xml.item do
          xml.guid 'winvin-talk' + talk['id']
          xml.title talk_title(talk)
          xml.enclosure :url => talk['download_url']
          xml.link talk['download_url']
          xml.description talk_title(talk) + ".\n\n" + (talk['slides_url'].present? ? "Slides are available here: " + talk['slides_url'] : "")

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
