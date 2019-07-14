namespace :elasticsearch do

  task index: :environment do
    Searchable.create_index

    #person = Person.find('7a7c9d31-9c04-43f3-bcef-1bf4d655ca84') # Helen Child
    #person = Person.find('eb01b16f-63b4-49d2-bfb9-b18f9c44af04') # 25 form responses
    #person = Person.find('d9ef29ea-8987-4382-8abe-fa7f66507a1f') # 6 alerts
    person = Person.find(Search::TARGET_PERSON_ID)

    names_hash = Person.names_hash_for_people
    # names hash has the format:
    # { <person_1_id> => <full_name>,
    # { <person_2_id> => <full_name>,
    #   ...
    # }

    count = 0

    lists = [
              person.watches,
              person.watch_updates,
              person.vitals_readings,
              person.pain_assessments,
              person.interactions,
              person.help_button_states,
              person.excursions,
              person.excursions.map(&:comments).flatten,
              person.notes,
              person.form_responses,
              person.activity_records,
              person.alerts,
            ]

    lists.each do |objects|

      noun = objects.first.class.to_s.pluralize
      puts("Indexing #{objects.count} #{noun}")

      objects.each do |obj|
        s = Searchable.new(obj, names_hash)
        s.write
        count += 1
      end

      puts "Done with #{noun}"
    end

    [:location_changes, :orientation_changes, :thank_yous].each do |skipped|
      puts "NOT INDEXED: #{skipped}"
    end

    [:pain_assessments].each do |alt|
      puts "Alternate links exist for #{alt}"
    end

    [:photos].each do |linked|
      puts "#{linked} not indexed directly because the parent object is indexed"
    end


    puts "#{count} documents total"
    puts 'Run this commant to check the total number of documents'
    puts 'in this elasticsearch index: '
    puts "\n  curl localhost:9200/#{ELASTICSEARCH_AUDIT_INDEX}/_search | jq '.hits.total'\n"

  end
end
