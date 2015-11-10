require_relative "computational_sentiment_classifier"

nokia_positive = File.open("nokia-pos.txt").read.lines
nokia_negative = File.open("nokia-neg.txt").read.lines

results_positive = []
results_negative = []

classifier = CSC.new

nokia_positive.each do |review|
  buffer_file = File.open("buffer.txt", "w") { |file| file.write review }
  classifier.load_stanford_parse_from "buffer.txt"

  result = classifier.calculate_polarity
  results_positive.push result
  # if result != "+"
  #   puts "---\nINCORRECT LABEL: classified as #{result}"
  #   puts review
  #   puts "---"
  #   abort
  # end
end

# nokia_negative.each do |review|
#   buffer_file = File.open("buffer.txt","w") { |file| file.write review }
#   classifier.load_stanford_parse_from "buffer.txt"

#   result = classifier.calculate_polarity
#   results_negative.push result
#   if result != "-"
#     puts "\nThis is where it gives a wrong answer"
#     puts review
#     abort
#   end
# end

correct_positive = results_positive.count "+"
false_negatives = restuls_positive.count "-"
# correct_negative = results_negative.count "-"
# false_positives = results_negative.count "+"

puts correct_positive
# puts correct_negative
# puts false_positives
puts false_negatives
