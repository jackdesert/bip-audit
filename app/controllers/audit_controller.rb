class AuditController < ApplicationController

  def index
    require_permission :financial_reports, AccessType::READ

    write_to_redis
    search_params = {
                      blobs: params[:blobs],
                      field_names: params[:field_names],
                      start_timestamp: params[:start_timestamp],
                      end_timestamp: params[:end_timestamp],
                      type: params[:type],
                      subtype: params[:subtype],
                    }

    results = Search.new(search_params).results

    locals = search_params.merge(
      verbose: params[:verbose],
      stats: SearchStats.stats,
      results: results,
      names_hash: Person.names_hash_for_people,
      resident: Person.find(Search::TARGET_PERSON_ID),
    )




    render locals: locals
  end

  private

  def write_to_redis
    REDIS_CLIENT.lpush(redis_key, env['PATH'])
    REDIS_CLIENT.ltrim(redis_key, 0, Search::REDIS_SIZE)
  end

  def redis_key
    "#{Search::REDIS_KEY_PREPEND}#{current_user.id}"
  end
end


