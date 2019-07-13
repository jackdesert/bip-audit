class SearchStats
  # This class tells gives you the aggregate counts
  #
  # How many documents with each type, subtype, etc.


  KEYS = [:type, :subtype, :field_names, :created_by_id]

  def self.stats
    output = {}
    _raw_results['aggregations'].each do |agg_name, data|
      name = agg_name.sub('_agg', '')
      output[name] ||= {}
      data['buckets'].each do |hash|
        key = hash['key']
        value = hash['doc_count']
        output[name][key] = value
      end
    end

    output
  end

  private

  def self._raw_results
    options = { index: ELASTICSEARCH_AUDIT_INDEX,
                body: _body }

    ELASTICSEARCH_CLIENT.search options
  end



  def self._body
    output = {
               size: 0, # Set size to zero so hits is empty array
               query: {
                 match_all: {} # match all
               },
               aggregations: {}, # Fill this hash in below
             }

    KEYS.each do |key|
      hash = { terms: { field: key, size: Search::MAX_SIZE } }
      output[:aggregations]["#{key}_agg"] = hash
    end

    output
  end



end
