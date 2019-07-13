class SearchResult
  # This class is used when returning results from Search

  SOURCE = '_source'.freeze

  attr_reader :id, :type, :subtype, :created_by_id, :created_by_name, :link, :person_ids, :timestamp, :blobs, :field_names, :blob_highlights

  def initialize(hit)
    @id = hit['_id']
    @type = hit[SOURCE]['type']
    @subtype = hit[SOURCE]['subtype']
    @created_by_id = hit[SOURCE]['created_by_id']
    @created_by_name = hit[SOURCE]['created_by_name']
    @link = hit[SOURCE]['link']
    @field_names = hit[SOURCE]['field_names']
    @blobs = hit[SOURCE]['blobs']
    @blob_highlights = hit['highlight'].try!(:[], 'blobs') || []
    @person_ids = hit[SOURCE]['person_ids']
    @timestamp = hit[SOURCE]['timestamp']
  end

end
