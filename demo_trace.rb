require_relative 'computational_sentiment_classifier'

csc = CSC.new
csc.load_stanford_parse

puts csc.parse.text
csc.calculate_polarity show_trace: true
