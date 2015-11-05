require "yaml"
require "lemmatizer"

class Symbol
  def to_polarity
    case self
    when :positive
      "+"
    when :negative
      "-"
    when :neutral
      "~"
    when :inverting
      "¬"
    end
  end
end

class NilClass
  def to_polarity
    "_"
  end
end

class PennParse
  attr_reader :text

  def initialize raw
    @text = raw
  end

  def leaf_nodes
    @leaf_nodes ||= @text.to_enum(:scan,
      /\((?<pos_tag>[A-Z]+\$?)\s(?<word>[^\(\)]+)\)/)
      .map { Regexp.last_match }
  end
end

class MpqaLexicon
  attr_reader :lexicon

  def initialize
    @lexicon = YAML.load File.open("mpqa.yaml").read
  end

  def search word, pos_symbol
    @lexicon[word] && (@lexicon[word][pos_symbol] || @lexicon[word][:anypos])
  end
end

class CSC
  attr_accessor :lemmatizer, :parse, :typed_deps, :sent_lex

  def initialize
    load_lexicon
    load_lemmatizer
  end

  def load_lexicon
    @sent_lex = MpqaLexicon.new
  end

  def load_lemmatizer
    @lemmatizer = Lemmatizer.new
  end

  def load_stanford_parse
    lines = %x( java -mx150m -cp "$HOME/stanford-parser/*:" \
        edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat \
        "oneline, typedDependencies" \
        edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz testsent.txt )
        .strip.split("\n")

    @parse = PennParse.new(lines.shift.strip.gsub(/\s\(([^A-Z]) \1\)/, ""))
    @typed_deps = lines
  end

  def find_polarity word, pos_tag
    return :inverting if @typed_deps.any? do |entry|
      entry =~ Regexp.new("neg\\(.*,\\s#{word}.*\\)")
    end

    case pos_tag
    when /^JJ[RS]?$/
      pos_sym = :adj
    when /^NNS?P?$/
      pos_sym = :noun
    when /^RB[RS]?$/
      pos_sym = :adv
    when /^VB[DGNPZ]?$/
      pos_sym = :verb
    end

    if pos_sym
      @sent_lex.search(word, pos_sym) ||
      @sent_lex.search(@lemmatizer.lemma(word, pos_sym), pos_sym)
    else
      @sent_lex.search(word, :anypos)
    end
  end

  def polarity_list
    @polarity_list ||= @parse.leaf_nodes.map do |data|
      find_polarity data[:word], data[:pos_tag]
    end
  end

  def insert_polarities parse
    match = /\((?<pos_tag>[A-Z]+\$?)\s(?<word>[^\(\)\+\-~¬_]+)\)/.match parse
    if match
      insert_polarities \
        parse.sub(/\((?<pos_tag>[A-Z]+\$?)\s(?<word>[^\(\)\+\-~¬_]+)\)/,
          "(#{ match[:pos_tag] } #{ find_polarity(match[:word], match[:pos_tag]).to_polarity })")
    else
      parse
    end
  end

  def strip_brackets parse
    if parse =~ /\([\+\-~¬_]\)/
      strip_brackets parse.sub(/\(([\+\-~¬_])\)/, '\1')
    else
      parse
    end
  end

  def insert_polarities_reduce parse
    match = /\((?<pos_tag>[A-Z]+\$?)\s(?<word>[^\(\)]+)\)/.match parse
    if match
      insert_polarities_reduce \
        parse.sub(/\((?<pos_tag>[A-Z]+\$?)\s(?<word>[^\(\)]+)\)/,
          "(#{ find_polarity(match[:word], match[:pos_tag]).to_polarity })")
    else
      strip_brackets parse
    end
  end

  def reverse_polarity p
    if p == "+"
      "-"
    elsif p == "-"
      "+"
    end
  end

  def right_reduce polarity_seq
    match = /(\+|\-|~|¬|_) (\+|\-|~|¬|_)$/.match polarity_seq

    if match
      regex_inverting = /^¬ ([\+\-])$|([\+\-]) ¬$/
      regex_absorbing = /^[~_] ([\+\-_])$|^([\+\-_]) [~_]$/

      temp = polarity_seq
      if match[0] =~ /^\+ \-$|^\- \+$/
        temp[match.begin(0)...match.end(0)] = match[2]
      elsif match[0] =~ regex_inverting
        temp[match.begin(0)...match.end(0)] =
          reverse_polarity(regex_inverting.match(polarity_seq)[1] ||
            regex_inverting.match(polarity_seq)[2])
      elsif match[0] =~ regex_absorbing
        temp[match.begin(0)...match.end(0)] =
          regex_absorbing.match(polarity_seq)[1] ||
            regex_absorbing.match(polarity_seq)[2]
      else
        temp[match.begin(0)...match.end(0)] = match[2]
      end
    else
      polarity_seq
    end
  end

  def reduce_polarities parse
    if parse =~ /^(ROOT [\+\-~¬_])$/
      parse
    else
      temp = parse
      matches = temp.to_enum(:scan,
        /\((?<pos_tag>[A-Z]+\$?)\s(?<node_value>[^\(\)]+)\)/)
        .map { Regexp.last_match }

      matches.reverse.each do |mtch|
        temp[mtch.begin(0)...mtch.end(0)] = right_reduce mtch[:node_value]
      end
      reduce_polarities temp
    end
  end
end

csc = CSC.new
csc.load_stanford_parse
# puts csc.insert_polarities(csc.parse.text)

int_parse = csc.insert_polarities_reduce(csc.parse.text)
puts int_parse
# puts csc.reduce_polarities int_parse
