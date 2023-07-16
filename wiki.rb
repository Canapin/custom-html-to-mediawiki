require 'open-uri'
require 'nokogiri'
require 'pandoc-ruby'

# fill in this
html_content = ''

# Parse the HTML content with Nokogiri
doc = Nokogiri::HTML(html_content)

# Find each 'table' element and extract the '.thumb' elements
# Replace it with a [gallery] instead of a <gallery> so it isn't removed by Pandoc
doc.css('table').each do |table|
  thumbs = table.css('.thumb')
  if thumbs.any?
    gallery = "[gallery]\n"
    thumbs.each do |thumb|
      filename = thumb.at_css('.image')['href'].split('File:').last
      caption_div = thumb.at_css('.thumbcaption')
      caption_div.at_css('.magnify').remove if caption_div.at_css('.magnify')
      caption = caption_div.text.strip 
      gallery += "#{filename}|#{caption}\n"
    end
    gallery += "[/gallery]"
    table.replace(gallery)
  end
end

# Remove tables of content
doc.css('table.toc').remove

# Handle floating images that aren't thumbnails
doc.css('div[class^="float"]').each do |float_div|
  # Extract 'floatxxx' class and filename
  align = float_div['class'].sub('float', '')
  filename = float_div.at_css('.image')['href'].split('File:').last 

  # Replace the float div with the MediaWiki image syntax
  float_div.replace("[[File:#{filename}|frameless|#{align}]]")
end

# Find each remaining 'thumb' div
doc.css('.thumb').each do |thumb|
  # Extract 'txxx' class and filename
  align = thumb['class'].split.find { |c| c.start_with?('t') && c != 'thumb' }[1..]
  filename = thumb.at_css('.image')['href'].split('File:').last 

  # Get the thumbcaption div, remove the 'magnify' div and get the text
  caption_div = thumb.at_css('.thumbcaption')
  caption_div.at_css('.magnify').remove if caption_div.at_css('.magnify') 

  # Get the text content, remove leading/trailing white space
  caption = caption_div.text.strip 

  # Replace the thumb div with the MediaWiki image syntax
  thumb.replace("[[File:#{filename}|thumb|#{align}|#{caption}]]")
end

inner_html = doc.to_html

# Convert the HTML content to MediaWiki using Pandoc
begin
  converter = PandocRuby.convert(inner_html, :s, {f: :html, to: :mediawiki}, '--wrap=preserve')
  output = converter
rescue StandardError => e
  puts "Error during conversion: #{e.message}"
end

# Convert blockquotes to MediaWiki quotes
output.gsub!(/\<blockquote\>(.*?)\<\/blockquote\>/m) do
  "{{quote|#{Regexp.last_match[1].strip}}}"
end

# Remove remaining HTML tags from the output
output.gsub!(/<[^>]+?>/, "")

# Replaces the [gallery] custom tags by the gallery tag which is mediawiki syntax
output.gsub!(/\[gallery\](.*?)\[\/gallery\]/m, '<gallery>\1</gallery>')

# Remove consecutive line breaks
output.gsub!(/\n{2,}/, "\n")

output.strip!

# Write the result to a text file
File.open("output.txt", "w") { |file| file.write(output) }

