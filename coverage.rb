require_relative 'computational_sentiment_classifier'

class Coverage
  def self.lexicon_coverage
    csc = CSC.new
    nokia_positive = File.open("nokia-pos.txt").read
    nokia_negative = File.open("nokia-neg.txt").read

    all_words = nokia_positive.split.keep_if { |w| (w =~ /\w/) }
    lexicon_coverage_positive = all_words.select do |w|
      csc.sent_lex.lexicon[w] || csc.sent_lex.lexicon[csc.lemmatizer.lemma(w)]
    end.count / all_words.count.to_f

    all_words = nokia_negative.split.keep_if { |w| (w =~ /\w/) }
    lexicon_coverage_negative = all_words.select do |w|
      csc.sent_lex.lexicon[w] || csc.sent_lex.lexicon[csc.lemmatizer.lemma(w)]
    end.count / all_words.count.to_f

    coverage = {
      positive: lexicon_coverage_positive,
      negative: lexicon_coverage_negative
    }
    coverage
  end
end

puts "Lexicon coverage:"
puts "positive Nokia reviews: #{ "%.2f" % (Coverage.lexicon_coverage[:positive] * 100) }%"
puts "negative Nokia reviews: #{ "%.2f" % (Coverage.lexicon_coverage[:negative] * 100) }%"