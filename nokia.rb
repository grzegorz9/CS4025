require_relative "computational_sentiment_classifier"

FAIL_ON_ERROR = ARGV.any? { |arg| arg =~ /\-e/ }

nokia_positive = File.open("nokia-pos.txt").read.lines
nokia_negative = File.open("nokia-neg.txt").read.lines

results_positive = { "+" => 0, "-" => 0, "~" => 0, "_" => 0 }
results_negative = { "+" => 0, "-" => 0, "~" => 0, "_" => 0 }

classifier = CSC.new

nokia_positive.each do |review|
  buffer_file = File.open("buffer.txt", "w") { |file| file.write review }
  classifier.load_stanford_parse_from "buffer.txt"

  result = classifier.calculate_polarity
  results_positive[result] += 1

  if FAIL_ON_ERROR && (result != "+")
    puts "---\nINCORRECT LABEL: classified as '#{result}'"
    puts review
    puts "---"
    abort
  end
end

nokia_negative.each do |review|
  buffer_file = File.open("buffer.txt","w") { |file| file.write review }
  classifier.load_stanford_parse_from "buffer.txt"

  result = classifier.calculate_polarity
  results_negative[result] += 1

  if FAIL_ON_ERROR && (result != "-")
    puts "---\nINCORRECT LABEL: classified as '#{result}'"
    puts review
    puts "---"
    abort
  end
end

puts "POSITIVE"
puts results_positive

puts "NEGATIVE"
puts results_negative
