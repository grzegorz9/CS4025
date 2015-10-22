require "active_support/core_ext/hash/conversions"
require "facets"
require "yaml"
require "lingua/stemmer"

  # PENN POS tags reference
  # 1.    CC    Coordinating conjunction
  # 2.    CD    Cardinal number
  # 3.    DT    Determiner
  # 4.    EX    Existential there
  # 5.    FW    Foreign word
  # 6.    IN    Preposition or subordinating conjunction
  # 7.    JJ    Adjective
  # 8.    JJR   Adjective, comparative
  # 9.    JJS   Adjective, superlative
  # 10.   LS    List item marker
  # 11.   MD    Modal
  # 12.   NN    Noun, singular or mass
  # 13.   NNS   Noun, plural
  # 14.   NNP   Proper noun, singular
  # 15.   NNPS  Proper noun, plural
  # 16.   PDT   Predeterminer
  # 17.   POS   Possessive ending
  # 18.   PRP   Personal pronoun
  # 19.   PRP$  Possessive pronoun
  # 20.   RB    Adverb
  # 21.   RBR   Adverb, comparative
  # 22.   RBS   Adverb, superlative
  # 23.   RP    Particle
  # 24.   SYM   Symbol
  # 25.   TO    to
  # 26.   UH    Interjection
  # 27.   VB    Verb, base form
  # 28.   VBD   Verb, past tense
  # 29.   VBG   Verb, gerund or present participle
  # 30.   VBN   Verb, past participle
  # 31.   VBP   Verb, non-3rd person singular present
  # 32.   VBZ   Verb, 3rd person singular present
  # 33.   WDT   Wh-determiner
  # 34.   WP    Wh-pronoun
  # 35.   WP$   Possessive wh-pronoun
  # 36.   WRB   Wh-adverb

  # POLARITY SYMBOLS:
  # positive: +
  # negative: -
  # neutral: ~
  # missing: _
  # SPECIAL symbol for polarity reversal: ¬

class Symbol
  def to_polar
    case self
    when :positive
      "+"
    when :negative
      "-"
    when :neutral
      "~"
    when :inverting
      "¬"
    else
      self
    end
  end
end

class CompSenClsfc
  attr_accessor :sentiment_lexicon, :sentiwordnet_lexicon, :stemmer, :parse, :xml_parse_tree

  def initialize
    load_mpqa_lexicon
    @stemmer = Lingua::Stemmer.new language: "en"
  end

  def load_penn_parse
    @parse = %x( java -mx150m -cp "$HOME/stanford-parser/*:" edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat "oneline" edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz testsent.txt )
  end

  def load_xml_parse_tree
     xml_raw = %x( java -mx150m -cp "$HOME/stanford-parser/*:" edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat "xmlTree" edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz testsent.txt )
     @xml_parse_tree = Hash.from_xml(xml_raw)
  end

  def load_mpqa_lexicon
    @sentiment_lexicon = YAML.load(File.open("mpqa.yaml").read)
  end

  def load_stanford_dependencies
    @sd_parse = %x( java -mx150m -cp "$HOME/stanford-parser/*:" edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat "typedDependencies" edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz testsent.txt )
  end

  def load_sentiwordnet
    # A bit more tricky to parse into a data structure

    # raw = File.open('sentiwordnet.txt')
    # @sentiwordnet_lexicon = {}
    # raw.lines.delete_if { |l| l[0] == "#" }.each do |line|
    #   entries = line.split
    #   @sentiwordnet_lexicon[]
    # end
  end

  def insert_polarities parse
    match = /\((?<pos_tag>[A-Z]+\$?)\s(?<word>\w+)\)/.match parse
    if match
      insert_polarities parse.sub(/\((?<pos_tag>[A-Z]+\$?)\s(?<word>\w+)\)/, "(#{ get_polarity(match[:word], match[:pos_tag]) ? get_polarity(match[:word], match[:pos_tag]).to_polar : '_' })")
    else
      parse
    end
  end

  def stem word
    @stemmer.stem word
  end


  def polarities_from_stem stm
    @sentiment_lexicon.keys.keep_if { |wd| wd =~ Regexp.new("^#{stm}") }.map { |wd| @sentiment_lexicon[wd] }.reduce({}, :merge)
  end

  def list_parse_leaves
    @parse.to_enum(:scan, /\((?<pos_tag>[A-Z]+\$?)\s(?<word>\w+)\)/).map { Regexp.last_match }
  end

  def polarity_label_parse
    list_parse_leaves.map { |mtch| [mtch, (get_polarity(mtch[:word], mtch[:pos_tag]) || :_)] }
  end

  def get_polarity word, pos_tag
    wd = word.downcase
    
    if @sd_parse =~ Regexp.new("neg\\(.*,\\s#{wd}.*\\)")
      return :inverting
    end

    if pos_tag =~ /^JJ/ # an adjective
      @sentiment_lexicon[wd] && (@sentiment_lexicon[wd][:adj] || @sentiment_lexicon[wd][:anypos])
    elsif pos_tag =~ /^VB$/ # a verb in base form
      @sentiment_lexicon[wd] && @sentiment_lexicon[wd][:verb]
    # elsif pos_tag =~ /^VB[DGNPZ]$/ # a verb in a compound form
    #   options = polarities_from_stem(stem(wd)).delete_if { |e| e.nil? }
    #   if options.empty?
    #     nil
    #   else
    #     options[:verb] || options[:anypos]
    #   end
    elsif pos_tag =~ /^NN/ # a noun
      @sentiment_lexicon[wd] && (@sentiment_lexicon[wd][:noun] || @sentiment_lexicon[wd][:anypos])
    else
      @sentiment_lexicon[wd] && @sentiment_lexicon[wd][:anypos]
    end
  end
end

c = CompSenClsfc.new
c.load_penn_parse
c.load_stanford_dependencies
puts "\n--- PARSE ---\n#{c.parse}"
puts c.insert_polarities(c.parse)
puts "\n--- POLARITY (LEAF NODES) ---"
c.polarity_label_parse.each { |l| puts "#{l[0]} -> #{l[1]}" }

puts "\n--- PARSE GRAPH ---"
c.load_xml_parse_tree
puts c.xml_parse_tree