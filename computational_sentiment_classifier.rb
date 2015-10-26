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
      /\((?<pos_tag>[A-Z]{,3}\$?)\s(?<word>[^\(\)]+)\)/)
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
  attr_accessor :parse, :typed_deps, :sent_lex

  def initialize
    @sent_lex = MpqaLexicon.new
    @inflctr = Lemmatizer.new

    lines = %x( java -mx150m -cp "$HOME/stanford-parser/*:" \
        edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat \
        "oneline, typedDependencies" \
        edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz testsent.txt )
        .strip.split("\n")

    @parse = PennParse.new lines.shift.strip
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
      @sent_lex.search(@inflctr.lemma(word, pos_sym), pos_sym)
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
    match = /\((?<pos_tag>[A-Z]{,3}\$?)\s(?<word>[^\(\)]+)\)/.match parse
    if match
      insert_polarities \
        parse.sub(/\((?<pos_tag>[A-Z]{,3}\$?)\s(?<word>[^\(\)]+)\)/,
          "(#{ find_polarity(match[:word], match[:pos_tag]).to_polarity })")
    else
      parse
    end
  end
end
