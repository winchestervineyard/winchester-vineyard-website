xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0", :'xmlns:itunes' => "http://www.itunes.com/dtds/podcast-1.0.dtd" do
  xml.channel do
    xml.title "Winchester Vineyard Sunday Talks"
    xml.description "Talks given on Sundays and at conferences at Winchester Vineyard"
    xml.link "http://winvin.org.uk/#wv-talks"
    xml.itunes :author, "Winchester Vineyard"
    xml.language "en-gb"
    xml.itunes :explicit, "clean"
    xml.itunes :category, :text => "Religion & Spirituality" do
      xml.itunes :category, :text => "Christianity"
    end
    xml.itunes :owner do
      xml.itunes :name, "Winchester Vineyard"
      xml.itunes :email, "hello@winvin.org.uk"
    end
    xml.itunes :image, :href => "http://winvin.org.uk/images/winvin-square-logo.png"
    xml.itunes :summary, "Talks given on Sundays and at conferences at Winchester Vineyard"

    @talks.each do |talk|
      if (talk.published?)
        xml.item do
          xml.guid :isPermaLink => false do
            xml << 'winvin-talk' + talk.id
          end
          xml.title talk.full_name
          xml.enclosure :url => talk.download_url, :type => 'audio/mpeg'
          xml.link 'http://winvin.org.uk/talks/' + talk.slug
          xml.description do
            xml.cdata! talk.description + " \n\n" + (talk.has_slides? ? "Slides are available on our website: <a href='http://winvin.org.uk/talks/#{talk.slug}'>http://winvin.org.uk/talks/#{talk.slug}</a>" : "")
          end
          xml.pubDate talk.date.rfc822
          if talk.part_of_a_series?
            xml.category talk.series_name
          end
          xml.category talk.who
        end
      end
    end
  end
end
