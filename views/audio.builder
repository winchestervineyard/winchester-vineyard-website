xml.instruct! :xml, :version => '1.0'
xml.rss :version => "2.0", :'xmlns:itunes' => "http://www.itunes.com/dtds/podcast-1.0.dtd" do
  xml.channel do
    xml.title "Sunday Podcasts"
    xml.description "Winchester Vineyard Church are people who are getting to know Jesus better and bringing hope and life into our communities. These podcasts are taken from our Sunday morning gatherings."
    xml.link "http://winvin.org.uk/#wv-talks"
    xml.itunes :author, "Winchester Vineyard"
    xml.language "en-gb"
    xml.copyright "539120"
    xml.itunes :keywords, "539120"
    xml.itunes :explicit, "clean"
    xml.itunes :category, :text => "Religion & Spirituality" do
      xml.itunes :category, :text => "Christianity"
    end
    xml.itunes :owner do
      xml.itunes :name, "Winchester Vineyard"
      xml.itunes :email, "hello@winvin.org.uk"
    end
    xml.itunes :image, :href => "http://winvin.org.uk/images/winvin_logo_podcast.png"
    xml.itunes :summary, "Winchester Vineyard Church are people who are getting to know Jesus better and bringing hope and life into our communities. These podcasts are taken from our Sunday morning gatherings."

    @talks.each do |talk|
      if (talk.published?)
        xml.item do
          xml.guid :isPermaLink => false do
            xml << 'winvin-talk' + talk.id
          end
          xml.title talk.full_name
          xml.enclosure :url => talk.download_url, :type => 'audio/mpeg'
          xml.link 'http://winvin.org.uk/'
          xml.description talk.description
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
