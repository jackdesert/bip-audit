require 'test_helper'

class SearchTest < ActiveSupport::TestCase

  def empty_body
    {:query=>{:bool=>{:filter=>[]}},
     :sort=>[{:timestamp=>{}}],
     :highlight=>{:fields=>{:blobs=>{}}}}
  end

  describe '#initialize' do
    describe 'unknown options' do
      it do
        assert_raises(ArgumentError) do
          Search.new(unknown: '')
        end
      end
    end
  end

  describe '#_body' do

    describe 'empty params' do
      it do
        body = Search.new().send :_body
        assert body == empty_body
      end
    end

    describe 'blanks in params' do
      it do
        options = {
          blobs: '',
          type: '',
          subtype: '',
          field_names: '',
          created_by_id: '',
          created_by_name: '',
          person_ids: '',
        }
        body = Search.new(options).send :_body
        assert body == empty_body
      end
    end


    describe 'single type in params' do
      it do
        options = { type: 'note' }
        body = Search.new(options).send :_body
        assert body == {:query=>{:bool=>{:filter=>[{:bool=>{:should=>[{:term=>{:type=>"note"}}]}}]}},
                        :sort=>[{:timestamp=>{}}],
                        :highlight=>{:fields=>{:blobs=>{}}}}
      end
    end

    describe 'two types in params' do
      it do
        options = { type: 'note, form_response' }
        body = Search.new(options).send :_body
        assert body == {:query=>
                        {:bool=>
                         {:filter=>
                          [{:bool=>
                            {:should=>[{:term=>{:type=>"note"}},
                                       {:term=>{:type=>"form_response"}}]}}]}},
                        :sort=>[{:timestamp=>{}}],
                        :highlight=>{:fields=>{:blobs=>{}}}}
      end
    end

    describe 'one type and two person_ids in params' do
      it do
        options = { type: 'note', person_ids: 'abc, def' }
        body = Search.new(options).send :_body
        assert body == {:query=>
                        {:bool=>
                         {:filter=>
                          [{:bool=>{:should=>[{:term=>{:type=>"note"}}]}},
                           {:bool=>
                            {:should=>[{:term=>{:person_ids=>"abc"}},
                                       {:term=>{:person_ids=>"def"}}]}}]}},
                        :sort=>[{:timestamp=>{}}],
                        :highlight=>{:fields=>{:blobs=>{}}}}
      end
    end

    describe 'blobs and one created_by_id' do
      it do
        options = { blobs: 'Hello, John', created_by_id: 'ghi' }
        body = Search.new(options).send :_body
        assert body == {:query=>
                        {:bool=>
                         {:filter=>
                          [{:match=>{:blobs=>"Hello, John"}},
                           {:bool=>{:should=>[{:term=>{:created_by_id=>"ghi"}}]}}]}},
                        :sort=>[{:timestamp=>{}}],
                        :highlight=>{:fields=>{:blobs=>{}}}}
      end
    end
  end
end
