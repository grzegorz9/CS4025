require_relative 'computational_sentiment_classifier'

csc = CSC.new
csc.load_stanford_parse

puts csc.parse.text
puts csc.insert_polarities csc.parse.text
int_parse = csc.insert_polarities_reduce(csc.parse.text)
puts csc.total_polarity int_parse
