xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0", :'xmlns:itunes' => "http://www.itunes.com/dtds/podcast-1.0.dtd" do
  xml.channel do
    xml.title "Winchester Vineyard Sunday Talks"
    xml.description "Talks given on Sundays and at conferences at Winchester Vineyard"
    xml.link "http://winvin.org.uk/#wv-talks"
    xml.itunes :author, "Winchester Vineyard"
    xml.itunes :language, "English"
    xml.itunes :email, "hello@winvin.org.uk"
    xml.itunes :explicit, "clean"
    xml.itunes :category, :text => "Religion & Spirituality" do
      xml.itunes :category, :text => "Christianity"
    end
    xml.itunes :image, :href => "http://winvin.org.uk/images/winvin-square-logo.png"
    xml.itunes :summary, "Talks given on Sundays and at conferences at Winchester Vineyard"

    @talks.each do |talk|
      if (talk['published'])
        xml.item do
          xml.guid :isPermaLink => false do
            xml << 'winvin-talk' + talk['id']
          end
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
