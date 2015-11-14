require_relative "computational_sentiment_classifier"
require_relative "statistical_classifier"

STATISTICAL_CLSFR = ARGV.any? { |arg| arg =~ /^\-{2}stat$/ }
SHOW_INCORRECT = ARGV.any? { |arg| arg =~ /\-\w*e\w*/ }
ABORT_ON_ERROR = ARGV.any? { |arg| arg =~ /\-\w*A\w*/ }

nokia_positive = File.open("nokia-pos.txt").read.lines
nokia_negative = File.open("nokia-neg.txt").read.lines

results_positive = { "+" => 0, "-" => 0, "~" => 0, "_" => 0 }
results_negative = { "+" => 0, "-" => 0, "~" => 0, "_" => 0 }

if STATISTICAL_CLSFR
  puts "Decided to use the statistical classifier :("
  abort
  classifier = StatisticalClassifier.new
else
  classifier = CSC.new
end

nokia_positive.each do |review|
  if STATISTICAL_CLSFR
    classifier.load_review_directly review
    result = classifier.calculate_polarity
  else
    buffer_file = File.open("buffer.txt", "w") { |file| file.write review }
    classifier.load_stanford_parse_from "buffer.txt"
    result = classifier.calculate_polarity
  end

  results_positive[result] += 1

  if SHOW_INCORRECT || ABORT_ON_ERROR
    if (result != "+")
      if SHOW_INCORRECT
        puts "---\nINCORRECT LABEL: classified as '#{result}'"
        puts review
        puts "---"
      end
      abort if ABORT_ON_ERROR
    end
  end
end

nokia_negative.each do |review|
  if STATISTICAL_CLSFR
    classifier.load_review_directly review
    result = classifier.calculate_polarity
  else
    buffer_file = File.open("buffer.txt", "w") { |file| file.write review }
    classifier.load_stanford_parse_from "buffer.txt"
    result = classifier.calculate_polarity
  end

  results_negative[result] += 1

  if SHOW_INCORRECT || ABORT_ON_ERROR
    if (result != "-")
      if SHOW_INCORRECT
        puts "---\nINCORRECT LABEL: classified as '#{result}'"
        puts review
        puts "---"
      end
      abort if ABORT_ON_ERROR
    end
  end
end

puts "POSITIVE"
puts results_positive

puts "NEGATIVE"
puts results_negative
