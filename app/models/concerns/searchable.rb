class Searchable
  # This class is used to index objects into ElasticSearch

  class MissingData < Exception;end

  KEYWORD = :keyword
  TEXT = :text
  DATE = :date

  include Rails.application.routes.url_helpers


  attr_reader :names_hash, :obj

  def initialize(obj, names_hash=nil)
    @obj = obj

    # Pass this in to improve batch performance
    names_hash ||= Person.names_hash_for_people

    @names_hash = names_hash
    @created_by_name = names_hash[created_by_id]
  end



  def write
    type = obj.class.table_name.downcase.singularize
    id = "#{type}-#{obj.id}"

    ELASTICSEARCH_CLIENT.index(index: ELASTICSEARCH_AUDIT_INDEX,
                               type: '_doc',
                               id: id,
                               body: { person_ids: person_ids,
                                       type: type,
                                       subtype: subtype,
                                       link: link,
                                       created_by_id: created_by_id,
                                       created_by_name: created_by_name,
                                       blobs: blobs,
                                       field_names: field_names,
                                       timestamp: timestamp })

  end

  private

  def blobs
    if obj.is_a?(Note)
      [obj.note_text]
    elsif obj.is_a?(FormResponse) && obj.form_definition.individual?
      # If first in a series, return all current values
      return obj.form_data.map(&:value) unless obj.previous

      # Otherwise, return current and previous values that changed
      # That way if somebody either adds or removes "heart condition",
      # it will show up
      diff = obj.diff(obj.previous)
      current_values  =          obj.form_data.order_by_key.where(key: field_names).map(&:value)
      previous_values = obj.previous.form_data.order_by_key.where(key: field_names).map(&:value)
      [previous_values, ['---'], current_values].flatten
    elsif obj.is_a?(FormResponse)
      obj.form_data.order_by_key.map(&:value)
    elsif obj.is_a?(ActivityRecord)
      [obj.comment]
    elsif obj.is_a?(Alert)
      [obj.message]
    elsif obj.is_a?(Excursion)
      []
    elsif obj.is_a?(Excursion::Comment)
      obj.text
    elsif obj.is_a?(HelpButtonState)
      []
    elsif obj.is_a?(Interaction)
      []
    elsif obj.is_a?(PainAssessment)
      [obj.notes]
    elsif obj.is_a?(VitalsReading)
      []
    elsif obj.is_a?(Watch)
      [obj.notes]
    elsif obj.is_a?(WatchUpdate)
      [obj.observation, obj.action]
    else
      raise MissingData
    end
  end

  def field_names
    if obj.is_a?(FormResponse) && obj.form_definition.individual?
      return obj.form_data.map(&:key) unless obj.previous
      diff = obj.diff(obj.previous)
      # Individual forms will have "person." prepend.
      # To take that out in `field_names` would mean adding it back in
      # in `blobs` when querying for data matching the field names.
      #
      # Also, leaving it in groups all the individual field_names together
      # on the front end so they are clearly a group.
      diff.changes.map(&:key).sort
    elsif obj.is_a?(FormResponse)
      obj.form_data.map(&:key).sort
    else
      []
    end
  end

  def person_ids
    if obj.respond_to?(:person_ids)
      obj.person_ids
    elsif obj.respond_to?(:person_id)
      [obj.person_id]
    elsif obj.is_a?(Excursion::Comment)
      [obj.excursion.person_id]
    elsif obj.is_a?(WatchUpdate)
      [obj.watch.person_id]
    else
      raise MissingData
    end
  end

  def subtype
    output = if obj.is_a?(Note)
               obj.category
             elsif obj.is_a?(FormResponse)
               obj.form_definition.name
             elsif obj.is_a?(ActivityRecord)
               obj.activity_definition.name
             elsif obj.is_a?(Alert)
               Alert::ALERT_TYPE_LABELS[obj.alert_type].to_s.gsub(' ', '_')
             elsif obj.is_a?(Excursion)
               obj.reason
             elsif obj.is_a?(Excursion::Comment)
               nil
             elsif obj.is_a?(HelpButtonState)
               obj.change_type
             elsif obj.is_a?(Interaction)
               obj.interaction_type
             elsif obj.is_a?(PainAssessment)
               nil
             elsif obj.is_a?(VitalsReading)
               nil
             elsif obj.is_a?(Watch)
               obj.note.category
             elsif obj.is_a?(WatchUpdate)
               obj.watch.note.category
             else
               raise MissingData
             end

    # Note no "!" on the end of try, because we want it to be called for strings,
    # but not for integers
    output.try(:downcase)
  end

  def link
    if obj.is_a?(Note)
      note_path(obj.id)
    elsif obj.is_a?(FormResponse)
      form_response_path(obj)
    elsif obj.is_a?(ActivityRecord)
      activity_record_path(obj)
    elsif obj.is_a?(Alert)
      alert_path(obj)
    elsif obj.is_a?(Excursion)
      excursion_path(obj)
    elsif obj.is_a?(Excursion::Comment)
      excursion_path(obj.excursion_id)
    elsif obj.is_a?(HelpButtonState)
      help_button_state_path(obj)
    elsif obj.is_a?(Interaction)
      interaction_path(obj)
    elsif obj.is_a?(PainAssessment)
      pain_assessment_path(obj)
    elsif obj.is_a?(VitalsReading)
      vitals_reading_path(obj)
    elsif obj.is_a?(Watch)
      watch_path(obj)
    elsif obj.is_a?(WatchUpdate)
      watch_update_path(obj)
    else
      raise MissingData
    end
  end

  def created_by_id
    if obj.respond_to?(:created_by_id)
      obj.created_by_id
    elsif obj.respond_to?(:entered_by_id)
      obj.entered_by_id
    elsif obj.respond_to?(:claimed_by_id)
      obj.claimed_by_id
    elsif obj.respond_to?(:started_by_id)
      obj.started_by_id
    elsif obj.respond_to?(:completed_by) # Interaction#completed_by
      obj.completed_by
    elsif obj.is_a?(Excursion::Comment)
      obj.excursion.started_by_id
    elsif obj.is_a?(HelpButtonState)
      nil
    elsif obj.is_a?(Watch)
      obj.note.entered_by_id
    else
      raise MissingData
    end
  end

  def created_by_name
    names_hash[created_by_id]
  end

  def timestamp
    if obj.respond_to?(:created_at)
      obj.created_at
    elsif obj.respond_to?(:started_at)
      obj.started_at
    else
      raise MissingData
    end
  end

  def self.create_index
    # type "keyword" in not analyzed. Can only search by exact match
    # type "text" is analyzed (tokenized, etc for search)
    body = { settings: {
               analysis: {
                 analyzer: {
                   default: {
                     type: :english
                   }
                 }
               }
             },
             mappings: {
               properties: {
                 person_ids: {
                   type: TEXT,
                 },
                 type: {
                   type: KEYWORD,
                 },
                 subtype: {
                   type: KEYWORD,
                 },
                 link: {
                   type: KEYWORD,
                   index: false
                 },
                 created_by_id: {
                   type: KEYWORD,
                 },
                 created_by_name: {
                   type: TEXT,
                 },
                 blobs: {
                   type: TEXT,
                 },
                 field_names: {
                   type: KEYWORD,
                 },
                 timestamp: {
                   type: DATE,
                 },
               }
             }
    }

    ELASTICSEARCH_CLIENT.perform_request 'PUT', ELASTICSEARCH_AUDIT_INDEX, {}, body
    puts "Created index '#{ELASTICSEARCH_AUDIT_INDEX}' with settings #{body}"
  end
end
