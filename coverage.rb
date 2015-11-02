require_relative 'computational_sentiment_classifier'

class Coverage
  def self.stats
    csc = CSC.new
    nokia_positive = File.open("nokia-pos.txt").read
    nokia_negative = File.open("nokia-neg.txt").read

    all_words_positiv = nokia_positive.split.keep_if { |w| (w =~ /\w/) }
    positiv_hits = all_words_positiv.select do |w|
      csc.sent_lex.lexicon[w] || csc.sent_lex.lexicon[csc.lemmatizer.lemma(w)]
    end.count
    positiv_coverage = positiv_hits / all_words_positiv.count.to_f

    all_words_negativ = nokia_negative.split.keep_if { |w| (w =~ /\w/) }
    negativ_hits = all_words_negativ.select do |w|
      csc.sent_lex.lexicon[w] || csc.sent_lex.lexicon[csc.lemmatizer.lemma(w)]
    end.count
    negativ_coverage = negativ_hits / all_words_negativ.count.to_f

    coverage = {
      positive: {
        coverage: positiv_coverage,
        hits: positiv_hits,
        word_total: all_words_positiv.count
      },
      negative: {
        coverage: negativ_coverage,
        hits: negativ_hits,
        word_total: all_words_negativ.count
      }
    }
    coverage
  end
end

puts "Lexicon coverage:"

puts "positive Nokia reviews: #{ "%.2f" % (Coverage.stats[:positive][:coverage] * 100) }% \
(#{ Coverage.stats[:positive][:hits] }/#{ Coverage.stats[:positive][:word_total]})"

puts "negative Nokia reviews: #{ "%.2f" % (Coverage.stats[:negative][:coverage] * 100) }% \
(#{ Coverage.stats[:negative][:hits] }/#{ Coverage.stats[:negative][:word_total]})"
