require_relative "classifier"

class CSC < Classifier
  def load_stanford_parse
    lines = %x( java -mx500m -cp "$HOME/stanford-parser/*:" \
        edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat \
        "oneline, typedDependencies" \
        edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz testsent.txt )
        .strip.split("\n")

    raw = lines.shift.strip.gsub(/\s?\([^A-Z\(\)]+ [^\(\)]+\)|\(\-[^\(\)]+\)/, "")
    @parse = PennParse.new raw
    @typed_deps = lines
  end

  def load_stanford_parse_from file
    cmd = """
        java -mx500m -cp \"$HOME/stanford-parser/*:\" \
        edu.stanford.nlp.parser.lexparser.LexicalizedParser -outputFormat \
        'oneline, typedDependencies' \
        edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz #{file}
      """
    lines = `#{cmd}`.strip.split("\n")

    @parse = PennParse.new(lines.shift.strip.gsub(/\s?\([^A-Z\(\)]+ [^\(\)]+\)|\(\-[^\(\)]+\)/, ""))
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

  def insert_polarities
    temp = self.parse.text
    matches = temp.to_enum(:scan,
      /\((?<pos_tag>[A-Z]+\$?)\s(?<word>[^\(\)]+)\)/)
      .map { Regexp.last_match }

    matches.reverse.each do |mtch|
      temp[mtch.begin(0)...mtch.end(0)] =
         "(#{ mtch[:pos_tag] } #{ find_polarity(mtch[:word], mtch[:pos_tag]).to_polarity })"
    end

    temp.gsub(/\) \)/, "))")
  end

  def strip_brackets parse
    if parse =~ /\([\+\-~¬_]\)/
      strip_brackets parse.sub(/\(([\+\-~¬_])\)/, '\1')
    else
      parse
    end
  end

  def reverse_polarity p
    if p == "+"
      "-"
    elsif p == "-"
      "+"
    end
  end

  def compose_polarities polarity_seq
    match = /([\+\-~¬_]) ([\+\-~¬_])$/.match polarity_seq

    if match
      regex_inverting = /^¬ ([\+\-])$|([\+\-]) ¬$/
      regex_absorbing = /^_ ([\+\-~])$|^([\+\-~]) _$/
      regex_high_prec = /^~ ([\+\-])$|^([\+\-]) ~$/

      temp = polarity_seq
      if match[0] =~ /^([\+\-~¬_]) \1$/
        temp[match.begin(0)...match.end(0)] = match[2]
        compose_polarities temp
      elsif match[0] =~ /^\+ \-$|^\- \+$/
        temp[match.begin(0)...match.end(0)] = match[2]
        compose_polarities temp
      elsif match[0] =~ regex_inverting
        temp[match.begin(0)...match.end(0)] =
          reverse_polarity(regex_inverting.match(match[0])[1] ||
            regex_inverting.match(match[0])[2])
        compose_polarities temp
      elsif match[0] =~ regex_absorbing
        temp[match.begin(0)...match.end(0)] =
          regex_absorbing.match(match[0])[1] ||
            regex_absorbing.match(match[0])[2]
        compose_polarities temp
      elsif match[0] =~ regex_high_prec
        temp[match.begin(0)...match.end(0)] =
          regex_high_prec.match(match[0])[1] ||
            regex_high_prec.match(match[0])[2]
        compose_polarities temp
      else
        temp[match.begin(0)...match.end(0)] = match[2]
        compose_polarities temp
      end
    else
      polarity_seq
    end
  end

  def total_polarity parse, options = {}
    if parse.length > 1
      temp = parse
      puts temp if (options[:show_trace]) && (options[:show_trace] == true)
      matches = temp.to_enum(:scan,
        /\((?<pos_tag>[A-Z]+\$?)\s+(?<polarity_value>[^\(\)]+)\)/)
        .map { Regexp.last_match }

      matches.reverse.each do |mtch|
        temp[mtch.begin(0)...mtch.end(0)] =
          compose_polarities mtch[:polarity_value]
      end
      total_polarity temp, options
    else
      parse
    end
  end

  def calculate_polarity *options
    initial_polarities = insert_polarities

    if !options.empty? && options.first.is_a?(Hash)
      total_polarity initial_polarities, options.first
    else
      total_polarity initial_polarities
    end
  end
end
