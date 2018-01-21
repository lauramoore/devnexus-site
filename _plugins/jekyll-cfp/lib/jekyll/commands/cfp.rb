module Jekyll
  module Commands
    class Cfp < Command
      class << self
        def init_with_program(prog)
          @speakers = Speakers.new()
          prog.command(:cfp) do |c|
            c.action do |args, options|
              if("events".eql?(args[0]))
                process_event_data()
              elsif("schedule".eql?(args[0]))
                process_schedule_data()
              else
                Jekyll.logger.info("I do not understand #{args}")
              end
              #persist_speakers()
            end
          end
        end
        def process_schedule_data()
            schedule_data_file = File.read("_cfp/full_schedule.json")
            _data_in = JSON.parse(schedule_data_file)['schedule']['conference']['days']
            #Jekyll.logger.info(_data_in)
            days = _data_in.map{ |d| {}.merge( 'index'=> d['index'], 'events' => collect_rooms(d['rooms'])) }
            Jekyll.logger.info("Gathered #{days.length} schedule days")
            _schedule_yaml = YAML.dump(days)
            File.write("_data/schedule.yml", _schedule_yaml)
            #now we can print all the people
        end
        def process_event_data()
          event_data_file = File.read("_cfp/promo_events.json")
          event_data = JSON.parse(event_data_file)
          #workshop_data = event_data['events'].select{|item|"workshop" == item['track']}
          events = event_data['events']
          Jekyll.logger.info("Reading #{events.length} events from cfp")
          @speakers.collect_people_events(events)
          process_event_collection(events);
        end
        def collect_rooms(room_event_data)
          #Jekyll.logger.info(room_event_data)
          _data = room_event_data.reduce([]){ |hash, (k,v)| hash.concat(collect_room_events(k, v)) }
          return _data
        end
        def collect_room_events(room, array_of_events)
           @speakers.collect_people_events(array_of_events)
           times =  array_of_events.map{ |e| e.select{ |k,v| ["id", "start"].include?(k)}.merge("room" => room) }
           #Jekyll.logger.info(times)
           return times
           process_event_collection(array_of_events)
        end
        def process_event_collection(cfp_data)
          for event in cfp_data do
              person_details = event.delete 'persons'
              process_event(event, person_details)
          end
        end
        def process_event(event, persons)
         #Jekyll.logger.info(event)
         #Jekyll.logger.info(persons)
         event['layout'] = 'preso_details'
         #keeping keys to person records for later rendering
         filtered_persons = filter_attributes(persons, "full_public_name", "id")
         if (persons && persons.length > 0)
            primary_person = persons[0].select{ |k,v| ["id"].include?(k)}
            event['primary'] = primary_person
         end
         event['persons'] = filtered_persons
         abstract = event.delete('abstract')
         write_item("events", event, abstract)
        end
        def filter_attributes(data, *props)
           return data.map{|p| p.select{ |k,v| props.include?(k) }}
        end
        def write_item(collection, item, abstract)
          filename = "_#{collection}/#{item['id']}.md"
          #don't overwrite existing files to preserve CMS edits
          #if !(File.file?(filename))
          File.write( filename , YAML.dump(item)+"\r\n---\r\n"+abstract)
          #end
        end

        def persist_speakers()
          stored_speaker_file = File.read("_data/speakers.yml")
          stored_speaker_data = YAML.load(stored_speaker_file)
          #Jekyll.logger.info(stored_speaker_data)
          for person in @speakers.data().values do
            abstract = person.delete 'abstract'
            public_items = person.select{ |k,v| ["full_public_name", "id", "twitter_name", "events"].include?(k)}
            public_items['title'] = person['full_public_name']
            public_items['layout'] = "speaker_bio"
            write_item("speakers", public_items, abstract)
            correct_speaker_data(stored_speaker_data, person)
          end
          updated_speaker_yaml = YAML.dump(stored_speaker_data)
          #Jekyll.logger.info(updated_speaker_yaml)
          File.write("_data/speakers.yml", updated_speaker_yaml)
        end
        def correct_speaker_data(speaker_db, person_details)
          speaker_record = speaker_db.fetch(person_details['id'], nil)
          if(speaker_record)
            #TODO - update any cfp sourced images?
            #Jekyll.logger.info("found")
          else
            new_record = { "avatar_path" => person_details['avatar_path'], "name" => person_details['full_public_name']}
            speaker_db.store(person_details['id'], new_record)
            #Jekyll.logger.info("new>>> #{speaker_db.fetch(person_details['id'])}")
          end
        end
        def speakers(people, person_details)
          captured = people | person_details
          new_people = person_details - people
        end
      end
    end
  end
end
