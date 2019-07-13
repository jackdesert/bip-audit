class Search
  # This class is used to query Elasticsearch

  TARGET_PERSON_ID = '7a7c9d31-9c04-43f3-bcef-1bf4d655ca84'.freeze # Helen Child
  MAX_SIZE = 10_000
  REDIS_KEY_PREPEND = 'audit-searches-'.freeze
  REDIS_SIZE = 200

  OPTIONS = {
    # match options match one analyzed data
    blobs: :match,

    # term options match exactly
    type: :term,
    subtype: :term,
    field_names: :term,
    created_by_id: :term,
    created_by_name: :term,
    person_ids: :term,
    start_timestamp: :q,
    end_timestamp: :q,
  }

  DELIMITED_OPTIONS = [:type, :subtype, :field_names, :created_by_id, :person_ids]
  DELIMITER = ', '.freeze


  attr_reader *OPTIONS.keys

  def initialize(options={})
    # ARGUMENTS
    # blobs:           <string> (search for any of the analyzed words in the string)
    # type:            <delimited_string> (any of the exact terms found)
    # subtype:         <delimited_string> (any of the exact terms found)
    # field_names:     <delimited_string> (any of the exact terms found)
    # created_by_id:   <delimited_string> (any of the exact terms found)
    # person_ids:      <delimited_string> (any of the exact terms found)
    # start_timestamp: <timestamp> (after this time)
    # end_timestamp:   <timestamp> (before this time)
    #
    #
    # While most of these fields, taken individually, use OR logic (should)
    # they are combined using AND (must) logic.
    #
    # That is, if you search for { type: [:note, :form_response] }
    # you get
    #   (type == note OR type == form_response)
    #
    # But if you search for { type: [:note, :form_response], created_by_id: 'abc' }
    # you get
    #   ((type == note OR type == form_response) AND (created_by_id == 'abc'))
    #
    # See https://stackoverflow.com/questions/28538760/elasticsearch-bool-query-combine-must-with-or#answer-40755927

    options.symbolize_keys!

    excess_keys = options.keys - OPTIONS.keys
    if excess_keys.present?
      raise ArgumentError, "These keys not allowed: #{excess_keys}"
    end

    options.each do |key, value|
      value_to_use = if DELIMITED_OPTIONS.include?(key)
                       value.try!(:split, DELIMITER)
                     else
                       value
                     end

      instance_variable_set "@#{key}", value_to_use
    end
  end

  def results
    output = []
    _raw_results['hits']['hits'].each do |hit|
      result = SearchResult.new(hit)
      output.push(result)
    end

    output
  end

  private

  def _raw_results
    options = { index: ELASTICSEARCH_AUDIT_INDEX,
                size: MAX_SIZE,
                body: _body }

    ELASTICSEARCH_CLIENT.search options
  end


  def _boolean_should(key, values)
    # Construct a boolean OR between each term in the array
    # Note boolean OR is spelled "should"
    # See https://stackoverflow.com/questions/28538760/elasticsearch-bool-query-combine-must-with-or#answer-40755927

    shoulds = []

    values.each do |v|
      shoulds.push({ term: { key => v }})
    end

    output = { bool: { should: shoulds} }

    output
  end

  def _filters
    output = []

    OPTIONS.each do |key, query_type|
      value = send(key)
      next unless value.present?

      if query_type == :match
        #output.push({ fuzzy: { key => value }})
        output.push({ match: { key => value }})
      elsif query_type == :term
        output.push(_boolean_should(key, value))
      end
    end

    output
  end

  def _body
    {
      query: {
        bool: {
          filter: _filters
        }
      },
      sort: [
        { timestamp: {} }
      ],
      highlight: {
        fields: {
          blobs: {}
        }
      }
    }
  end

  def self.all
    # Format is
    # { <person_id> => [url, url, url],
    #   <person_id> => [url, url],
    #   ...
    # }
    output = {}
    self.redis_keys.each do |key|
      person_id = key.sub(REDIS_KEY_PREPEND, '')
      REDIS_CLIENT.lrange(key, 0, -1).each do |value|
        output[person_id] ||= []
        output[person_id] << value
      end
    end

    output
  end

  def self.redis_keys
    # There is one key for each user who has searched
    # See audit_controller.rb for format
    keys = Set.new
    cursor = 0

    while true
      cursor, results = REDIS_CLIENT.scan(cursor, match: "#{REDIS_KEY_PREPEND}*")

      results.each do |result|
        keys.add(result)
      end

      break if cursor.to_i == 0
    end

    keys
  end

end
